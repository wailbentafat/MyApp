import ActivityKit
import SwiftUI
import WidgetKit

struct PlogLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PlogActivityAttributes.self) { context in
            LockScreenView(title: context.attributes.title, state: context.state)
                .activityBackgroundTint(Eco.background)
                .activitySystemActionForegroundColor(Eco.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(PlogFormat.distance(context.state.distanceMeters), systemImage: "figure.walk")
                        .foregroundStyle(Eco.primary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    PlogTimer(state: context.state).font(.title3.monospacedDigit().bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Label("\(context.state.kcal) kcal", systemImage: "flame.fill")
                        Spacer()
                        if let hr = context.state.heartRate {
                            Label("\(hr)", systemImage: "heart.fill")
                            Spacer()
                        }
                        Label("\(context.state.bags) bags", systemImage: "trash.fill")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Eco.textSecondary)
                }
            } compactLeading: {
                Image(systemName: "leaf.fill").foregroundStyle(Eco.primary)
            } compactTrailing: {
                PlogTimer(state: context.state)
                    .font(.caption.monospacedDigit())
                    .frame(width: 48)
            } minimal: {
                Image(systemName: "leaf.fill").foregroundStyle(Eco.primary)
            }
            .keylineTint(Eco.primary)
        }
    }
}

private struct PlogTimer: View {
    let state: PlogActivityAttributes.ContentState

    var body: some View {
        Text(timerInterval: state.timerStart...Date.distantFuture,
             pauseTime: state.pausedAt,
             countsDown: false)
    }
}

private struct LockScreenView: View {
    let title: String
    let state: PlogActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: "leaf.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Eco.primary)
                Spacer()
                if state.isPaused {
                    Text("Paused").font(.caption).foregroundStyle(Eco.warning)
                }
            }
            HStack {
                stat(PlogFormat.distance(state.distanceMeters), "distance")
                Spacer()
                stat(nil, "time") { PlogTimer(state: state) }
                Spacer()
                stat("\(state.kcal)", "kcal")
                Spacer()
                stat("\(state.bags)", "bags")
            }
        }
        .padding()
    }

    private func stat(_ value: String?, _ label: String) -> some View {
        stat(value, label) { EmptyView() }
    }

    private func stat<Content: View>(_ value: String?, _ label: String,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let value { Text(value) } else { content() }
            }
            .font(.title3.monospacedDigit().weight(.bold))
            .foregroundStyle(Eco.textPrimary)
            Text(label).font(.caption2).foregroundStyle(Eco.textSecondary)
        }
    }
}
