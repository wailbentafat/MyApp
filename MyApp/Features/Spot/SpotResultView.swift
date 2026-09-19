import SwiftUI

struct SpotResultView: View {
    var image: UIImage?
    @Binding var result: ScannerResult
    var errorMessage: String?
    var onRetry: () -> Void
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Eco.Space.xl) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Eco.Radius.card))
                }

                if let errorMessage {
                    VStack(alignment: .leading, spacing: Eco.Space.s) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.ecoBodyMedium)
                            .foregroundStyle(Eco.warning)
                        Text("Edit the fields below manually, or try again.")
                            .font(.ecoBodySmall)
                            .foregroundStyle(Eco.textSecondary)
                        Button("Try again", action: onRetry)
                            .buttonStyle(.ecoSecondary)
                    }
                    .ecoCard()
                } else {
                    HStack {
                        Label("AI detected this", systemImage: "sparkles")
                            .font(.ecoLabelMedium)
                            .foregroundStyle(Eco.primary)
                        Spacer()
                        Text("\(Int(result.confidence * 100))% confidence")
                            .font(.ecoLabelSmall)
                            .foregroundStyle(Eco.textHint)
                    }
                }

                if let hazardMessage = result.hazard.message {
                    Label(hazardMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.ecoBodyMedium)
                        .foregroundStyle(result.hazard == .hazardous ? Eco.error : Eco.warning)
                        .padding(Eco.Space.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((result.hazard == .hazardous ? Eco.error : Eco.warning).opacity(0.12), in: RoundedRectangle(cornerRadius: Eco.Radius.card))
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Waste types")
                    FlowChips {
                        ForEach(WasteType.allCases) { type in
                            Button {
                                toggle(type)
                            } label: {
                                EcoChip(title: type.label, systemImage: type.systemImage, isSelected: result.wasteTypes.contains(type))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Severity")
                    Picker("Severity", selection: $result.severity) {
                        ForEach(Severity.allCases, id: \.self) { severity in
                            Text(severity.label).tag(severity)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Estimated bags")
                    Stepper("\(result.estimatedBags) bag\(result.estimatedBags == 1 ? "" : "s")", value: $result.estimatedBags, in: 1...20)
                        .font(.ecoBodyMedium)
                        .foregroundStyle(Eco.textPrimary)
                }

                VStack(alignment: .leading, spacing: Eco.Space.m) {
                    EcoSectionHeader(title: "Gear", action: ("Regenerate", regenerateGear))
                    VStack(spacing: Eco.Space.s) {
                        ForEach(result.gear) { item in
                            HStack {
                                Image(systemName: item.systemImage)
                                    .foregroundStyle(Eco.primary)
                                Text(item.name)
                                    .font(.ecoBodyMedium)
                                    .foregroundStyle(Eco.textBody)
                                Spacer()
                            }
                        }
                    }
                    .ecoCard()
                }

                Button("Continue", action: onContinue)
                    .buttonStyle(.eco)
                    .disabled(result.wasteTypes.isEmpty)
            }
            .padding(Eco.Space.l)
        }
        .ecoScreenBackground()
    }

    private func toggle(_ type: WasteType) {
        if let index = result.wasteTypes.firstIndex(of: type) {
            result.wasteTypes.remove(at: index)
        } else {
            result.wasteTypes.append(type)
        }
    }

    private func regenerateGear() {
        result.gear = Fixtures.gear(for: result.wasteTypes)
    }
}

/// Minimal wrapping HStack for chips, since the design system doesn't ship a flow layout.
struct FlowChips<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        _FlowLayout(spacing: Eco.Space.s) { content }
    }
}

private struct _FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > maxWidth, origin.x > 0 {
                origin.x = 0
                origin.y += lineHeight + spacing
                totalHeight += lineHeight + spacing
                lineHeight = 0
            }
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        totalHeight += lineHeight
        return CGSize(width: maxWidth == .infinity ? origin.x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x + size.width > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        SpotResultView(
            image: DemoPhoto.image,
            result: .constant(ScannerResult(
                wasteTypes: [.plastic, .glass],
                severity: .medium,
                estimatedBags: 3,
                gear: Fixtures.gear(for: [.plastic, .glass]),
                hazard: .caution,
                peopleNeeded: 2,
                confidence: 0.91,
                modelVersion: "ecoplog-vision-fake-v1"
            )),
            errorMessage: nil,
            onRetry: {},
            onContinue: {}
        )
    }
    .ecoTheme()
}
