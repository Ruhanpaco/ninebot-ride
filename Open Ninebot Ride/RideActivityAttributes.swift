import Foundation
import ActivityKit

struct RideActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var speed: Double
        var mode: String
        var batteryLevel: Double
        var duration: TimeInterval
        var isRecording: Bool
    }

    var scooterName: String
    var startDate: Date
}
