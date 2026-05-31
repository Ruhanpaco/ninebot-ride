import Foundation
import SwiftData
import CoreLocation

@Model
final class RidePoint {
    var timestamp: Date
    var latitude: Double
    var longitude: Double
    var speed: Double
    var mode: String
    var lightsOn: Bool
    var batteryLevel: Double
    var voltage: Double
    var current: Double
    var odometer: Double
    var acceleration: Double
    var isBraking: Bool
    var isEvent: Bool
    var eventType: String?

    init(timestamp: Date, coordinate: CLLocationCoordinate2D, speed: Double, mode: String,
         lightsOn: Bool, batteryLevel: Double, voltage: Double, current: Double,
         odometer: Double, acceleration: Double, isBraking: Bool, isEvent: Bool = false, eventType: String? = nil) {
        self.timestamp = timestamp
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.speed = speed
        self.mode = mode
        self.lightsOn = lightsOn
        self.batteryLevel = batteryLevel
        self.voltage = voltage
        self.current = current
        self.odometer = odometer
        self.acceleration = acceleration
        self.isBraking = isBraking
        self.isEvent = isEvent
        self.eventType = eventType
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
