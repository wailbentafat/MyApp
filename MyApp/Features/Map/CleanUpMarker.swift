import SwiftUI

/// Map marker in the photo-avatar style (from the friend's redesign): the Spot's Before photo inside a
/// status-colored ring, a bag-count badge, a pin tail anchored to the coordinate, and a pulsing halo
/// for `.live` Clean-Ups. Colors come from the design system tokens.
struct CleanUpMarker: View {
    let cleanUp: CleanUp
    let bagsText: String

    @State private var isPulsing = false

    private var tint: Color {
        switch cleanUp.status {
        case .open: Eco.primary
        case .scheduled: Eco.info
        case .live: Eco.warning
        case .done: Eco.textHint
        }
    }

    private var photo: UIImage? {
        FakePhotoStore.shared.loadImage(cleanUp.beforePhotoURL)
    }

    var body: some View {
        VStack(spacing: -4) {
            ZStack {
                if cleanUp.status == .live {
                    Circle()
                        .fill(tint.opacity(0.4))
                        .frame(width: 52, height: 52)
                        .scaleEffect(isPulsing ? 1.35 : 0.8)
                        .opacity(isPulsing ? 0 : 0.8)
                        .animation(.easeOut(duration: 1.3).repeatForever(autoreverses: false), value: isPulsing)
                }

                Circle()
                    .fill(.white)
                    .frame(width: 48, height: 48)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                avatar
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                Circle()
                    .stroke(tint, lineWidth: 3)
                    .frame(width: 48, height: 48)
            }
            .overlay(alignment: .topTrailing) {
                Text(bagsText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Eco.onButton)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Eco.buttonFill, in: Circle())
                    .overlay(Circle().stroke(Eco.onButton.opacity(0.25), lineWidth: 1))
                    .offset(x: 4, y: -2)
            }

            MarkerTail()
                .fill(tint)
                .frame(width: 13, height: 8)
                .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
        }
        .onAppear { isPulsing = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cleanUp.title), \(cleanUp.status.label), \(bagsText) bags")
    }

    @ViewBuilder
    private var avatar: some View {
        if let photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [tint, tint.opacity(0.65)], startPoint: .top, endPoint: .bottom)
                EcoSymbol("trash.fill", size: 18).foregroundStyle(Eco.onPrimary)
            }
        }
    }
}

private struct MarkerTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
