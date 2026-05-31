import SwiftUI
import SwiftData

struct RideDetailView: View {
    @Bindable var ride: Ride
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab: DetailTab = .overview
    @State private var showExportAlert = false
    @State private var exportResult: String?

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case blackbox = "Black Box"
        case map = "Map"
    }

    var body: some View {
        VStack(spacing: 0) {
            customSegmentedPicker
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

            Group {
                switch selectedTab {
                case .overview:
                    overviewTab
                case .blackbox:
                    BlackBoxView(
                        points: ride.points?.sorted(by: { $0.timestamp < $1.timestamp }) ?? [],
                        events: ride.events?.sorted(by: { $0.timestamp < $1.timestamp }) ?? []
                    )
                case .map:
                    mapTab
                }
            }
        }
        .background(AppBackground { EmptyView() })
        .navigationTitle("Ride Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { exportPDF() } label: {
                    Image(systemName: "doc.badge.arrow.up")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .disabled(ride.points?.isEmpty ?? true)
            }
        }
        .alert("Evidence Report", isPresented: $showExportAlert) {
            Button("OK") {}
        } message: {
            Text(exportResult ?? "")
        }
    }

    private var customSegmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.snappy) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 11, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .white : .white.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color(red: 0.12, green: 0.12, blue: 0.16) : .clear)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(3)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var overviewTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsGrid
                eventLog
            }
            .padding(20)
        }
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            StatTile(title: "Top Speed", value: String(format: "%.1f", ride.maxSpeed), unit: "km/h", color: .red)
            StatTile(title: "Avg Speed", value: String(format: "%.1f", ride.averageSpeed), unit: "km/h", color: .blue)
            StatTile(title: "Low Speed", value: String(format: "%.1f", ride.minSpeed == .greatestFiniteMagnitude ? 0 : ride.minSpeed), unit: "km/h", color: .green)
            StatTile(title: "Distance", value: String(format: "%.0f", ride.distance), unit: "m", color: .orange)
            StatTile(title: "Max Accel", value: String(format: "%.1f", ride.maxAcceleration), unit: "m/s²", color: .yellow)
            StatTile(title: "Max Decel", value: String(format: "%.1f", ride.maxDeceleration), unit: "m/s²", color: .purple)
            StatTile(title: "Events", value: "\(ride.eventCount)", unit: "total", color: .red)
            StatTile(title: "Duration", value: durationString, unit: "", color: .secondary)
            if let s = ride.scooterName {
                StatTile(title: "Scooter", value: s, unit: "", color: .gray)
            }
        }
    }

    private var durationString: String {
        guard let end = ride.endDate else { return "In progress" }
        let d = end.timeIntervalSince(ride.startDate)
        let h = Int(d) / 3600; let m = (Int(d) % 3600) / 60; let s = Int(d) % 60
        return h > 0 ? "\(h)h \(m)m \(s)s" : "\(m)m \(s)s"
    }

    private var eventLog: some View {
        Group {
            if let events = ride.events, !events.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Event Log")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .tracking(0.5)
                        .padding(.leading, 4)

                    ForEach(events.sorted(by: { $0.timestamp < $1.timestamp })) { event in
                        HStack(spacing: 10) {
                            Image(systemName: eventIcon(event.eventType))
                                .font(.system(size: 10))
                                .foregroundStyle(eventColor(event.eventType))
                                .frame(width: 22, height: 22)
                                .background(RoundedRectangle(cornerRadius: 6).fill(eventColor(event.eventType).opacity(0.1)))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(event.eventDescription)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("\(event.timestamp, style: .time) · \(String(format: "%.1f", event.speed)) km/h")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(eventColor(event.eventType).opacity(0.15), lineWidth: 0.5))
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func eventIcon(_ t: String) -> String {
        switch t { case "hard_brake": return "xmark.circle.fill"; case "rapid_accel": return "bolt.fill"; case "mode_change": return "arrow.triangle.swap"; default: return "exclamationmark.circle" }
    }
    private func eventColor(_ t: String) -> Color {
        switch t { case "hard_brake": return .red; case "rapid_accel": return .yellow; case "mode_change": return .blue; default: return .orange }
    }

    private var mapTab: some View {
        MapWithRouteView(
            routePoints: ride.points?.sorted(by: { $0.timestamp < $1.timestamp }) ?? [],
            currentSpeed: 0, currentMode: "", lightsOn: false
        )
        .ignoresSafeArea()
    }

    private func exportPDF() {
        guard let data = PDFExporter.generateEvidenceReport(ride: ride) else {
            exportResult = "No ride data to export"; showExportAlert = true; return
        }
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd_HHmmss"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Ninebot_EDR_\(df.string(from: ride.startDate)).pdf")
        do {
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
        } catch { exportResult = "Error: \(error.localizedDescription)"; showExportAlert = true }
    }
}

struct StatTile: View {
    let title: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(color).minimumScaleFactor(0.6)
            if !unit.isEmpty { Text(unit).font(.system(size: 7)).foregroundStyle(.white.opacity(0.25)) }
            Text(title).font(.system(size: 8)).foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.15), lineWidth: 0.5))
        )
    }
}
