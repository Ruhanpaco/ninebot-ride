import Foundation
import SwiftData

@Model
final class EventRecord {
    var timestamp: Date
    var eventType: String
    var eventDescription: String
    var speed: Double
    var batteryLevel: Double
    var latitude: Double
    var longitude: Double

    init(timestamp: Date, eventType: String, eventDescription: String, speed: Double,
         batteryLevel: Double, latitude: Double, longitude: Double) {
        self.timestamp = timestamp
        self.eventType = eventType
        self.eventDescription = eventDescription
        self.speed = speed
        self.batteryLevel = batteryLevel
        self.latitude = latitude
        self.longitude = longitude
    }
}
