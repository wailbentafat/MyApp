import PhotosUI
import SwiftUI

/// Full-screen scanning camera for Spot: live AVFoundation preview, corner reticle with a scan line,
/// torch, library picker and a white shutter. On the simulator it shows a demo photo.
struct CameraScannerView: View {
    var onCaptured: (UIImage) -> Void
    var onClose: () -> Void

    @State private var viewModel: CameraScannerViewModel?
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let viewModel {
                ScannerContent(viewModel: viewModel, pickerItem: $pickerItem, onCaptured: onCaptured, onClose: onClose)
            }
        }
        .task {
            guard viewModel == nil else { return }
            let model = CameraScannerViewModel(camera: AppEnvironment.makeCamera())
            viewModel = model
            await model.start()
        }
        .onDisappear { viewModel?.stop() }
        .onChange(of: pickerItem) { _, item in
            Task {
                guard let item, let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                onCaptured(image)
            }
        }
    }
}

private struct ScannerContent: View {
    let viewModel: CameraScannerViewModel
    @Binding var pickerItem: PhotosPickerItem?
    var onCaptured: (UIImage) -> Void
    var onClose: () -> Void

    @State private var scanPhase = false
    @State private var flash = false
    private let hintTimer = Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            preview
                .ignoresSafeArea()

            Reticle()
                .padding(.horizontal, 44)
                .padding(.vertical, 170)
                .overlay {
                    if viewModel.state == .running || viewModel.state == .demo {
                        scanLine
                    }
                }

            VStack {
                topBar
                Spacer()
                hintPill
                bottomBar
            }
            .padding(.horizontal, Eco.Space.l)

            Color.white.opacity(flash ? 0.85 : 0).ignoresSafeArea().allowsHitTesting(false)
        }
        .onReceive(hintTimer) { _ in viewModel.advanceHint() }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { scanPhase = true }
        }
    }

    // MARK: Layers

    @ViewBuilder
    private var preview: some View {
        switch viewModel.state {
        case .running:
            if let session = viewModel.previewSession {
                CameraPreviewView(session: session)
            }
        case .demo:
            if let url = DemoPhotos.url("before_beach"), let image = FakePhotoStore.shared.loadImage(url) {
                Image(uiImage: image).resizable().scaledToFill()
                    .overlay(alignment: .top) {
                        Text("Simulator: no camera. Using a demo photo.")
                            .font(.ecoLabelSmall)
                            .foregroundStyle(Eco.textPrimary)
                            .padding(.horizontal, Eco.Space.m).padding(.vertical, 6)
                            .glassEffect(.regular, in: .capsule)
                            .padding(.top, 120)
                    }
            }
        case .denied:
            deniedView
        case .idle, .requestingAccess:
            ProgressView().tint(.white)
        }
    }

    private var deniedView: some View {
        VStack(spacing: Eco.Space.l) {
            EcoSymbol("camera.fill", size: 40).foregroundStyle(Eco.textSecondary)
            Text("Camera access is off")
                .font(.ecoHeadlineSmall).foregroundStyle(Eco.textPrimary)
            Text("Allow camera access in Settings to scan pollution, or pick a photo from your library.")
                .font(.ecoBodyMedium).foregroundStyle(Eco.textSecondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.eco)
            .frame(maxWidth: 260)
        }
        .padding(Eco.Space.xl)
    }

    private var scanLine: some View {
        GeometryReader { proxy in
            LinearGradient(colors: [.clear, Eco.primary.opacity(0.9), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(height: 3)
                .shadow(color: Eco.primary, radius: 6)
                .offset(y: scanPhase ? proxy.size.height - 3 : 0)
        }
    }

    // MARK: Controls

    private var topBar: some View {
        HStack {
            EcoCircleButton(systemImage: "xmark", label: "Close", action: onClose)
            Spacer()
            if viewModel.supportsTorch {
                EcoCircleButton(systemImage: viewModel.torchOn ? "bolt.fill" : "bolt.slash.fill",
                                label: viewModel.torchOn ? "Turn torch off" : "Turn torch on") {
                    viewModel.toggleTorch()
                }
            }
        }
        .padding(.top, Eco.Space.s)
    }

    private var hintPill: some View {
        Text(viewModel.hint)
            .font(.ecoLabelLarge)
            .foregroundStyle(Eco.textPrimary)
            .padding(.horizontal, Eco.Space.l).padding(.vertical, Eco.Space.s)
            .glassEffect(.regular, in: .capsule)
            .animation(.easeInOut, value: viewModel.hintIndex)
            .padding(.bottom, Eco.Space.l)
    }

    private var bottomBar: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                EcoSymbol("photo", size: 22)
                    .foregroundStyle(Eco.textPrimary)
                    .frame(width: 52, height: 52)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .accessibilityLabel("Choose from library")

            Spacer()

            Button {
                Task {
                    withAnimation(.easeOut(duration: 0.12)) { flash = true }
                    let image = await viewModel.capture()
                    withAnimation(.easeIn(duration: 0.25)) { flash = false }
                    if let image { onCaptured(image) }
                }
            } label: {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4).frame(width: 78, height: 78)
                    Circle().fill(.white).frame(width: 62, height: 62)
                }
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canCapture)
            .opacity(viewModel.canCapture ? 1 : 0.5)
            .accessibilityLabel("Take photo")

            Spacer()

            Color.clear.frame(width: 52, height: 52)
        }
        .padding(.bottom, Eco.Space.xl)
    }
}

/// Four rounded corner brackets marking the scan area.
private struct Reticle: View {
    var body: some View {
        GeometryReader { proxy in
            let length: CGFloat = 34
            let w = proxy.size.width, h = proxy.size.height
            Path { path in
                let corners: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(0, 0, 1, 1), (w, 0, -1, 1), (0, h, 1, -1), (w, h, -1, -1)]
                for (x, y, dx, dy) in corners {
                    path.move(to: CGPoint(x: x, y: y + dy * length))
                    path.addLine(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x + dx * length, y: y))
                }
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
}
