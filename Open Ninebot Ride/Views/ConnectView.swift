import SwiftUI
import CoreBluetooth

struct ConnectView: View {
    @ObservedObject var scooterManager: ScooterManager
    @State private var showPicker = false
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer()

            if scooterManager.isConnected {
                connectedState
            } else if scooterManager.connectionState == .scanning {
                scanningState
            } else {
                disconnectedState
            }

            Spacer()

            if scooterManager.isConnected {
                connectedFooter
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .background(AppBackground { EmptyView() })
        .sheet(isPresented: $showPicker) {
            ScooterPickerView(scanner: scooterManager.scanner, scooterManager: scooterManager)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Connect")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                Text(scooterManager.isConnected ? "Scooter linked" : "Awaiting pairing")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }
            Spacer()
            Image(systemName: "scooter")
                .font(.system(size: 22))
                .foregroundStyle(.blue)
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
    }

    private var disconnectedState: some View {
        VStack(spacing: 24) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 42))
                .foregroundStyle(.blue.opacity(0.5))

            VStack(spacing: 4) {
                Text("No Scooter Connected")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Power on your Ninebot and tap below")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Button {
                showPicker = true
            } label: {
                Text("Scan for Scooters")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(.blue))
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private var scanningState: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 2)
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .fill(Color.blue)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundStyle(.blue)
            }
            .onAppear { isAnimating = true }

            VStack(spacing: 4) {
                Text("Scanning")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .tracking(1.5)
                Text("Looking for Ninebot scooters")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Button {
                scooterManager.stopScan()
            } label: {
                Text("Cancel")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.08)))
            }
            .buttonStyle(PressScaleStyle())
        }
    }

    private var connectedState: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text(scooterManager.scanner.connectedPeripheral?.name ?? "Ninebot Scooter")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)

            if scooterManager.scooterModel != .unknown {
                Text(scooterManager.scooterModel.displayName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.35))
                    .tracking(1)
            }

            authStateBadge

            HStack(spacing: 12) {
                Label("\(Int(scooterManager.batteryLevel))%", systemImage: "battery.\(batteryIcon)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(batteryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(batteryColor.opacity(0.12)))

                Label(scooterManager.mode, systemImage: modeIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(modeColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(modeColor.opacity(0.12)))
            }
        }
    }

    @ViewBuilder
    private var authStateBadge: some View {
        switch scooterManager.authState {
        case .idle:
            EmptyView()
        case .preComm, .setPwd, .auth:
            HStack(spacing: 4) {
                ProgressView().tint(.yellow).scaleEffect(0.7)
                Text("Authenticating...")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
            }
        case .complete:
            EmptyView()
        case .failed(let reason):
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
                Text(reason)
                    .font(.system(size: 9))
                    .foregroundStyle(.red.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }

    private var connectedFooter: some View {
        HStack {
            Circle().fill(.green).frame(width: 5, height: 5)
            Text("Live connection")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Button {
                scooterManager.disconnect()
            } label: {
                Text("Disconnect")
                    .font(.system(size: 11))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(PressScaleStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    private var batteryIcon: Int {
        if scooterManager.batteryLevel > 75 { return 100 }
        if scooterManager.batteryLevel > 50 { return 75 }
        if scooterManager.batteryLevel > 25 { return 50 }
        return 25
    }

    private var batteryColor: Color {
        if scooterManager.batteryLevel > 50 { return .green }
        if scooterManager.batteryLevel > 20 { return .yellow }
        return .red
    }

    private var modeIcon: String {
        switch scooterManager.mode {
        case "Sport": return "bolt"
        case "Eco": return "leaf"
        default: return "figure.walk"
        }
    }

    private var modeColor: Color {
        switch scooterManager.mode {
        case "Sport": return .red
        case "Eco": return .green
        default: return .blue
        }
    }
}
