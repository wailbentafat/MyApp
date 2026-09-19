import CoreLocation
import Foundation
import Observation

/// Drives the whole Activity flow (setup → recording → impact log → summary).
/// ALL business logic of the flow lives here: state machine, GPS filtering, distance, pace,
/// elevation, calories, impact counters, saving, and display formatting.
@Observable @MainActor
final class ActivityViewModel: Identifiable {
    enum State { case idle, running, paused, finished }
    enum Screen { case setup, recording, impactLog, summary }

    // MARK: Tunables
    static let maxAccuracy: Double = 30          // metres: ignore worse GPS fixes
    static let maxSpeed: Double = 12             // m/s: ignore teleporting fixes
    static let minStep: Double = 2               // metres: ignore GPS jitter
    static let elevationThreshold: Double = 3    // metres: ignore barometric/GPS noise
    static let defaultWeightKg: Double = 70

    // MARK: State (read by the view)
    private(set) var state: State = .idle
    var screen: Screen = .setup
    private(set) var route: [RoutePoint] = []
    private(set) var elapsed: TimeInterval = 0
    private(set) var distanceMeters: Double = 0
    private(set) var elevationGain: Double = 0
    private(set) var kcal: Double = 0
    private(set) var kcalSource: EnergySource = .estimated
    private(set) var currentSpeed: Double = 0     // m/s, smoothed
    private(set) var heartRate: Int?
    private(set) var steps: Int?
    private(set) var savedActivity: Activity?
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    var impact = ImpactLog()
    var title: String

    let context: ActivityContext

    // MARK: Dependencies
    @ObservationIgnored private let location: LocationProviding
    @ObservationIgnored private let health: HealthProviding
    @ObservationIgnored private let activities: ActivityRepository
    @ObservationIgnored private let cleanUps: CleanUpRepository
    @ObservationIgnored private let now: () -> Date

    // MARK: Internals
    @ObservationIgnored private var startedAt: Date?
    @ObservationIgnored private var endedAt: Date?
    @ObservationIgnored private var segmentStart: Date?
    @ObservationIgnored private var accumulated: TimeInterval = 0
    @ObservationIgnored private var lastLocation: CLLocation?
    @ObservationIgnored private var altitudeAnchor: Double?
    @ObservationIgnored private var weightKg = ActivityViewModel.defaultWeightKg
    @ObservationIgnored private var heartRateSum = 0
    @ObservationIgnored private var heartRateCount = 0
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(
        context: ActivityContext = .free,
        location: LocationProviding,
        health: HealthProviding,
        activities: ActivityRepository,
        cleanUps: CleanUpRepository,
        now: @escaping () -> Date = { .now }
    ) {
        self.context = context
        self.location = location
        self.health = health
        self.activities = activities
        self.cleanUps = cleanUps
        self.now = now
        self.title = context.cleanUp?.title ?? Self.defaultTitle(at: now())
    }

    // MARK: - Intents

    func start() {
        guard state == .idle else { return }
        let date = now()
        startedAt = date
        segmentStart = date
        state = .running
        screen = .recording
        beginSensors(startingAt: date)
    }

    func pause() {
        guard state == .running else { return }
        accumulated += segmentElapsed()
        segmentStart = nil
        state = .paused
        elapsed = accumulated
    }

    func resume() {
        guard state == .paused else { return }
        segmentStart = now()
        lastLocation = nil        // don't count the ground covered while paused
        state = .running
    }

    /// Stops recording and moves on to the impact log.
    func finish() {
        guard state == .running || state == .paused else { return }
        if state == .running { accumulated += segmentElapsed() }
        elapsed = accumulated
        segmentStart = nil
        endedAt = now()
        state = .finished
        stopSensors()
        screen = .impactLog
    }

    /// Throws the activity away (used by "Discard").
    func discard() {
        stopSensors()
        state = .idle
    }

    func addBag() { impact.bags += 1 }
    func removeBag() { impact.bags = max(0, impact.bags - 1) }
    func adjustKg(by delta: Double) { impact.kg = max(0, (impact.kg + delta * 2).rounded() / 2) }
    func increment(_ category: WasteCategory) { impact.items[category, default: 0] += 1 }
    func decrement(_ category: WasteCategory) {
        let value = max(0, (impact.items[category] ?? 0) - 1)
        impact.items[category] = value == 0 ? nil : value
    }

    /// Persists the activity, saves the Health workout, closes the Clean-Up, then shows the summary.
    func save() async {
        guard state == .finished, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        var activity = makeActivity()
        do {
            activity.healthWorkoutId = try? await health.saveWorkout(activity)
            try await activities.save(activity)
            if let cleanUp = context.cleanUp {
                try await cleanUps.complete(cleanUpId: cleanUp.id, activityId: activity.id)
            }
            savedActivity = activity
            screen = .summary
        } catch {
            errorMessage = "Couldn't save your activity. Please try again."
        }
        isSaving = false
    }

    // MARK: - Ticking & GPS (internal so tests can drive them)

    func tick() {
        guard state == .running else { return }
        elapsed = accumulated + segmentElapsed()
    }

