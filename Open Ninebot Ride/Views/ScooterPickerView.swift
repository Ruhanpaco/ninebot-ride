import SwiftUI
import CoreBluetooth

struct ScooterPickerView: View {
    @ObservedObject var scanner: BLEScanner
    @ObservedObject var scooterManager: ScooterManager
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Text("Cancel").font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text("Select Scooter").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Spacer()
                Button {
                    scanner.isScanning ? scanner.stopScanning() : scanner.startScanning()
                } label: {
                    Text(scanner.isScanning ? "Stop" : "Scan").font(.system(size: 12)).foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)

            Divider().background(.white.opacity(0.05))

            if scanner.discoveredPeripherals.isEmpty && scanner.isScanning {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Scanning for Ninebot scooters...").font(.system(size: 12)).foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
            } else if !scanner.isScanning && scanner.discoveredPeripherals.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "sensor.fill").font(.system(size: 28)).foregroundStyle(.white.opacity(0.08))
                    Text("No Scooters Found").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
                    Text("Make sure your Ninebot scooter is powered on and nearby").font(.system(size: 11)).foregroundStyle(.white.opacity(0.15)).multilineTextAlignment(.center)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(scanner.discoveredPeripherals, id: \.identifier) { peripheral in
                            Button {
                                connect(to: peripheral)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "scooter")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.blue)
                                        .frame(width: 36, height: 36)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(.blue.opacity(0.1)))

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(peripheral.name ?? "Unknown").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                                        Text(peripheral.identifier.uuidString.prefix(8).uppercased()).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.25))
                                    }

                                    Spacer()

                                    if isConnecting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.white.opacity(0.12))
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06), lineWidth: 0.5))
                                )
                            }
                            .disabled(isConnecting)
                            .buttonStyle(PressScaleStyle())
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12)
                }
            }
        }
        .background(AppBackground { EmptyView() })
        .onAppear { scanner.startScanning() }
        .onDisappear { if !isConnecting { scanner.stopScanning() } }
    }

    private func connect(to peripheral: CBPeripheral) {
        isConnecting = true
        Task {
            let success = await scooterManager.connect(to: peripheral)
            isConnecting = false
            if success { dismiss() }
        }
    }
}
