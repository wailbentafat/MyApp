import SwiftUI

/// Photo of a Clean-Up (the Spot "Before" photo), or a themed placeholder while there is none.
struct CleanUpPhoto: View {
    let cleanUp: CleanUp
    var height: CGFloat = 150

    var body: some View {
        ZStack {
            if let image = FakePhotoStore.shared.loadImage(cleanUp.beforePhotoURL) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(colors: [Eco.accent, Eco.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
                EcoSymbol(cleanUp.wasteTypes.first?.systemImage ?? "leaf.fill", size: 44)
                    .foregroundStyle(Eco.highlight.opacity(0.55))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

/// Strava "challenge / race" style card: photo with date pill, title, meta, chips, RSVP.
struct CleanUpCard: View {
    let cleanUp: CleanUp
    let subtitle: String
    let rsvpTitle: String
    let isGoing: Bool
    var onOpen: () -> Void
    var onRSVP: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onOpen) {
                CleanUpPhoto(cleanUp: cleanUp)
                    .overlay(alignment: .topLeading) { datePill.padding(Eco.Space.m) }
                    .overlay(alignment: .topTrailing) { hazardBadge.padding(Eco.Space.m) }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: Eco.Space.s) {
                Text(cleanUp.title)
                    .font(.ecoHeadlineSmall)
                    .foregroundStyle(Eco.textPrimary)
                    .lineLimit(2)
                EcoLabel(subtitle, systemImage: "mappin.and.ellipse")
                    .font(.ecoBodySmall)
                    .foregroundStyle(Eco.textSecondary)

                EcoFlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(cleanUp.wasteTypes) { EcoChip(title: $0.label, systemImage: $0.systemImage) }
                }

                HStack {
                    EcoLabel("\(cleanUp.estimatedBags) bags", systemImage: "bag.fill")
                        .font(.ecoLabelMedium)
                        .foregroundStyle(Eco.textSecondary)
                    Spacer()
                    Button(rsvpTitle, action: onRSVP)
                        .font(.ecoLabelLarge)
                        .foregroundStyle(isGoing ? Eco.primary : Eco.onButton)
                        .padding(.horizontal, Eco.Space.l)
                        .padding(.vertical, Eco.Space.s)
                        .background(isGoing ? Eco.selected : Eco.buttonFill, in: Capsule())
                        .disabled(!isGoing && cleanUp.isFull)
                }
            }
            .padding(Eco.Space.m)
        }
        .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.card))
        .clipShape(RoundedRectangle(cornerRadius: Eco.Radius.card))
    }

    @ViewBuilder
    private var datePill: some View {
        if let date = cleanUp.startsAt {
            Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                .font(.ecoLabelMedium)
                .foregroundStyle(Eco.textPrimary)
                .padding(.horizontal, Eco.Space.m)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
        }
    }

    @ViewBuilder
    private var hazardBadge: some View {
        if cleanUp.hazard != .none {
            EcoSymbol("exclamationmark.triangle.fill", size: 16)
                .foregroundStyle(cleanUp.hazard == .hazardous ? Eco.error : Eco.warning)
                .padding(8)
                .glassEffect(.regular, in: .circle)
                .accessibilityLabel("Hazard")
        }
    }
}
