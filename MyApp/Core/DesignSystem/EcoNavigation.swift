import SwiftUI

// MARK: - Circle icon button (Liquid Glass)

/// Round icon button like Strava's top-bar buttons, rendered with iOS 26 Liquid Glass.
struct EcoCircleButton: View {
    let systemImage: String
    let label: String
    var badge = false
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            EcoSymbol(systemImage, size: size * 0.5)
                .foregroundStyle(Eco.textPrimary)
                .frame(width: size, height: size)
                .overlay(alignment: .topTrailing) {
                    if badge {
                        Circle().fill(Eco.error).frame(width: 10, height: 10).offset(x: -6, y: 6)
                    }
                }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(label)
    }
}

// MARK: - Top bar

/// Strava-style top bar: round buttons on both sides and a centered title/wordmark.
struct EcoTopBar<Leading: View, Trailing: View>: View {
    let title: String
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(.ecoHeadlineSmall)
                .foregroundStyle(Eco.textPrimary)
            HStack(spacing: Eco.Space.s) {
                leading
                Spacer(minLength: 0)
                trailing
            }
        }
        .padding(.horizontal, Eco.Space.l)
        .padding(.vertical, Eco.Space.s)
    }
}

// MARK: - Sub tabs with underline (You: Progress / Activities / Gallery / More, Clean-Ups: Upcoming / Near you / Done)

struct EcoSegmentItem<Tab: Hashable>: Identifiable {
    let tab: Tab
    let title: String
    var systemImage: String? = nil
    var id: Tab { tab }
}

struct EcoSegmentedTabs<Tab: Hashable>: View {
    let items: [EcoSegmentItem<Tab>]
    @Binding var selection: Tab

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = item.tab == selection
                Button {
                    withAnimation(.smooth(duration: 0.25)) { selection = item.tab }
                } label: {
                    VStack(spacing: Eco.Space.xs) {
                        if let systemImage = item.systemImage {
                            EcoSymbol(systemImage, size: 22)
                        }
                        Text(item.title).font(.ecoLabelMedium)
                        ZStack {
                            Rectangle().fill(.clear).frame(height: 3)
                            if isSelected {
                                Rectangle()
                                    .fill(Eco.primary)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                    }
                    .foregroundStyle(isSelected ? Eco.textPrimary : Eco.textSecondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Eco.border).frame(height: 1) }
    }
}

// MARK: - Stats row (Strava: Distance · Pace · Time · Performances)

struct EcoStat: Identifiable {
    let label: String
    let value: String
    var id: String { label }
}

struct EcoStatRow: View {
    let stats: [EcoStat]

    var body: some View {
        HStack(alignment: .top, spacing: Eco.Space.l) {
            ForEach(stats) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.label)
                        .font(.ecoBodySmall)
                        .foregroundStyle(Eco.textSecondary)
                    Text(stat.value)
                        .font(.ecoTitleLarge)
                        .monospacedDigit()
                        .foregroundStyle(Eco.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                if stat.id != stats.last?.id { Spacer(minLength: 0) }
            }
        }
    }
}

// MARK: - Banner (Strava's PR banner → EcoPlog impact banner)

struct EcoBanner: View {
    let systemImage: String
    let title: String
    var subtitle: String? = nil
    var tint: Color = Eco.primary

    var body: some View {
        HStack(spacing: Eco.Space.m) {
            EcoSymbol(systemImage, size: 22)
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.ecoTitleMedium)
                    .foregroundStyle(Eco.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle).font(.ecoBodySmall).foregroundStyle(Eco.textSecondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(Eco.Space.m)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(Eco.surface, in: RoundedRectangle(cornerRadius: Eco.Radius.field))
    }
}

// MARK: - Date badge (Strava events: SEPT / 20 / DIM)

struct EcoDateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text(date.formatted(.dateTime.month(.abbreviated)).uppercased())
                .font(.ecoLabelSmall)
                .tracking(0.8)
                .foregroundStyle(Eco.onPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
                .background(Eco.primary)
            Text(date.formatted(.dateTime.day()))
                .font(.ecoHeadlineMedium)
                .foregroundStyle(Eco.background)
            Text(date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                .font(.ecoLabelSmall)
                .foregroundStyle(Eco.background.opacity(0.6))
                .padding(.bottom, 4)
        }
        .frame(width: 58)
        .background(.white, in: RoundedRectangle(cornerRadius: 8))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
    }
}
