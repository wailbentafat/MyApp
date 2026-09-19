import SwiftUI

// MARK: - Theme entry point

extension View {
    /// Apply once at the app root: dark-green background, forced dark scheme, brand tint.
    func ecoTheme() -> some View {
        self
            .tint(Eco.primary)
            .preferredColorScheme(.dark)
            .foregroundStyle(Eco.textBody)
            .background(Eco.background.ignoresSafeArea())
    }

    /// Screen container background for pushed / sheet screens.
    func ecoScreenBackground() -> some View {
        background(Eco.background.ignoresSafeArea())
    }
}

// MARK: - Buttons

struct EcoButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }

    var kind: Kind = .primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ecoLabelLarge)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Eco.Space.xl)
            .padding(.vertical, 14)
            .background(background, in: RoundedRectangle(cornerRadius: Eco.Radius.button))
            .overlay {
                if kind == .secondary {
                    RoundedRectangle(cornerRadius: Eco.Radius.button)
                        .stroke(Eco.primary, lineWidth: 1.5)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        kind == .secondary ? Eco.primary : Eco.onPrimary
    }

    private var background: Color {
        switch kind {
        case .primary: Eco.primary
        case .secondary: .clear
        case .destructive: Eco.error
        }
    }
}

extension ButtonStyle where Self == EcoButtonStyle {
    static var eco: EcoButtonStyle { EcoButtonStyle() }
    static var ecoSecondary: EcoButtonStyle { EcoButtonStyle(kind: .secondary) }
    static var ecoDestructive: EcoButtonStyle { EcoButtonStyle(kind: .destructive) }
}

// MARK: - Card

struct EcoCardModifier: ViewModifier {
    var padding: CGFloat = Eco.Space.l

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Eco.Radius.card)
                    .stroke(Eco.border, lineWidth: 1)
            )
    }
}

extension View {
    func ecoCard(padding: CGFloat = Eco.Space.l) -> some View {
        modifier(EcoCardModifier(padding: padding))
    }
}

// MARK: - Text field

struct EcoTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.ecoBodyMedium)
            .foregroundStyle(Eco.textPrimary)
            .padding(.horizontal, Eco.Space.l)
            .padding(.vertical, 14)
            .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.field))
            .overlay(
                RoundedRectangle(cornerRadius: Eco.Radius.field)
                    .stroke(Eco.border, lineWidth: 1)
            )
    }
}

// MARK: - Stat tile (distance, time, kcal, bags…)

struct EcoStatTile: View {
    let value: String
    let label: String
    var systemImage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Eco.Space.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.ecoLabelMedium)
                    .foregroundStyle(Eco.primary)
                    .frame(width: 28, height: 28)
                    .background(Eco.selected, in: Circle())
            }
            Text(value)
                .font(.ecoStat)
                .foregroundStyle(Eco.textPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.ecoLabelMedium)
                .foregroundStyle(Eco.textSecondary)
        }
        .ecoCard()
    }
}

// MARK: - Chip (waste types, gear, filters)

struct EcoChip: View {
    let title: String
    var systemImage: String? = nil
    var isSelected = false

    var body: some View {
        HStack(spacing: Eco.Space.xs) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.ecoLabelMedium)
        .foregroundStyle(isSelected ? Eco.highlight : Eco.textSecondary)
        .padding(.horizontal, Eco.Space.m)
        .padding(.vertical, Eco.Space.s)
        .background(isSelected ? Eco.selected : Eco.surface, in: Capsule())
        .overlay(Capsule().stroke(isSelected ? Eco.primary : Eco.border, lineWidth: 1))
    }
}

// MARK: - Section header

struct EcoSectionHeader: View {
    let title: String
    var action: (title: String, run: () -> Void)? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.ecoHeadlineSmall)
                .foregroundStyle(Eco.textPrimary)
            Spacer()
            if let action {
                Button(action.title, action: action.run)
                    .font(.ecoLabelMedium)
                    .foregroundStyle(Eco.primary)
            }
        }
    }
}

// MARK: - Preview / living style guide

#Preview("Design system") {
    ScrollView {
        VStack(alignment: .leading, spacing: Eco.Space.xl) {
            Text("EcoPlog").font(.ecoDisplayLarge).foregroundStyle(Eco.textPrimary)
            Text("Turn every run into a cleanup.").font(.ecoBodyLarge)

            HStack {
                EcoStatTile(value: "5.2 km", label: "Distance", systemImage: "figure.walk")
                EcoStatTile(value: "312", label: "kcal", systemImage: "flame.fill")
            }

            EcoSectionHeader(title: "Waste detected", action: ("Edit", {}))
            HStack {
                EcoChip(title: "Plastic", systemImage: "bag", isSelected: true)
                EcoChip(title: "Glass")
                EcoChip(title: "Bulk item")
            }

            TextField("Beacon title", text: .constant(""))
                .textFieldStyle(EcoTextFieldStyle())

            Button("Start Plog") {}.buttonStyle(.eco)
            Button("Save draft") {}.buttonStyle(.ecoSecondary)
            Button("Delete") {}.buttonStyle(.ecoDestructive)
            Button("Disabled") {}.buttonStyle(.eco).disabled(true)
        }
        .padding(Eco.Space.l)
    }
    .ecoTheme()
}
