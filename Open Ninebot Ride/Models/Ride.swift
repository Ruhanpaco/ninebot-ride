import Foundation
import SwiftData

@Model
final class Ride {
    var startDate: Date
    var endDate: Date?
    var maxSpeed: Double
    var minSpeed: Double
    var averageSpeed: Double
    var distance: Double
    var maxAcceleration: Double
    var maxDeceleration: Double
    var eventCount: Int
    var scooterName: String?
    var isActive: Bool
    @Relationship(deleteRule: .cascade) var points: [RidePoint]?
    @Relationship(deleteRule: .cascade) var events: [EventRecord]?

    init(startDate: Date = Date(), scooterName: String? = nil) {
        self.startDate = startDate
        self.endDate = nil
        self.maxSpeed = 0
        self.minSpeed = Double.greatestFiniteMagnitude
        self.averageSpeed = 0
        self.distance = 0
        self.maxAcceleration = 0
        self.maxDeceleration = 0
        self.eventCount = 0
        self.scooterName = scooterName
        self.isActive = true
        self.points = []
        self.events = []
    }
}
