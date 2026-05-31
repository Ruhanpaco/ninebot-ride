import SwiftUI

struct BlackBoxView: View {
    let points: [RidePoint]
    let events: [EventRecord]

    @State private var selectedFilter = "all"
    @State private var sortAscending = true

    private var sortedPoints: [RidePoint] {
        let s = points.sorted { sortAscending ? $0.timestamp < $1.timestamp : $0.timestamp > $1.timestamp }
        switch selectedFilter {
        case "events": return s.filter { $0.isEvent }
        case "braking": return s.filter { $0.isBraking }
        case "high_speed": return s.filter { $0.speed > 20 }
        default: return s
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            if sortedPoints.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(.white.opacity(0.06))
                    Text("No Data Points").font(.system(size: 13, weight: .semibold)).foregroundStyle(.white.opacity(0.2))
                    Spacer()
                }
            } else {
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        headerRow
                        ForEach(Array(sortedPoints.enumerated()), id: \.element.id) { i, p in
                            DataRow(point: p, index: i)
                            Divider().background(.white.opacity(0.03))
                        }
                    }
                }
            }
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.06))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(label: "All", count: points.count, filter: "all", selected: $selectedFilter)
                FilterChip(label: "Events", count: points.filter(\.isEvent).count, filter: "events", selected: $selectedFilter)
                FilterChip(label: "Braking", count: points.filter(\.isBraking).count, filter: "braking", selected: $selectedFilter)
                FilterChip(label: "High Speed", count: points.filter { $0.speed > 20 }.count, filter: "high_speed", selected: $selectedFilter)
                Button {
                    withAnimation { sortAscending.toggle() }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: sortAscending ? "arrow.up" : "arrow.down").font(.system(size: 8))
                        Text(sortAscending ? "Oldest" : "Newest").font(.system(size: 9))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.08, green: 0.08, blue: 0.12)).overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.06), lineWidth: 0.5)))
                }
                .buttonStyle(PressScaleStyle())
            }
            .padding(.horizontal, 20).padding(.vertical, 8)
        }
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("Time").frame(width: 60, alignment: .leading)
            Text("Speed").frame(width: 44, alignment: .trailing)
            Text("Accel").frame(width: 44, alignment: .trailing)
            Text("Brake").frame(width: 38, alignment: .center)
            Text("Mode").frame(width: 44, alignment: .center)
            Text("Bat").frame(width: 38, alignment: .trailing)
            Text("Event").frame(minWidth: 68, alignment: .leading)
        }
        .font(.system(size: 8, weight: .semibold))
        .foregroundStyle(.white.opacity(0.25))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
    }
}

struct DataRow: View {
    let point: RidePoint; let index: Int
    private var rowColor: Color {
        if point.eventType == "hard_brake" { return .red.opacity(0.06) }
        if point.eventType == "rapid_accel" { return .yellow.opacity(0.06) }
        if point.isEvent { return .orange.opacity(0.04) }
        return .clear
    }
    var body: some View {
        HStack(spacing: 0) {
            Text(point.timestamp, style: .time).font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.5)).frame(width: 60, alignment: .leading)
            Text(String(format: "%.1f", point.speed)).font(.system(size: 8, design: .monospaced)).foregroundStyle(speedColor(point.speed)).frame(width: 44, alignment: .trailing)
            Text(String(format: "%.1f", point.acceleration)).font(.system(size: 8, design: .monospaced)).foregroundStyle(point.acceleration > 0 ? .green.opacity(0.7) : (point.acceleration < 0 ? .red.opacity(0.7) : .white.opacity(0.2))).frame(width: 44, alignment: .trailing)
            Text(point.isBraking ? "YES" : "no").font(.system(size: 7, design: .monospaced)).foregroundStyle(point.isBraking ? .red : .white.opacity(0.15)).frame(width: 38, alignment: .center)
            Text(point.mode.prefix(3)).font(.system(size: 7, design: .monospaced)).foregroundStyle(modeColor(point.mode)).frame(width: 44, alignment: .center)
            Text("\(Int(point.batteryLevel))%").font(.system(size: 8, design: .monospaced)).foregroundStyle(.white.opacity(0.4)).frame(width: 38, alignment: .trailing)
            Text(point.eventType ?? "").font(.system(size: 7)).foregroundStyle(point.isEvent ? .red : .clear).frame(minWidth: 68, alignment: .leading)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(rowColor)
    }
    private func speedColor(_ s: Double) -> Color { s < 10 ? .green.opacity(0.8) : s < 20 ? .yellow.opacity(0.8) : .red.opacity(0.8) }
    private func modeColor(_ m: String) -> Color { switch m { case "Sport": return .red; case "Eco": return .green; default: return .blue } }
}

struct FilterChip: View {
    let label: String; let count: Int; let filter: String
    @Binding var selected: String
    var body: some View {
        Button {
            withAnimation(.snappy) { selected = filter }
        } label: {
            HStack(spacing: 3) {
                Text(label).font(.system(size: 9, weight: selected == filter ? .semibold : .medium))
                Text("(\(count))").font(.system(size: 7))
            }
            .foregroundStyle(selected == filter ? .white : .white.opacity(0.35))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected == filter ? Color.blue : Color(red: 0.08, green: 0.08, blue: 0.12)).overlay(RoundedRectangle(cornerRadius: 8).stroke(selected == filter ? Color.blue.opacity(0.3) : .white.opacity(0.06), lineWidth: 0.5)))
        }
        .buttonStyle(PressScaleStyle())
    }
}
