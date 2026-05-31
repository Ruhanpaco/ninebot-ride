import Foundation
import SwiftData
import CoreBluetooth

@Model
final class Scooter {
    var name: String
    var bluetoothIdentifier: String
    var firmwareVersion: String?
    var lastConnected: Date?
    var isPaired: Bool

    init(name: String, bluetoothIdentifier: String, firmwareVersion: String? = nil, lastConnected: Date? = nil, isPaired: Bool = true) {
        self.name = name
        self.bluetoothIdentifier = bluetoothIdentifier
        self.firmwareVersion = firmwareVersion
        self.lastConnected = lastConnected
        self.isPaired = isPaired
    }
}
