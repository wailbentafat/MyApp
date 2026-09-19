import Foundation

/// Thin wrapper over HealthKit + CoreMotion. Live implementation arrives in Phase 3;
/// until then the app runs on `FakeHealthProvider`.
@MainActor
protocol HealthProviding: AnyObject {
    func requestAuthorization() async -> Bool
    func bodyMassKg() async -> Double?
    /// Beats per minute, whenever a new sample arrives (Apple Watch). Empty stream without a Watch.
    func heartRateUpdates() -> AsyncStream<Int>
    /// Cumulative steps since the activity started.
    func stepUpdates(from start: Date) -> AsyncStream<Int>
    /// Saves the finished activity as an `HKWorkout` with its route. Returns the workout id.
    func saveWorkout(_ activity: Activity) async throws -> UUID?
}

@MainActor
final class FakeHealthProvider: HealthProviding {
    func requestAuthorization() async -> Bool { true }

    func bodyMassKg() async -> Double? { 68 }

    func heartRateUpdates() -> AsyncStream<Int> {
        AsyncStream { continuation in
            let task = Task {
                var bpm = 105
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    bpm = min(165, max(90, bpm + Int.random(in: -3...5)))
                    continuation.yield(bpm)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func stepUpdates(from start: Date) -> AsyncStream<Int> {
        AsyncStream { continuation in
            let task = Task {
                var steps = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    steps += 2
                    continuation.yield(steps)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func saveWorkout(_ activity: Activity) async throws -> UUID? { UUID() }
}
