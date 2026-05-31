import SwiftUI
import SwiftData

struct RideHistoryView: View {
    @Query(sort: \Ride.startDate, order: .reverse) var rides: [Ride]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if rides.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(rides) { ride in
                                NavigationLink {
                                    RideDetailView(ride: ride)
                                } label: {
                                    RideRow(ride: ride)
                                }
                                .buttonStyle(PressScaleStyle())
                            }
                            .onDelete(perform: deleteRides)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 30)
                    }
                }
            }
            .background(AppBackground { EmptyView() })
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack {
            Text("History")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
            Spacer()
            if !rides.isEmpty {
                Text("\(rides.count) rides")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "scooter")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.08))
            Text("No Rides Yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
            Text("Connect your Ninebot and start a ride")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.15))
            Spacer()
        }
    }

    private func deleteRides(offsets: IndexSet) {
        for index in offsets {
            let ride = rides[index]
            if let points = ride.points {
                for point in points { modelContext.delete(point) }
            }
            if let events = ride.events {
                for event in events { modelContext.delete(event) }
            }
            modelContext.delete(ride)
        }
    }
}

struct RideRow: View {
    let ride: Ride

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(ride.startDate, style: .date)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                let start = ride.startDate.formatted(date: .omitted, time: .shortened)
                let endStr = ride.endDate?.formatted(date: .omitted, time: .shortened) ?? ""
                let timeStr = ride.endDate != nil ? "\(start) → \(endStr)" : start
                Text(timeStr)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: "%.1f", ride.maxSpeed))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(speedColor)
                Text("max km/h")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.06), lineWidth: 0.5))
        )
    }

    private var speedColor: Color {
        if ride.maxSpeed < 15 { return .green }
        if ride.maxSpeed < 25 { return .yellow }
        return .red
    }
}
