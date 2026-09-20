import SwiftUI

/// One 9:16 story card, drawn at 360×640 and rendered to 1080×1920 (see `LiveStoryRenderer`).
struct StoryCardView: View {
    let model: ShareCardModel

    var body: some View {
        ZStack {
            background
            overlay
        }
        .frame(width: StoryCanvas.size.width, height: StoryCanvas.size.height)
        .clipped()
    }

    // MARK: Backgrounds

    @ViewBuilder
    private var background: some View {
        switch model.kind {
        case .route:
            ZStack {
                if let map = model.mapImage {
                    Image(uiImage: map).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Eco.background, Color(hex: 0x1B2A3F)], startPoint: .top, endPoint: .bottom)
                }
                RouteShape(points: model.routePoints)
                    .stroke(Eco.primary, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    .shadow(color: .black.opacity(0.5), radius: 3)
                if let first = model.routePoints.first, let last = model.routePoints.last {
                    routeDot(first, color: .white)
                    routeDot(last, color: Eco.primary)
                }
                bottomShade
            }
        case .photo:
            ZStack {
                photoFill(model.photo)
                LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .center)
                bottomShade
            }
        case .beforeAfter:
            ZStack {
                VStack(spacing: 0) {
                    labeledPhoto(model.beforePhoto, label: "BEFORE")
                    labeledPhoto(model.afterPhoto, label: "AFTER")
                }
                bottomShade
            }
        case .impact:
            LinearGradient(colors: [Eco.background, Color(light: 0x2E7F4E, dark: 0x245A3E)], startPoint: .top, endPoint: .bottom)
        }
    }

    private var bottomShade: some View {
        LinearGradient(colors: [.clear, .black.opacity(0.88)], startPoint: UnitPoint(x: 0.5, y: 0.42), endPoint: .bottom)
    }

    private func photoFill(_ image: UIImage?) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Eco.surfaceRaised
            }
        }
        .frame(width: StoryCanvas.size.width, height: StoryCanvas.size.height)
        .clipped()
    }

    private func labeledPhoto(_ image: UIImage?, label: String) -> some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Eco.surfaceRaised
            }
        }
        .frame(width: StoryCanvas.size.width, height: StoryCanvas.size.height / 2)
        .clipped()
        .overlay(alignment: .topLeading) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(14)
                .padding(.top, label == "BEFORE" ? 46 : 0)
        }
    }

    private func routeDot(_ point: CGPoint, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.black.opacity(0.5), lineWidth: 2))
            .position(x: point.x * StoryCanvas.size.width, y: point.y * StoryCanvas.size.height)
    }

    // MARK: Foreground

    private var overlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image("HealLogo")
                .resizable()
                .scaledToFit()
                .frame(height: 64)
                .foregroundStyle(.white)
                .padding(.top, 10)

            if model.kind == .impact {
                impactBody
            } else {
                Spacer(minLength: 0)
                titleBlock
                statGrid
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
        .frame(width: StoryCanvas.size.width, height: StoryCanvas.size.height, alignment: .topLeading)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(model.title)
                .font(.ecoDisplaySmall)
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(model.dateText)
                .font(.ecoBodySmall)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.bottom, 16)
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                  alignment: .leading, spacing: 10) {
            ForEach(model.stats) { stat in
                VStack(alignment: .leading, spacing: 0) {
                    Text(stat.label).font(.ecoBodySmall).foregroundStyle(.white.opacity(0.8))
                    Text(stat.value)
                        .font(.ecoStat)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    private var impactBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)
            Text(model.stats.first?.value ?? "0")
                .font(.system(size: 110, weight: .bold))
                .foregroundStyle(.white)
            Text("bags collected")
                .font(.ecoHeadlineSmall)
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 22) {
                ForEach(model.stats.dropFirst()) { stat in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(stat.label).font(.ecoBodySmall).foregroundStyle(.white.opacity(0.75))
                        Text(stat.value).font(.ecoStat).foregroundStyle(.white)
                    }
                }
            }

            Text(model.bottlesText)
                .font(.ecoTitleMedium)
                .foregroundStyle(Eco.onPrimary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Eco.primary, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 6) {
                ForEach(model.wasteChips.prefix(3), id: \.self) { chip in
                    Text(chip)
                        .font(.ecoLabelSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.16), in: Capsule())
                }
            }

            Spacer(minLength: 0)
            titleBlock
        }
    }
}

private struct RouteShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.x * rect.width, y: first.y * rect.height))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.x * rect.width, y: point.y * rect.height))
        }
        return path
    }
}
