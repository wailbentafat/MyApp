import PhotosUI
import SwiftUI

struct SpotCaptureView: View {
    var onCaptured: (UIImage) -> Void

    @State private var showCamera = false
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        VStack(spacing: Eco.Space.xl) {
            Spacer()

            EcoSymbol("camera.viewfinder", size: 64)
                .foregroundStyle(Eco.primary)

            VStack(spacing: Eco.Space.s) {
                Text("Spot pollution")
                    .font(.ecoHeadlineMedium)
                    .foregroundStyle(Eco.textPrimary)
                Text("Snap a photo. AI will identify the waste, estimate volume and suggest gear.")
                    .font(.ecoBodyMedium)
                    .foregroundStyle(Eco.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Eco.Space.xl)

            Spacer()

            VStack(spacing: Eco.Space.m) {
                Button {
                    showCamera = true
                } label: {
                    EcoLabel("Take photo", systemImage: "camera.fill")
                }
                .buttonStyle(.eco)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

                PhotosPicker(selection: $pickerItem, matching: .images) {
                    EcoLabel("Choose from library", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.ecoSecondary)

                Button {
                    onCaptured(DemoPhoto.image)
                } label: {
                    Text("Use a demo photo")
                        .font(.ecoLabelMedium)
                        .foregroundStyle(Eco.textHint)
                }
            }
        }
        .padding(Eco.Space.l)
        .ecoScreenBackground()
        .sheet(isPresented: $showCamera) {
            CameraPicker(onImage: onCaptured)
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, newValue in
            Task {
                guard let newValue,
                      let data = try? await newValue.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                onCaptured(image)
            }
        }
    }
}

/// Thin wrapper around `UIImagePickerController` in `.camera` mode — P1's shared
/// `CameraView` (with the ghost overlay) doesn't exist yet, so Spot capture uses
/// the plain system camera for now, per the contract in the plan (§9): Spot reuses
/// P1's camera once it lands.
private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    NavigationStack { SpotCaptureView(onCaptured: { _ in }) }
        .ecoTheme()
}
