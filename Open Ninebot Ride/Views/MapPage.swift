import SwiftUI
import CoreLocation
import Combine

struct MapPage: View {
    @ObservedObject var scooterManager: ScooterManager
    @State private var routePoints: [RidePoint] = []
    @State private var userLocation: CLLocationCoordinate2D?
    @State private var locationDelegate: LocationDelegate?
    @State private var rideStartTime: Date = Date()

    private var isConnected: Bool { scooterManager.isConnected }

    var body: some View {
        ZStack {
            MapWithRouteView(
                routePoints: routePoints,
                currentSpeed: scooterManager.speed,
                currentMode: scooterManager.mode,
                lightsOn: scooterManager.lightsOn,
                userLocation: userLocation
            )
            .ignoresSafeArea()

            VStack {
                if isConnected {
                    dynamicIsland
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()

                VStack(spacing: 12) {
                    if scooterManager.isRecording {
                        recBadge
                    }
                    recordButton
                }
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 16)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isConnected)
        .onAppear {
            let delegate = LocationDelegate { location in
                userLocation = location
            }
            locationDelegate = delegate
            scooterManager.locationManager.delegate = delegate
            scooterManager.locationManager.startUpdatingLocation()
        }
        .onChange(of: scooterManager.speed) { _, _ in
            if scooterManager.isRecording {
                let point = RidePoint(
                    timestamp: Date(),
                    coordinate: userLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0),
                    speed: scooterManager.speed,
                    mode: scooterManager.mode,
                    lightsOn: scooterManager.lightsOn,
                    batteryLevel: scooterManager.batteryLevel,
                    voltage: scooterManager.voltage,
                    current: scooterManager.current,
                    odometer: scooterManager.odometer,
                    acceleration: scooterManager.acceleration,
                    isBraking: scooterManager.isBraking
                )
                routePoints.append(point)
            }
        }
    }

    private var dynamicIsland: some View {
        HStack(spacing: 0) {
            HStack(spacing: 3) {
                Text("\(Int(scooterManager.speed))")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(speedColor)
                    .contentTransition(.numericText())
                    .animation(.snappy(duration: 0.2), value: scooterManager.speed)
                Text("km/h")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(width: 0, height: 20)
                .overlay(.white.opacity(0.08))

            // Turn signal
            HStack(spacing: 2) {
                Image(systemName: "arrow.left.to.line")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(scooterManager.turnSignal == .left ? .green : .white.opacity(0.08))
                Image(systemName: "arrow.right.to.line")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(scooterManager.turnSignal == .right ? .green : .white.opacity(0.08))
            }
            .frame(width: 36)

            Divider()
                .frame(width: 0, height: 20)
                .overlay(.white.opacity(0.08))

            HStack(spacing: 4) {
                Image(systemName: modeIcon)
                    .font(.system(size: 11))
                    .fontWeight(.semibold)
                Text(scooterManager.mode)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(modeColor)
            .frame(maxWidth: .infinity)

            Divider()
                .frame(width: 0, height: 20)
                .overlay(.white.opacity(0.08))

            HStack(spacing: 4) {
                Image(systemName: "battery.\(batteryIcon)")
                    .font(.system(size: 11))
                    .foregroundStyle(batteryColor)
                Text("\(Int(scooterManager.batteryLevel))%")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(batteryColor)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            ZStack {
                Capsule()
                    .fill(.black.opacity(0.75))
                Capsule()
                    .stroke(.white.opacity(0.08), lineWidth: 0.5)
            }
        )
        .padding(.top, 12)
        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
    }

    private var recBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(.red)
                .frame(width: 5, height: 5)
            Text("REC")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.red)
                .tracking(1.5)
            Text(durationString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(.black.opacity(0.5))
        )
    }

    private var recordButton: some View {
        Button {
            if scooterManager.isRecording {
                scooterManager.stopRecording()
            } else {
                rideStartTime = Date()
                routePoints.removeAll()
                scooterManager.startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(scooterManager.isRecording ? Color.red : .white)
                    .frame(width: 52, height: 52)
                if scooterManager.isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white)
                        .frame(width: 14, height: 14)
                } else {
                    Circle()
                        .fill(.black)
                        .frame(width: 18, height: 18)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 8)
        }
        .buttonStyle(PressScaleStyle())
    }

    private var durationString: String {
        let dur = Date().timeIntervalSince(rideStartTime)
        let m = Int(dur) / 60
        let s = Int(dur) % 60
        return String(format: "%d:%02d", m, s)
    }

    private var speedColor: Color {
        if scooterManager.speed < 10 { return Color(red: 0.2, green: 0.8, blue: 0.3) }
        if scooterManager.speed < 20 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
        return Color(red: 1.0, green: 0.2, blue: 0.2)
    }

    private var modeIcon: String {
        switch scooterManager.mode {
        case "Sport": return "bolt.fill"
        case "Eco": return "leaf.fill"
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

    private var batteryIcon: String {
        if scooterManager.batteryLevel > 75 { return "100" }
        if scooterManager.batteryLevel > 50 { return "75" }
        if scooterManager.batteryLevel > 25 { return "50" }
        return "25"
    }

    private var batteryColor: Color {
        if scooterManager.batteryLevel > 50 { return Color(red: 0.2, green: 0.8, blue: 0.3) }
        if scooterManager.batteryLevel > 20 { return Color(red: 1.0, green: 0.8, blue: 0.0) }
        return Color(red: 1.0, green: 0.2, blue: 0.2)
    }
}

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    let onUpdate: (CLLocationCoordinate2D) -> Void
    init(onUpdate: @escaping (CLLocationCoordinate2D) -> Void) {
        self.onUpdate = onUpdate
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        onUpdate(loc.coordinate)
    }
}
