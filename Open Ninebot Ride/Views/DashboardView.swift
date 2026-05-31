import SwiftUI

struct DashboardView: View {
    @ObservedObject var scooterManager: ScooterManager
    @State private var rideStartTime: Date = Date()

    private var isConnected: Bool { scooterManager.isConnected }

    var body: some View {
        GeometryReader { geo in
            if geo.size.width > geo.size.height {
                landscapeContent
            } else {
                portraitContent
            }
        }
        .background(Rectangle().fill(Color(red: 0.04, green: 0.04, blue: 0.06)))
        .ignoresSafeArea()
    }

    private var portraitContent: some View {
        ZStack {
            CircularGauge(speed: scooterManager.speed, maxSpeed: 30)
                .frame(width: 240, height: 240)

            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
                recordButton
                    .padding(.bottom, 40)
            }
        }
    }

    private var landscapeContent: some View {
        ZStack {
            CircularGauge(speed: scooterManager.speed, maxSpeed: 30)
                .frame(width: 200, height: 200)

            VStack(spacing: 0) {
                topBar
                Spacer()
                HStack(alignment: .bottom) {
                    HStack(spacing: 16) {
                        lightsIcon
                        batteryIcon
                    }
                    Spacer()
                    voltageLabel
                }
                .padding(.horizontal, 24)
                recordButton
                    .padding(.bottom, 24)
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            modeBadge
            Spacer()
            if isConnected {
                HStack(spacing: 5) {
                    Circle()
                        .fill(.green)
                        .frame(width: 5, height: 5)
                    Text("LIVE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.green)
                        .tracking(1.5)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.green.opacity(0.1)))
            }
        }
        .padding(.top, 64)
        .padding(.horizontal, 24)
    }

    private var bottomBar: some View {
        HStack(alignment: .center) {
            lightsIcon
            Spacer()
            turnSignalIcon
            Spacer()
            batteryIcon
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 4)
    }

    private var turnSignalIcon: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.left.to.line")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(scooterManager.turnSignal == .left ? Color.green : .white.opacity(0.1))
            Image(systemName: "arrow.right.to.line")
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(scooterManager.turnSignal == .right ? Color.green : .white.opacity(0.1))
        }
    }

    private var modeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10))
            Text(scooterManager.mode.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(1)
        }
        .foregroundStyle(modeColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(modeColor.opacity(0.12)))
    }

    private var lightsIcon: some View {
        VStack(spacing: 4) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 18))
                .foregroundStyle(scooterManager.lightsOn ? .yellow : .white.opacity(0.15))
            Text("LIGHTS")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .tracking(1)
        }
    }

    private var batteryIcon: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "battery.\(batteryIconName)")
                    .font(.system(size: 18))
                    .foregroundStyle(batteryColor)
                Text("\(Int(scooterManager.batteryLevel))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(batteryColor)
            }
            Text("BATTERY")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .tracking(1)
        }
    }

    private var voltageLabel: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.shield")
                    .font(.system(size: 12))
                    .foregroundStyle(.cyan)
                Text(String(format: "%.1fV", scooterManager.voltage))
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }
            Text("VOLTAGE")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.2))
                .tracking(1)
        }
    }

    private var recordButton: some View {
        Button {
            if scooterManager.isRecording {
                scooterManager.stopRecording()
            } else {
                scooterManager.startRecording()
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(scooterManager.isRecording ? .red : .white)
                    .frame(width: 7, height: 7)
                Text(scooterManager.isRecording ? "STOP RECORDING" : "START RECORDING")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.5)
            }
            .foregroundStyle(scooterManager.isRecording ? .red : .black)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(
                Group {
                    if scooterManager.isRecording {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.red.opacity(0.08))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.red, lineWidth: 0.5))
                    } else {
                        RoundedRectangle(cornerRadius: 14).fill(.white)
                    }
                }
            )
        }
        .buttonStyle(PressScaleStyle())
    }

    private var modeColor: Color {
        switch scooterManager.mode {
        case "Sport": return .red
        case "Eco": return .green
        default: return .blue
        }
    }

    private var batteryIconName: String {
        if scooterManager.batteryLevel > 75 { return "100" }
        if scooterManager.batteryLevel > 50 { return "75" }
        if scooterManager.batteryLevel > 25 { return "50" }
        return "25"
    }

    private var batteryColor: Color {
        if scooterManager.batteryLevel > 50 { return .green }
        if scooterManager.batteryLevel > 20 { return .yellow }
        return .red
    }
}
