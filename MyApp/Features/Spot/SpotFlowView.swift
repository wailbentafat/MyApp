import SwiftUI

/// State machine coordinator for the Spot tab: capture → analysing (fake AI) →
/// result (editable) → publish. Calling `onPublished` lets the shell switch back
/// to the Map tab once a Clean-Up is live.
struct SpotFlowView: View {
    private enum Step: Equatable {
        case capture, analyzing, result, publish
    }

    var onPublished: () -> Void

    @Environment(\.scannerService) private var scannerService
    @Environment(\.cleanUpRepository) private var cleanUpRepository
    @Environment(\.notificationService) private var notificationService
    @Environment(\.appSession) private var appSession
    @State private var locationProvider = LocationFixProvider()

    @State private var step: Step = .capture
    @State private var capturedImage: UIImage?
    @State private var capturedCoordinate: Coordinate?
    @State private var capturedHeading: Double = 0
    @State private var scannerResult: ScannerResult?
    @State private var scannerError: String?
    @State private var isPublishing = false

    var body: some View {
        Group {
            switch step {
            case .capture:
                SpotCaptureView(onCaptured: handleCapture)
            case .analyzing:
                SpotAnalyzingView()
            case .result:
                if let resultBinding = Binding($scannerResult) {
                    SpotResultView(
                        image: capturedImage,
                        result: resultBinding,
                        errorMessage: scannerError,
                        onRetry: { Task { await runAnalysis() } },
                        onContinue: { step = .publish }
                    )
                }
            case .publish:
                if let scannerResult {
                    SpotPublishView(
                        image: capturedImage,
                        result: scannerResult,
                        isPublishing: isPublishing,
                        onPublish: publish
                    )
                }
            }
        }
        .navigationTitle("Spot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if step != .capture {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Start over", action: resetFlow)
                }
            }
        }
    }

    private func handleCapture(_ image: UIImage) {
        capturedImage = image
        step = .analyzing
        Task {
            locationProvider.requestWhenInUseAuthorization()
            if let fix = await locationProvider.requestFix() {
                capturedCoordinate = fix.coordinate
                capturedHeading = fix.heading
            } else {
                // No/denied location: demo still works, geotagged near the seed data.
                capturedCoordinate = Fixtures.homeCoordinate
            }
            await runAnalysis()
        }
    }

    private func runAnalysis() async {
        guard let capturedImage, let data = capturedImage.jpegData(compressionQuality: 0.7) else { return }
        step = .analyzing
        scannerError = nil
        do {
            scannerResult = try await scannerService.analyse(imageData: data)
        } catch {
            scannerError = error.localizedDescription
            // Manual-entry fallback: still let the person tag it themselves.
            scannerResult = ScannerResult(
                wasteTypes: [], severity: .medium, estimatedBags: 1,
                gear: [], hazard: .none, peopleNeeded: 1, confidence: 0, modelVersion: "manual"
            )
        }
        step = .result
    }

    private func publish(title: String, startsAt: Date?, capacity: Int?) async {
        guard let scannerResult, let coordinate = capturedCoordinate, let user = appSession.currentUser else { return }
        isPublishing = true
        defer { isPublishing = false }

        let draft = CleanUpDraft(
            title: title,
            coordinate: coordinate,
            beforePhotoData: capturedImage?.jpegData(compressionQuality: 0.8),
            beforeHeading: capturedHeading,
            wasteTypes: scannerResult.wasteTypes,
            severity: scannerResult.severity,
            estimatedBags: scannerResult.estimatedBags,
            gear: scannerResult.gear,
            hazard: scannerResult.hazard,
            startsAt: startsAt,
            capacity: capacity
        )

        if let cleanUp = try? await cleanUpRepository.create(draft, host: user) {
            _ = await notificationService.requestAuthorization()
            await notificationService.notifyNearby(of: cleanUp)
            await notificationService.scheduleReminder(for: cleanUp)
        }
        resetFlow()
        onPublished()
    }

    private func resetFlow() {
        step = .capture
        capturedImage = nil
        capturedCoordinate = nil
        capturedHeading = 0
        scannerResult = nil
        scannerError = nil
    }
}

#Preview {
    NavigationStack { SpotFlowView(onPublished: {}) }
        .ecoTheme()
}
