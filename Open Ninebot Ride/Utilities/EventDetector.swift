import Foundation
import SwiftUI

enum EventDetector {
    static func detectEvents(points: [RidePoint]) -> [DetectedEvent] {
        var events: [DetectedEvent] = []
        guard points.count > 1 else { return events }

        for i in 1..<points.count {
            let prev = points[i-1]
            let curr = points[i]

            let accel = curr.acceleration
            let dt = curr.timestamp.timeIntervalSince(prev.timestamp)

            if dt <= 0 { continue }

            if accel > 3.0 {
                let event = DetectedEvent(
                    type: "rapid_accel",
                    severity: min((accel - 3.0) / 5.0, 1.0),
                    description: String(format: "%.1f m/s² acceleration", accel),
                    timestamp: curr.timestamp,
                    speed: curr.speed,
                    battery: curr.batteryLevel,
                    point: curr
                )
                events.append(event)
            }

            if accel < -3.0 {
                let event = DetectedEvent(
                    type: "hard_brake",
                    severity: min((abs(accel) - 3.0) / 5.0, 1.0),
                    description: String(format: "%.1f m/s² deceleration", abs(accel)),
                    timestamp: curr.timestamp,
                    speed: curr.speed,
                    battery: curr.batteryLevel,
                    point: curr
                )
                events.append(event)
            }

            if curr.mode != prev.mode {
                let event = DetectedEvent(
                    type: "mode_change",
                    severity: 0.5,
                    description: "Mode: \(prev.mode) → \(curr.mode)",
                    timestamp: curr.timestamp,
                    speed: curr.speed,
                    battery: curr.batteryLevel,
                    point: curr
                )
                events.append(event)
            }

            if curr.lightsOn != prev.lightsOn {
                let event = DetectedEvent(
                    type: "lights_toggle",
                    severity: 0.2,
                    description: curr.lightsOn ? "Lights turned on" : "Lights turned off",
                    timestamp: curr.timestamp,
                    speed: curr.speed,
                    battery: curr.batteryLevel,
                    point: curr
                )
                events.append(event)
            }
        }

        return events
    }

    static func analyzeRide(points: [RidePoint]) -> RideAnalysis {
        let speeds = points.map { $0.speed }
        let maxSpeed = speeds.max() ?? 0
        let minSpeed = speeds.min() ?? 0
        let avgSpeed = speeds.isEmpty ? 0 : speeds.reduce(0, +) / Double(speeds.count)
        let events = detectEvents(points: points)
        let hardBrakes = events.filter { $0.type == "hard_brake" }
        let rapidAccels = events.filter { $0.type == "rapid_accel" }

        return RideAnalysis(
            maxSpeed: maxSpeed,
            minSpeed: minSpeed,
            averageSpeed: avgSpeed,
            totalEvents: events.count,
            hardBrakeCount: hardBrakes.count,
            rapidAccelCount: rapidAccels.count,
            events: events
        )
    }
}

struct DetectedEvent {
    let type: String
    let severity: Double
    let description: String
    let timestamp: Date
    let speed: Double
    let battery: Double
    let point: RidePoint?

    var typeIcon: String {
        switch type {
        case "hard_brake": return "xcircle"
        case "rapid_accel": return "bolt"
        case "mode_change": return "arrow.triangle.swap"
        case "lights_toggle": return "lightbulb"
        default: return "exclamationmark"
        }
    }

    var typeColor: Color {
        switch type {
        case "hard_brake": return .red
        case "rapid_accel": return .yellow
        case "mode_change": return .blue
        case "lights_toggle": return .orange
        default: return .gray
        }
    }
}

struct RideAnalysis {
    let maxSpeed: Double
    let minSpeed: Double
    let averageSpeed: Double
    let totalEvents: Int
    let hardBrakeCount: Int
    let rapidAccelCount: Int
    let events: [DetectedEvent]
}
