import SwiftUI
import WidgetKit
import ActivityKit

@main
struct RideActivityBundle: WidgetBundle {
    var body: some Widget {
        RideLiveActivity()
    }
}

struct RideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            RideLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    speedView(context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    modeView(context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    durationView(context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    batteryView(context.state)
                }
            } compactLeading: {
                compactSpeed(context.state)
            } compactTrailing: {
                compactRecording(context.state)
            } minimal: {
                Image(systemName: "scooter")
                    .foregroundStyle(.green)
            }
        }
    }

    // MARK: - Compact
    private func compactSpeed(_ state: RideActivityAttributes.ContentState) -> some View {
        HStack(spacing: 2) {
            Text("\(Int(state.speed))")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(speedColor(state.speed))
            Text("km")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func compactRecording(_ state: RideActivityAttributes.ContentState) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(state.isRecording ? .red : .green)
                .frame(width: 6, height: 6)
            Text(state.isRecording ? "REC" : "LIVE")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(state.isRecording ? .red : .green)
        }
    }

    // MARK: - Expanded
    private func speedView(_ state: RideActivityAttributes.ContentState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(Int(state.speed))")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(speedColor(state.speed))
                .contentTransition(.numericText())
            Text("km/h")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func modeView(_ state: RideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 2) {
            Image(systemName: modeIcon(state.mode))
                .font(.system(size: 14))
                .foregroundStyle(modeColor(state.mode))
            Text(state.mode)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(modeColor(state.mode))
        }
    }

    private func durationView(_ state: RideActivityAttributes.ContentState) -> some View {
        VStack(spacing: 2) {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.6))
            Text(durationString(state.duration))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white)
        }
    }

    private func batteryView(_ state: RideActivityAttributes.ContentState) -> some View {
        HStack(spacing: 4) {
            Image(systemName: batteryIcon(state.batteryLevel))
                .font(.system(size: 12))
                .foregroundStyle(batteryColor(state.batteryLevel))
            Text("\(Int(state.batteryLevel))%")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(batteryColor(state.batteryLevel))
        }
    }

    // MARK: - Helpers
    private func speedColor(_ s: Double) -> Color {
        if s < 10 { return Color(red: 0.2, green: 0.8, blue: 0.3) }
        if s < 20 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
        return Color(red: 1.0, green: 0.2, blue: 0.2)
    }

    private func modeIcon(_ m: String) -> String {
        switch m { case "Sport": return "bolt.fill"; case "Eco": return "leaf.fill"; default: return "figure.walk" }
    }

    private func modeColor(_ m: String) -> Color {
        switch m { case "Sport": return .red; case "Eco": return .green; default: return .blue }
    }

    private func batteryIcon(_ b: Double) -> String {
        if b > 75 { return "battery.100" }; if b > 50 { return "battery.75" }; if b > 25 { return "battery.50" }; return "battery.25"
    }

    private func batteryColor(_ b: Double) -> Color {
        if b > 50 { return .green }; if b > 20 { return .yellow }; return .red
    }

    private func durationString(_ d: TimeInterval) -> String {
        let m = Int(d) / 60; let s = Int(d) % 60
        return String(format: "%d:%02d", m, s)
    }
}
