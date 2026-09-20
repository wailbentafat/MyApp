import SwiftUI

/// Strava-style "Share activity" screen: a carousel of 9:16 story cards (route, photo, Before/After, impact)
/// and a row of share targets (Instagram Story, Photos, Copy, More).
struct ActivityShareView: View {
    @Bindable var viewModel: ActivityShareViewModel
    var onClose: () -> Void

    private let previewScale: CGFloat = 0.7

    var body: some View {
        ZStack(alignment: .top) {
            Eco.background.ignoresSafeArea()

            VStack(spacing: 0) {
                EcoTopBar(title: viewModel.showsDone ? "Nice work!" : "Share activity") {
                    EcoCircleButton(systemImage: "xmark", label: "Close", action: onClose)
                } trailing: {
                    EmptyView()
                }
                Divider().overlay(Eco.border)

                if viewModel.isPreparing {
                    Spacer()
                    ProgressView("Preparing your story…")
                        .tint(Eco.textPrimary)
                        .foregroundStyle(Eco.textSecondary)
                    Spacer()
                } else {
                    carousel
                    dots
                    Spacer(minLength: 0)
                    targets
                }
            }

            if let toast = viewModel.toast {
                Text(toast)
                    .font(.ecoLabelLarge)
                    .foregroundStyle(Eco.textPrimary)
                    .padding(.horizontal, Eco.Space.l).padding(.vertical, Eco.Space.m)
                    .glassEffect(.regular, in: .capsule)
                    .padding(.top, 90)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.smooth, value: viewModel.toast)
    }

    // MARK: Carousel

    private var carousel: some View {
        TabView(selection: $viewModel.currentIndex) {
            ForEach(Array(viewModel.cards.enumerated()), id: \.element.id) { index, card in
                StoryCardView(model: card)
                    .scaleEffect(previewScale)
                    .frame(width: StoryCanvas.size.width * previewScale, height: StoryCanvas.size.height * previewScale)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                    .tag(index)
                    .accessibilityLabel(card.accessibilityName)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: StoryCanvas.size.height * previewScale + 40)
        .padding(.top, Eco.Space.l)
    }

    private var dots: some View {
        HStack(spacing: 8) {
            ForEach(viewModel.cards.indices, id: \.self) { index in
                Circle()
                    .fill(index == viewModel.currentIndex ? Eco.buttonFill : Eco.textHint.opacity(0.6))
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.top, Eco.Space.s)
    }

    // MARK: Share targets

    private var targets: some View {
        VStack(spacing: Eco.Space.l) {
            HStack(alignment: .top, spacing: Eco.Space.xl) {
                target(title: "Story") {
                    Task { await viewModel.shareToInstagramStory() }
                } icon: {
                    EcoSymbol("instagram.logo", size: 28).foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(colors: [Color(hex: 0x833AB4), Color(hex: 0xFD1D1D), Color(hex: 0xFCB045)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: Circle()
                        )
                }
                target(title: "Save") {
                    Task { await viewModel.saveToPhotos() }
                } icon: { whiteCircle("square.and.arrow.down") }
                target(title: "Copy") {
                    viewModel.copyImage()
                } icon: { whiteCircle("doc.on.doc") }
                MoreShareTarget(viewModel: viewModel)
            }

            if viewModel.showsDone {
                Button("Done", action: onClose)
                    .buttonStyle(.eco)
                    .frame(maxWidth: 300)
            }
        }
        .padding(.top, Eco.Space.l)
        .padding(.bottom, Eco.Space.l)
        .frame(maxWidth: .infinity)
        .background(Eco.surface.ignoresSafeArea(edges: .bottom))
    }

    private func whiteCircle(_ symbol: String) -> some View {
        EcoSymbol(symbol, size: 26)
            .foregroundStyle(Eco.onButton)
            .frame(width: 60, height: 60)
            .background(Eco.buttonFill, in: Circle())
    }

    private func target<Icon: View>(title: String, action: @escaping () -> Void, @ViewBuilder icon: () -> Icon) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                icon()
                Text(title).font(.ecoLabelMedium).foregroundStyle(Eco.textBody)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title == "Story" ? "Share to Instagram Story" : title)
    }
}

/// "More": the system share sheet with the rendered story image.
private struct MoreShareTarget: View {
    let viewModel: ActivityShareViewModel
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: Image(uiImage: image), preview: SharePreview(viewModel.activity.title, image: Image(uiImage: image))) {
                    label
                }
            } else {
                label.opacity(0.5)
            }
        }
        .buttonStyle(.plain)
        .task(id: viewModel.currentIndex) { image = viewModel.currentImage() }
    }

    private var label: some View {
        VStack(spacing: 8) {
            EcoSymbol("ellipsis", size: 26)
                .foregroundStyle(Eco.onButton)
                .frame(width: 60, height: 60)
                .background(Eco.buttonFill, in: Circle())
            Text("More").font(.ecoLabelMedium).foregroundStyle(Eco.textBody)
        }
    }
}
