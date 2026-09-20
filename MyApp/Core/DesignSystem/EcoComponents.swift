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
                        .stroke(Eco.buttonFill, lineWidth: 1.5)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Eco.onButton
        case .secondary: Eco.buttonFill
        case .destructive: .white
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Eco.buttonFill
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

// MARK: - Round button (Strava-style Record / Pause)

struct EcoRoundButtonStyle: ButtonStyle {
    var size: CGFloat = 88
    var filled = true
    var tint: Color = Eco.buttonFill

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ecoTitleLarge)
            .foregroundStyle(filled ? Eco.onButton : tint)
            .frame(width: size, height: size)
            .background(filled ? tint : Eco.surface, in: Circle())
            .overlay(Circle().stroke(filled ? .clear : Eco.border, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == EcoRoundButtonStyle {
    static func ecoRound(size: CGFloat = 88, filled: Bool = true, tint: Color = Eco.buttonFill) -> EcoRoundButtonStyle {
        EcoRoundButtonStyle(size: size, filled: filled, tint: tint)
    }
}

// MARK: - Metric (Strava-style: small caps label above a big number)

struct EcoMetric: View {
    enum Size { case regular, hero }

    let label: String
    let value: String
    var unit: String? = nil
    var size: Size = .regular

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.ecoLabelSmall)
                .tracking(0.8)
                .foregroundStyle(Eco.textSecondary)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(size == .hero ? .ecoHero : .ecoStat)
                    .monospacedDigit()
                    .foregroundStyle(Eco.textPrimary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let unit {
                    Text(unit)
                        .font(.ecoLabelMedium)
                        .foregroundStyle(Eco.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue("\(value) \(unit ?? "")")
    }
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
                EcoSymbol(systemImage, size: 16)
                    .foregroundStyle(Eco.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Eco.surfaceRaised, in: Circle())
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
            if let systemImage { EcoSymbol(systemImage, size: 14) }
            Text(title).lineLimit(1)
        }
        .fixedSize()
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
            Text(AppInfo.name).font(.ecoDisplayLarge).foregroundStyle(Eco.textPrimary)
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

// MARK: - Photo (layout-safe)

/// A photo that always fills the width it is given and never makes its parent wider.
/// `scaledToFill()` reports the image's own (larger) size to layout, which used to push cards past the screen edge;
/// putting the image in an `overlay` of a clear, fixed-height view keeps layout independent of the image.
struct EcoPhoto<Placeholder: View>: View {
    let image: UIImage?
    var height: CGFloat = 150
    var cornerRadius: CGFloat = Eco.Radius.field
    @ViewBuilder var placeholder: Placeholder

    var body: some View {
        Color.clear
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension EcoPhoto where Placeholder == AnyView {
    /// Default placeholder: raised surface with a photo icon (never an empty box).
    init(image: UIImage?, height: CGFloat = 150, cornerRadius: CGFloat = Eco.Radius.field) {
        self.image = image
        self.height = height
        self.cornerRadius = cornerRadius
        self.placeholder = AnyView(
            Eco.surfaceRaised.overlay(EcoSymbol("photo", size: 28).foregroundStyle(Eco.textHint))
        )
    }
}

// MARK: - Avatar (initials, no empty placeholder images)

struct EcoAvatar: View {
    let name: String
    var size: CGFloat = 40

    private static let tints: [Color] = [
        EcoPalette.brand.s500, EcoPalette.info.s500, EcoPalette.warning.s400,
        EcoPalette.success.s400, EcoPalette.error.s400, EcoPalette.brand.s700,
    ]

    private var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    private var tint: Color {
        Self.tints[abs(name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }) % Self.tints.count]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(Eco.onPrimary)
            .frame(width: size, height: size)
            .background(tint, in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Calendar strip (Clean-Ups tab)

struct EcoCalendarDay: Identifiable {
    let date: Date
    let eventCount: Int
    var id: Date { date }
}

/// Horizontal strip of days with a dot under days that have Clean-Ups; the selected day is a white pill.
struct EcoCalendarStrip: View {
    let days: [EcoCalendarDay]
    let selected: Date?
    var onSelect: (Date) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Eco.Space.s) {
                ForEach(days) { day in
                    let isSelected = selected.map { Calendar.current.isDate($0, inSameDayAs: day.date) } ?? false
                    Button { onSelect(day.date) } label: {
                        VStack(spacing: 6) {
                            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.ecoLabelSmall)
                                .foregroundStyle(isSelected ? Eco.onButton.opacity(0.7) : Eco.textSecondary)
                            Text(day.date.formatted(.dateTime.day()))
                                .font(.ecoTitleLarge)
                                .foregroundStyle(isSelected ? Eco.onButton : Eco.textPrimary)
                            Circle()
                                .fill(day.eventCount > 0 ? (isSelected ? Eco.onButton : Eco.primary) : .clear)
                                .frame(width: 5, height: 5)
                        }
                        .frame(width: 46, height: 72)
                        .background(isSelected ? Eco.buttonFill : Eco.surface, in: RoundedRectangle(cornerRadius: 23))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
                    .accessibilityValue(day.eventCount == 0 ? "No Clean-Ups" : "\(day.eventCount) Clean-Ups")
                }
            }
            .padding(.horizontal, Eco.Space.l)
        }
    }
}

// MARK: - Input bar (comment composer)

/// Glass text field with a white circular send button, for `safeAreaInset(edge: .bottom)`.
struct EcoInputBar: View {
    @Binding var text: String
    var placeholder: String
    var canSend: Bool
    var isSending = false
    var onSend: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: Eco.Space.s) {
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.ecoBodyMedium)
                .foregroundStyle(Eco.textPrimary)
                .padding(.horizontal, Eco.Space.l)
                .padding(.vertical, Eco.Space.m)
                .glassEffect(.regular, in: .rect(cornerRadius: 22))

            Button(action: onSend) {
                Group {
                    if isSending {
                        ProgressView().tint(Eco.onButton)
                    } else {
                        EcoSymbol("paperplane.fill", size: 20)
                    }
                }
                .foregroundStyle(Eco.onButton)
                .frame(width: 46, height: 46)
                .background(Eco.buttonFill.opacity(canSend ? 1 : 0.4), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send comment")
        }
        .padding(.horizontal, Eco.Space.l)
        .padding(.vertical, Eco.Space.s)
    }
}