    func handle(_ location: CLLocation) {
        guard state == .running else { return }
        guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= Self.maxAccuracy else { return }

        guard let last = lastLocation else {
            lastLocation = location
            altitudeAnchor = location.altitude
            route.append(RoutePoint(location))
            return
        }

        let dt = location.timestamp.timeIntervalSince(last.timestamp)
        let step = location.distance(from: last)
        guard dt > 0, step >= Self.minStep, step / dt <= Self.maxSpeed else { return }

        distanceMeters += step
        let speed = step / dt
        currentSpeed = currentSpeed == 0 ? speed : currentSpeed * 0.7 + speed * 0.3
        if kcalSource == .estimated {
            kcal += Self.met(forSpeed: currentSpeed) * weightKg * dt / 3600
        }
        updateElevation(with: location.altitude)
        lastLocation = location
        route.append(RoutePoint(location))
    }

    func record(heartRate bpm: Int) {
        heartRate = bpm
        if state == .running {
            heartRateSum += bpm
            heartRateCount += 1
        }
    }

    // MARK: - Derived values & display formatting

    var coordinates: [CLLocationCoordinate2D] { route.map(\.coordinate) }
    var isRunning: Bool { state == .running }
    var isPaused: Bool { state == .paused }

    var averageHeartRate: Double? {
        heartRateCount > 0 ? Double(heartRateSum) / Double(heartRateCount) : nil
    }

    var timeText: String { Self.formatDuration(elapsed) }
    var distanceValueText: String { String(format: "%.2f", distanceMeters / 1000) }
    var paceText: String { Self.formatPace(speed: currentSpeed) }
    var averagePaceText: String { Self.formatPace(speed: elapsed > 0 ? distanceMeters / elapsed : 0) }
    var kcalText: String { String(Int(kcal.rounded())) }
    var elevationText: String { String(Int(elevationGain.rounded())) }
    var heartRateText: String { heartRate.map(String.init) ?? "--" }
    var stepsText: String { steps.map(String.init) ?? "--" }
    var energyLabel: String { kcalSource == .estimated ? "Calories (est.)" : "Calories" }

    static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// "5:32" per km, "--:--" when standing still.
    static func formatPace(speed: Double) -> String {
        guard speed > 0.3 else { return "--:--" }
        let secondsPerKm = min(5999, Int((1000 / speed).rounded()))
        return String(format: "%d:%02d", secondsPerKm / 60, secondsPerKm % 60)
    }

    static func defaultTitle(at date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        let part = switch hour {
        case 5..<12: "Morning"
        case 12..<17: "Afternoon"
        case 17..<22: "Evening"
        default: "Night"
        }
        return "\(part) Clean-Up"
    }

    /// Metabolic equivalent by speed band (walking → running).
    static func met(forSpeed speed: Double) -> Double {
        switch speed {
        case ..<0.5: 2.0
        case ..<1.5: 3.0
        case ..<2.0: 3.8
        case ..<2.5: 5.0
        case ..<3.0: 8.3
        case ..<4.0: 9.8
        default: 11.5
        }
    }

    // MARK: - Private

    private func segmentElapsed() -> TimeInterval {
        guard let segmentStart else { return 0 }
        return now().timeIntervalSince(segmentStart)
    }

    private func updateElevation(with altitude: Double) {
        guard let anchor = altitudeAnchor else { altitudeAnchor = altitude; return }
        let delta = altitude - anchor
        guard abs(delta) >= Self.elevationThreshold else { return }
        if delta > 0 { elevationGain += delta }
        altitudeAnchor = altitude
    }

    private func makeActivity() -> Activity {
        Activity(
            cleanUpId: context.cleanUp?.id,
            title: title.trimmingCharacters(in: .whitespaces).isEmpty ? Self.defaultTitle(at: startedAt ?? now()) : title,
            startedAt: startedAt ?? now(),
            endedAt: endedAt ?? now(),
            movingSeconds: elapsed,
            route: route,
            distanceMeters: distanceMeters,
            elevationGainMeters: elevationGain,
            kcal: kcal.rounded(),
            kcalSource: kcalSource,
            averageHeartRate: averageHeartRate,
            steps: steps,
            impact: impact
        )
    }

    private func beginSensors(startingAt date: Date) {
        location.requestAuthorization()
        let locationStream = location.startUpdates()
        let heartRateStream = health.heartRateUpdates()
        let stepStream = health.stepUpdates(from: date)

        tasks = [
            Task { [weak self] in
                for await fix in locationStream { self?.handle(fix) }
            },
            Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    self?.tick()
                }
            },
            Task { [weak self] in
                for await bpm in heartRateStream { self?.record(heartRate: bpm) }
            },
            Task { [weak self] in
                for await count in stepStream { self?.steps = count }
            },
            Task { [weak self] in
                guard let self else { return }
                _ = await health.requestAuthorization()
                if let weight = await health.bodyMassKg() { weightKg = weight }
            },
        ]
    }

    private func stopSensors() {
        tasks.forEach { $0.cancel() }
        tasks = []
        location.stopUpdates()
    }
}
