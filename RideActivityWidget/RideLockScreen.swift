import SwiftUI
import WidgetKit
import ActivityKit

struct RideLockScreenView: View {
    let context: ActivityViewContext<RideActivityAttributes>

    var body: some View {
        HStack(spacing: 0) {
            // Speed
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(context.state.speed))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(speedColor)
                    .contentTransition(.numericText())
                Text("km/h")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
                .background(.white.opacity(0.1))
                .frame(height: 40)

            // Mode + Duration
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: modeIcon)
                        .font(.system(size: 11))
                    Text(context.state.mode)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(modeColor)

                HStack(spacing: 4) {
                    Circle()
                        .fill(context.state.isRecording ? .red : .green)
                        .frame(width: 5, height: 5)
                    Text(context.state.isRecording ? "REC" : "LIVE")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(context.state.isRecording ? .red : .green)
                }
            }
            .frame(maxWidth: .infinity)

            Divider()
                .background(.white.opacity(0.1))
                .frame(height: 40)

            // Battery
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: batteryIcon)
                        .font(.system(size: 12))
                    Text("\(Int(context.state.batteryLevel))%")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                }
                .foregroundStyle(batteryColor)

                Text(durationString)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var speedColor: Color {
        let s = context.state.speed
        if s < 10 { return Color(red: 0.2, green: 0.8, blue: 0.3) }
        if s < 20 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
        return Color(red: 1.0, green: 0.2, blue: 0.2)
    }

    private var modeIcon: String {
        switch context.state.mode { case "Sport": return "bolt.fill"; case "Eco": return "leaf.fill"; default: return "figure.walk" }
    }

    private var modeColor: Color {
        switch context.state.mode { case "Sport": return .red; case "Eco": return .green; default: return .blue }
    }

    private var batteryIcon: String {
        let b = context.state.batteryLevel
        if b > 75 { return "battery.100" }; if b > 50 { return "battery.75" }; if b > 25 { return "battery.50" }; return "battery.25"
    }

    private var batteryColor: Color {
        let b = context.state.batteryLevel
        if b > 50 { return .green }; if b > 20 { return .yellow }; return .red
    }

    private var durationString: String {
        let d = context.state.duration
        let m = Int(d) / 60; let s = Int(d) % 60
        return String(format: "%d:%02d", m, s)
    }
}
