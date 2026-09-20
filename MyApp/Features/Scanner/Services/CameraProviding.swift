import AVFoundation
import UIKit

enum CameraAuthorization: Equatable {
    case notDetermined, authorized, denied
}

/// Thin wrapper over AVFoundation. No business rules here: permission flow, capture state and hints live in
/// `CameraScannerViewModel`.
@MainActor
protocol CameraProviding: AnyObject {
    /// `false` on the simulator / devices without a camera.
    var isAvailable: Bool { get }
    var authorization: CameraAuthorization { get }
    var previewSession: AVCaptureSession? { get }
    func requestAccess() async -> Bool
    func start() async
    func stop()
    func setTorch(_ on: Bool)
    func capturePhoto() async -> UIImage?
}

// MARK: - Live (AVCaptureSession + AVCapturePhotoOutput)

@MainActor
final class LiveCameraProvider: NSObject, CameraProviding, AVCapturePhotoCaptureDelegate {
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private var captureContinuation: CheckedContinuation<UIImage?, Never>?

    var isAvailable: Bool { AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil }
    var previewSession: AVCaptureSession? { session }

    var authorization: CameraAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    func start() async {
        configureIfNeeded()
        guard isConfigured, !session.isRunning else { return }
        let session = session
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
                continuation.resume()
            }
        }
    }

    func stop() {
        setTorch(false)
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            if session.isRunning { session.stopRunning() }
        }
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }

    func capturePhoto() async -> UIImage? {
        guard isConfigured, captureContinuation == nil else { return nil }
        return await withCheckedContinuation { continuation in
            captureContinuation = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured,
              let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        device = camera
        isConfigured = true
    }

    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        Task { @MainActor in
            captureContinuation?.resume(returning: image)
            captureContinuation = nil
        }
    }
}

// MARK: - Fake (simulator: no camera, returns a real demo litter photo)

@MainActor
final class FakeCameraProvider: CameraProviding {
    var isAvailable: Bool { false }
    var authorization: CameraAuthorization { .authorized }
    var previewSession: AVCaptureSession? { nil }

    func requestAccess() async -> Bool { true }
    func start() async {}
    func stop() {}
    func setTorch(_ on: Bool) {}

    func capturePhoto() async -> UIImage? {
        try? await Task.sleep(for: .milliseconds(250))
        return DemoPhoto.image
    }
}
