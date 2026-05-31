import SwiftUI
import SwiftData
import CoreBluetooth

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var scooters: [Scooter]
    @Query private var rides: [Ride]
    @ObservedObject var scooterManager: ScooterManager

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 20) {
                    scooterSection
                    connectionSection
                    dataSection
                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(AppBackground { EmptyView() })
    }

    private var header: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 20)
    }

    private var scooterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Scooters")
            SettingsCard {
                if scooters.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.2))
                        Text("No scooters paired")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(scooters) { scooter in
                        SettingScooterRow(scooter: scooter)
                        if scooter.id != scooters.last?.id {
                            Divider().background(.white.opacity(0.04)).padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Connection")
            SettingsCard {
                if scooterManager.isConnected {
                    Divider().background(.white.opacity(0.04)).padding(.leading, 50)
                    SettingActionRow(
                        icon: "xmark.circle",
                        iconColor: .red,
                        label: "Disconnect",
                        description: scooterManager.scanner.connectedPeripheral?.name ?? "Scooter",
                        action: { scooterManager.disconnect() }
                    )
                }
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Data & Storage")
            SettingsCard {
                SettingInfoRow(icon: "clock", iconColor: .orange, label: "Total Rides", value: "\(rides.count)")
                Divider().background(.white.opacity(0.04)).padding(.leading, 50)
                SettingInfoRow(icon: "map", iconColor: .green, label: "Total Distance", value: String(format: "%.2f km", rides.reduce(0) { $0 + $1.distance } / 1000))
                Divider().background(.white.opacity(0.04)).padding(.leading, 50)
                SettingActionRow(icon: "square.and.arrow.up", iconColor: .blue, label: "Export All Data", description: "JSON format", action: exportAllData)
                    .disabled(rides.isEmpty).opacity(rides.isEmpty ? 0.3 : 1)

                if !rides.isEmpty {
                    Divider().background(.white.opacity(0.04)).padding(.leading, 50)
                    SettingActionRow(icon: "trash", iconColor: .red, label: "Delete All Rides", description: "\(rides.count) rides will be removed", action: deleteAllRides)
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("About")
            SettingsCard {
                HStack(spacing: 12) {
                    Image(systemName: "scooter")
                        .font(.system(size: 18))
                        .foregroundStyle(.blue)
                        .frame(width: 36, height: 36)
                        .background(RoundedRectangle(cornerRadius: 8).fill(.blue.opacity(0.12)))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Open Ninebot Ride")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Version 1.0 — EDR & Ride Tracking")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Spacer()
                }
            }
            Text("Records your Ninebot scooter rides with GPS tracking, speed analysis, event detection, and generates EDR evidence reports.")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.2))
                .lineSpacing(4)
                .padding(.horizontal, 4)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
            .tracking(0.8)
            .padding(.leading, 4)
    }

    private func deleteAllRides() {
        for ride in rides {
            if let points = ride.points { for point in points { modelContext.delete(point) } }
            if let events = ride.events { for event in events { modelContext.delete(event) } }
            modelContext.delete(ride)
        }
    }

    private func exportAllData() {
        var exportDict: [String: Any] = [:]
        var rideExports: [[String: Any]] = []
        for ride in rides {
            var dict: [String: Any] = [
                "startDate": ride.startDate, "endDate": ride.endDate ?? "",
                "maxSpeed": ride.maxSpeed, "minSpeed": ride.minSpeed, "averageSpeed": ride.averageSpeed,
                "distance": ride.distance, "maxAcceleration": ride.maxAcceleration, "maxDeceleration": ride.maxDeceleration,
                "events": ride.eventCount, "scooter": ride.scooterName ?? ""
            ]
            if let points = ride.points {
                dict["points"] = points.map { p in
                    ["time": p.timestamp, "lat": p.latitude, "lng": p.longitude, "speed": p.speed,
                     "mode": p.mode, "lights": p.lightsOn, "battery": p.batteryLevel,
                     "acceleration": p.acceleration, "braking": p.isBraking, "event": p.eventType ?? ""]
                }
            }
            rideExports.append(dict)
        }
        exportDict["rides"] = rideExports
        exportDict["exportedAt"] = ISO8601DateFormatter().string(from: Date())
        exportDict["app"] = "Open Ninebot Ride"
        exportDict["version"] = "1.0"
        do {
            let data = try JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Ninebot_Data_Export.json")
            try data.write(to: url)
            if let ws = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let vc = ws.windows.first?.rootViewController {
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let presented = vc.presentedViewController {
                    presented.dismiss(animated: true) {
                        vc.present(activityVC, animated: true)
                    }
                } else {
                    vc.present(activityVC, animated: true)
                }
            }
        } catch { print("Export failed: \(error)") }
    }
}

struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06), lineWidth: 0.5))
            )
    }
}

struct SettingToggleRow: View {
    let icon: String; let iconColor: Color; let label: String; let description: String
    @Binding var isOn: Bool
    var body: some View {
        HStack(spacing: 12) {
            iconBadge(icon: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                Text(description).font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
            }
            Spacer()
            CustomToggle(isOn: $isOn)
        }
        .padding(.vertical, 8)
    }
}

struct SettingActionRow: View {
    let icon: String; let iconColor: Color; let label: String; let description: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBadge(icon: icon, color: iconColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                    Text(description).font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.white.opacity(0.15))
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PressScaleStyle())
    }
}

struct SettingInfoRow: View {
    let icon: String; let iconColor: Color; let label: String; let value: String
    var body: some View {
        HStack(spacing: 12) {
            iconBadge(icon: icon, color: iconColor)
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced)).foregroundStyle(.white.opacity(0.4))
        }
        .padding(.vertical, 8)
    }
}

struct SettingScooterRow: View {
    let scooter: Scooter
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "scooter")
                .font(.system(size: 13))
                .foregroundStyle(.blue)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 7).fill(.blue.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) {
                Text(scooter.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                if let last = scooter.lastConnected {
                    Text("Last seen \(last, style: .date)").font(.system(size: 9)).foregroundStyle(.white.opacity(0.3))
                }
            }
            Spacer()
            Circle().fill(.green).frame(width: 4, height: 4)
        }
        .padding(.vertical, 8)
    }
}

private func iconBadge(icon: String, color: Color) -> some View {
    Image(systemName: icon)
        .font(.system(size: 12))
        .foregroundStyle(color)
        .frame(width: 30, height: 30)
        .background(RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.12)))
}

struct CustomToggle: View {
    @Binding var isOn: Bool
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 10).fill(isOn ? Color.blue : .white.opacity(0.1)).frame(width: 38, height: 22)
                Circle().fill(.white).frame(width: 16, height: 16).padding(3)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}
