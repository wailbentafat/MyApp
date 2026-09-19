import SwiftUI

/// Strava's "Your activity streak" card: flame with count, message, and a call to action.
struct StreakCard: View {
    let badge: String
    let message: String
    var actionTitle = "Start"
    var onAction: () -> Void

    var body: some View {
        HStack(spacing: Eco.Space.l) {
            ZStack {
                EcoSymbol("flame.fill", size: 52)
                    .foregroundStyle(badge == "0" ? Eco.textHint : Eco.warning)
                Text(badge)
                    .font(.ecoHeadlineSmall)
                    .foregroundStyle(Eco.textPrimary)
                    .offset(y: 8)
            }
            .frame(width: 64)

            Text(message)
                .font(.ecoBodyMedium)
                .foregroundStyle(Eco.textBody)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(actionTitle, action: onAction)
                .font(.ecoLabelLarge)
                .foregroundStyle(Eco.onButton)
                .padding(.horizontal, Eco.Space.l)
                .padding(.vertical, Eco.Space.m)
                .background(Eco.buttonFill, in: Capsule())
        }
        .padding(Eco.Space.l)
        .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.card))
        .accessibilityElement(children: .combine)
    }
}
