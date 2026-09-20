import AVFoundation
import Observation
import UIKit

/// Drives the Spot scanner camera: permission flow, live vs simulator mode, torch, capture, hints.
@Observable @MainActor
final class CameraScannerViewModel {
    enum State: Equatable {
        case idle
        case requestingAccess
        case running
        /// No camera (simulator): shows a demo photo and still lets the flow be tried.
        case demo
        case denied
    }

    static let hints = [
        "Point at the litter",
        "Get the whole pile in the frame",
        "Hold steady, then tap the shutter",
    ]

    private(set) var state: State = .idle
    private(set) var torchOn = false
    private(set) var isCapturing = false
    private(set) var hintIndex = 0

    private let camera: CameraProviding

    init(camera: CameraProviding) {
        self.camera = camera
    }

    var previewSession: AVCaptureSession? { camera.previewSession }
    var hint: String { Self.hints[hintIndex % Self.hints.count] }
    var canCapture: Bool { (state == .running || state == .demo) && !isCapturing }
    var supportsTorch: Bool { state == .running }

    // MARK: Lifecycle

    func start() async {
        guard camera.isAvailable else {
            state = .demo
            return
        }
        switch camera.authorization {
        case .authorized:
            break
        case .notDetermined:
            state = .requestingAccess
            guard await camera.requestAccess() else {
                state = .denied
                return
            }
        case .denied:
            state = .denied
            return
        }
        await camera.start()
        state = .running
    }

    func stop() {
        camera.stop()
        torchOn = false
    }

    // MARK: Actions

    func toggleTorch() {
        guard supportsTorch else { return }
        torchOn.toggle()
        camera.setTorch(torchOn)
    }

    func advanceHint() {
        hintIndex = (hintIndex + 1) % Self.hints.count
    }

    /// Takes the photo; returns nil if the camera failed or a capture is already running.
    func capture() async -> UIImage? {
        guard canCapture else { return nil }
        isCapturing = true
        defer { isCapturing = false }
        return await camera.capturePhoto()
    }
}
