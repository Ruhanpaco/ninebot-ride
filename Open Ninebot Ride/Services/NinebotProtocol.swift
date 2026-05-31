import Foundation
import CoreBluetooth

// MARK: - Protocol generation
enum ProtocolGen { case gen2, gen3 }

// MARK: - Board IDs
enum BoardID: UInt8 {
    case dis   = 0x01  // Dashboard/Display
    case ble   = 0x04  // BLE module (handshake target)
    case vcu   = 0x09  // Vehicle Control Unit (Gen2)
    case ctrl  = 0x20  // Main controller
    case bms1  = 0x22  // Battery 1
    case bms2  = 0x23  // Battery 2
    case hep   = 0x28  // Headlight/Taillight
}

// MARK: - Service/char UUIDs
extension NinebotProtocol {
    static let nordicServiceUUID  = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    static let nordicWriteUUID   = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    static let nordicNotifyUUID  = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    static let nbServiceUUID     = CBUUID(string: "6E400001-0000-0000-006E-696E65626F74")
    static let nbWriteUUID       = CBUUID(string: "6E400002-0000-0000-006E-696E65626F74")
    static let nbNotifyUUID      = CBUUID(string: "6E400004-0000-0000-006E-696E65626F74")

    // Backward-compat aliases used by ScooterManager
    static var serviceUUID: CBUUID { nordicServiceUUID }
    static var readCharUUID: CBUUID { nordicNotifyUUID }
    static var writeCharUUID: CBUUID { nordicWriteUUID }

    // All known service UUIDs for discovery
    static var allServiceUUIDs: [CBUUID] { [nordicServiceUUID, nbServiceUUID] }

    /// Find a UART service matching any known variant.
    static func findUARTService(in services: [CBService]) -> CBService? {
        let uuids = Set([nordicServiceUUID, nbServiceUUID])
        return services.first { uuids.contains($0.uuid) }
    }

    /// Find the write characteristic from any known variant.
    static func findWriteChar(in characteristics: [CBCharacteristic]) -> CBCharacteristic? {
        let uuids = Set([nordicWriteUUID, nbWriteUUID])
        return characteristics.first { uuids.contains($0.uuid) }
    }

    /// Find the notify/read characteristic from any known variant.
    static func findNotifyChar(in characteristics: [CBCharacteristic]) -> CBCharacteristic? {
        let uuids = Set([nordicNotifyUUID, nbNotifyUUID])
        return characteristics.first { uuids.contains($0.uuid) }
    }
}

// MARK: - Frame builder/parser
struct NinebotFrame {
    let length: Int
    let boardID: UInt8
    let cmd: UInt8
    let index: UInt8
    let data: [UInt8]

    static func build(target: BoardID, cmd: UInt8, index: UInt8, data: [UInt8] = []) -> [UInt8] {
        var frame = [UInt8]()
        frame.append(0x5A); frame.append(0xA5)
        frame.append(UInt8(data.count))
        frame.append(0x3E) // phone
        frame.append(target.rawValue)
        frame.append(cmd)
        frame.append(index)
        frame += data
        return frame
    }

    static func parse(_ decrypted: [UInt8]) -> NinebotFrame? {
        guard decrypted.count >= 7,
              decrypted[0] == 0x5A,
              (decrypted[1] == 0xA5 || decrypted[1] == 0xB5),
              decrypted[3] == 0x3E else { return nil }
        let len = Int(decrypted[2])
        return NinebotFrame(
            length: len,
            boardID: decrypted[4],
            cmd: decrypted[5],
            index: decrypted[6],
            data: Array(decrypted[7..<7+len])
        )
    }

    static func readReg(target: BoardID, register: UInt8, readLen: UInt8 = 2) -> [UInt8] {
        build(target: target, cmd: 0x01, index: register, data: [readLen])
    }

    static func writeReg(target: BoardID, register: UInt8, data: [UInt8]) -> [UInt8] {
        build(target: target, cmd: 0x02, index: register, data: data)
    }

    static func writeRegNR(target: BoardID, register: UInt8, data: [UInt8]) -> [UInt8] {
        build(target: target, cmd: 0x03, index: register, data: data)
    }
}

// MARK: - Register map (DIS board)
enum DISReg: UInt8 {
    case sn              = 0x10
    case btPassword      = 0x17
    case version         = 0x1A
    case error           = 0x1B
    case alarm           = 0x1C
    case boolState       = 0x1D
    case leftMileage     = 0x25
    case speed           = 0x26
    case aveSpeed        = 0x27
    case totalMileage    = 0x29  // 4 bytes
    case totalRunTime    = 0x32  // 4 bytes
    case totalRideTime   = 0x34  // 4 bytes
    case temp            = 0x3E
    case voltage         = 0x47
    case speedLimit      = 0x72
    case normalSpeedVal  = 0x73
    case limitSpeedVal   = 0x74
    case workMode        = 0x75  // 0=Normal, 1=Eco, 2=Sport
    case kers            = 0x7B
    case cruise          = 0x7C
    case tailLight       = 0x7D
    case autoLock        = 0x85
    case funAppBool      = 0x8A
    case limitSpeed      = 0x93
    case bool2           = 0xAA
    case preciseMileage  = 0xAF
    case bool            = 0xB2
    case battery         = 0xB5
    case mileage         = 0xB7  // 4 bytes
    case singleMileage   = 0xB9
    case runningTime     = 0xBA
    case power           = 0xBD
}

// MARK: - BMS registers
enum BMSReg: UInt8 {
    case sn              = 0x10
    case swVersion       = 0x17
    case capacity        = 0x18
    case remainingCap    = 0x31
    case soc             = 0x32
    case current         = 0x33
    case voltage         = 0x34
    case temp1           = 0x35
    case temp2           = 0x36
}

// MARK: - Convenience builders
extension NinebotFrame {
    static func readSN() -> [UInt8] { readReg(target: .dis, register: DISReg.sn.rawValue, readLen: 14) }
    static func readBattery() -> [UInt8] { readReg(target: .dis, register: DISReg.battery.rawValue) }
    static func readSpeed() -> [UInt8] { readReg(target: .dis, register: DISReg.speed.rawValue) }
    static func readMileage() -> [UInt8] { readReg(target: .dis, register: DISReg.mileage.rawValue, readLen: 4) }
    static func readVoltage() -> [UInt8] { readReg(target: .dis, register: DISReg.voltage.rawValue) }
    static func readWorkMode() -> [UInt8] { readReg(target: .dis, register: DISReg.workMode.rawValue) }
    static func readTailLight() -> [UInt8] { readReg(target: .dis, register: DISReg.tailLight.rawValue) }
    static func readError() -> [UInt8] { readReg(target: .dis, register: DISReg.error.rawValue) }
    static func readLeftMileage() -> [UInt8] { readReg(target: .dis, register: DISReg.leftMileage.rawValue) }
    static func readBool() -> [UInt8] { readReg(target: .dis, register: DISReg.bool.rawValue) }
    static func readSpeedLimit() -> [UInt8] { readReg(target: .dis, register: DISReg.speedLimit.rawValue) }
    static func readRunningTime() -> [UInt8] { readReg(target: .dis, register: DISReg.runningTime.rawValue) }
    static func readSingleMileage() -> [UInt8] { readReg(target: .dis, register: DISReg.singleMileage.rawValue) }
    static func readPower() -> [UInt8] { readReg(target: .dis, register: DISReg.power.rawValue) }
    static func readCruise() -> [UInt8] { readReg(target: .dis, register: DISReg.cruise.rawValue) }
    static func readVersion() -> [UInt8] { readReg(target: .dis, register: DISReg.version.rawValue) }
    static func readBMSsoc() -> [UInt8] { readReg(target: .bms1, register: BMSReg.soc.rawValue) }
    static func readBMSvoltage() -> [UInt8] { readReg(target: .bms1, register: BMSReg.voltage.rawValue) }

    static func setSpeedLimit(_ speed: UInt16) -> [UInt8] {
        writeRegNR(target: .dis, register: DISReg.speedLimit.rawValue, data: [UInt8(speed & 0xFF), UInt8((speed >> 8) & 0xFF)])
    }
    static func setMode(_ mode: UInt16) -> [UInt8] {
        writeRegNR(target: .dis, register: DISReg.workMode.rawValue, data: [UInt8(mode & 0xFF), UInt8((mode >> 8) & 0xFF)])
    }
    static func setLights(_ on: Bool) -> [UInt8] {
        writeRegNR(target: .dis, register: DISReg.tailLight.rawValue, data: [on ? 1 : 0, 0])
    }
    static func setAutoLock(_ seconds: UInt16) -> [UInt8] {
        writeRegNR(target: .dis, register: DISReg.autoLock.rawValue, data: [UInt8(seconds & 0xFF), UInt8((seconds >> 8) & 0xFF)])
    }
}

// MARK: - Value decoding helpers
extension Array where Element == UInt8 {
    func readU16LE(at offset: Int = 0) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset + 1]) << 8)
    }
    func readU32LE(at offset: Int = 0) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) | (UInt32(self[offset + 1]) << 8) |
               (UInt32(self[offset + 2]) << 16) | (UInt32(self[offset + 3]) << 24)
    }
    func readString(at offset: Int = 0, length: Int) -> String {
        let end = Swift.min(offset + length, count)
        return String(data: Data(self[offset..<end]), encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) ?? ""
    }
}

// MARK: - Model Identification
enum NinebotScooterModel: String, CaseIterable, Codable {
    case es1 = "ES1"; case es2 = "ES2"; case es4 = "ES4"
    case g30 = "G30"; case g30lp = "G30LP"; case maxG2 = "Max G2"
    case f20 = "F20"; case f25 = "F25"; case f30 = "F30"; case f40 = "F40"; case f65 = "F65"
    case f2 = "F2"; case f2Plus = "F2 Plus"; case f2Pro = "F2 Pro"
    case gt1 = "GT1"; case gt2 = "GT2"
    case p65 = "P65"; case p100s = "P100S"
    case e22 = "E22"; case e25 = "E25"; case e45 = "E45"
    case e2 = "E2"; case e2Pro = "E2 Pro"
    case snsc = "SNSC"; case zing = "ZING"; case airT = "Air T"; case dSeries = "D Series"
    case unknown = "Unknown"

    var displayName: String { rawValue }
    var series: String {
        switch self {
        case .es1, .es2, .es4: return "ES"
        case .g30, .g30lp: return "Max"
        case .maxG2: return "Max G2"
        case .f20, .f25, .f30, .f40, .f65: return "F"
        case .f2, .f2Plus, .f2Pro: return "F2"
        case .gt1, .gt2: return "GT"
        case .p65, .p100s: return "P"
        case .e22, .e25, .e45, .e2, .e2Pro: return "E"
        case .snsc: return "SNSC"; case .zing: return "ZING"
        case .airT: return "Air"; case .dSeries: return "D"
        case .unknown: return ""
        }
    }
    var isGen3: Bool {
        switch self {
        case .f2, .f2Plus, .f2Pro, .maxG2, .p65, .p100s, .zing, .dSeries, .e2, .e2Pro: return true
        default: return false
        }
    }
}

// MARK: - Feature Detection
struct ScooterFeatures: OptionSet, Codable {
    let rawValue: Int
    static let turnSignals    = ScooterFeatures(rawValue: 1 << 0)
    static let underdeckLeds  = ScooterFeatures(rawValue: 1 << 1)
    static let cruiseControl  = ScooterFeatures(rawValue: 1 << 2)
    static let dualBattery    = ScooterFeatures(rawValue: 1 << 3)
    static let tcs            = ScooterFeatures(rawValue: 1 << 4)
    static let appleFindMy    = ScooterFeatures(rawValue: 1 << 5)
    static let electronicHorn = ScooterFeatures(rawValue: 1 << 6)
    static let suspension     = ScooterFeatures(rawValue: 1 << 7)
    static let walkMode       = ScooterFeatures(rawValue: 1 << 8)
    static let regenBrake     = ScooterFeatures(rawValue: 1 << 9)
    static let pinLock        = ScooterFeatures(rawValue: 1 << 10)
    static let tractionControl = ScooterFeatures(rawValue: 1 << 11)
    static let speedLimit     = ScooterFeatures(rawValue: 1 << 12)
    static let all: ScooterFeatures = [.turnSignals, .underdeckLeds, .cruiseControl, .dualBattery, .tcs, .appleFindMy, .electronicHorn, .suspension, .walkMode, .regenBrake, .pinLock, .tractionControl, .speedLimit]
}

enum TurnSignal: String, Codable { case off, left, right }

struct NinebotSensorData {
    var speed: Double; var batteryLevel: Double; var mode: String
    var lightsOn: Bool; var odometer: Double; var voltage: Double
    var current: Double; var isCharging: Bool; var errorCode: Int
    var lockStatus: Bool; var turnSignal: TurnSignal
}

// MARK: - BLE protocol constants/handling
class NinebotProtocol {
    static let ninebotNamePrefixes = [
        "Ninebot", "SNSC", "ES", "MAX", "NINEBOT", "GT", "SEGWAY",
        "F", "G", "E", "P", "ZING", "Air", "D", "C", "Qi"
    ]
    static func matchesNinebot(_ name: String) -> Bool {
        let up = name.uppercased()
        return ninebotNamePrefixes.contains { up.hasPrefix($0.uppercased()) }
    }

    static func detectModel(from name: String) -> NinebotScooterModel {
        let up = name.uppercased()
        if up.contains("GT2") { return .gt2 }; if up.contains("GT1") { return .gt1 }
        if up.contains("P100") { return .p100s }; if up.contains("P65") { return .p65 }
        if up.contains("MAX G2") || up.contains(" G2") { return .maxG2 }
        if up.contains("G30LP") || up.contains("G30 LP") { return .g30lp }
        if up.contains("G30") { return .g30 }
        if up.contains("F65") { return .f65 }
        if up.contains("F2 PRO") || up.contains("F2PRO") { return .f2Pro }
        if up.contains("F2 PLUS") || up.contains("F2+") { return .f2Plus }
        if up.contains("F2") { return .f2 }
        if up.contains("F40") { return .f40 }; if up.contains("F30") { return .f30 }
        if up.contains("F25") { return .f25 }; if up.contains("F20") { return .f20 }
        if up.contains("E2 PRO") || up.contains("E2PRO") { return .e2Pro }
        if up.contains("E2") { return .e2 }
        if up.contains("E45") { return .e45 }; if up.contains("E25") { return .e25 }; if up.contains("E22") { return .e22 }
        if up.contains("ES4") { return .es4 }; if up.contains("ES2") { return .es2 }; if up.contains("ES1") { return .es1 }
        if up.contains("ES") { return .es2 }; if up.contains("MAX") { return .g30 }
        if up.contains("ZING") { return .zing }; if up.contains("AIR") { return .airT }
        if up.contains("SNSC") { return .snsc }; if up.contains("D") { return .dSeries }
        return .unknown
    }

    static func features(for model: NinebotScooterModel) -> ScooterFeatures {
        switch model {
        case .gt1, .gt2: return [.turnSignals, .cruiseControl, .walkMode, .regenBrake, .electronicHorn, .suspension, .speedLimit, .pinLock, .tractionControl, .appleFindMy]
        case .p65, .p100s: return [.turnSignals, .cruiseControl, .walkMode, .regenBrake, .electronicHorn, .suspension, .speedLimit, .pinLock]
        case .maxG2: return [.turnSignals, .cruiseControl, .walkMode, .regenBrake, .electronicHorn, .suspension, .tcs, .appleFindMy, .pinLock, .tractionControl]
        case .f2Pro: return [.turnSignals, .cruiseControl, .walkMode, .regenBrake, .electronicHorn, .tcs]
        case .f2Plus, .f2, .f65: return [.turnSignals, .cruiseControl, .walkMode, .regenBrake]
        case .f20, .f25, .f30, .f40, .g30, .g30lp: return [.cruiseControl, .walkMode, .regenBrake]
        case .es4: return [.underdeckLeds, .cruiseControl, .walkMode, .regenBrake, .dualBattery]
        case .es2, .e22: return [.cruiseControl, .walkMode, .regenBrake]
        case .es1: return [.cruiseControl, .walkMode]
        case .e25, .e45, .e2, .e2Pro: return [.underdeckLeds, .cruiseControl, .walkMode, .regenBrake]
        case .snsc: return [.cruiseControl, .walkMode, .regenBrake, .speedLimit]
        case .zing: return [.walkMode, .speedLimit]
        case .airT: return [.cruiseControl, .walkMode, .regenBrake]
        case .dSeries: return [.turnSignals, .cruiseControl, .walkMode, .regenBrake, .electronicHorn]
        case .unknown: return [.cruiseControl, .walkMode, .regenBrake]
        }
    }

    // Real-time notification parsing (protocol-agnostic payload)
    static func parseRealtimeData(_ data: Data) -> NinebotSensorData? {
        guard data.count >= 20 else { return nil }
        let bytes = [UInt8](data)
        let speed = Double(bytes.readU16LE(at: 4)) / 100.0
        let batteryLevel = Double(bytes[6])
        var mode = "Drive"
        switch bytes[7] { case 1: mode = "Eco"; case 2: mode = "Drive"; case 3: mode = "Sport"; default: break }
        let lightsOn = bytes[8] > 0
        let odometer = Double(bytes.readU32LE(at: 12)) / 1000.0
        let voltage = Double(bytes.readU16LE(at: 16)) / 100.0
        let currentRaw = Int16(truncatingIfNeeded: bytes.readU16LE(at: 18))
        let current = Double(currentRaw) / 100.0
        var turnSignal: TurnSignal = .off
        if bytes.count > 20 {
            let ts = bytes[20]
            if ts == 1 { turnSignal = .left } else if ts == 2 { turnSignal = .right }
        }
        return NinebotSensorData(speed: speed, batteryLevel: batteryLevel, mode: mode, lightsOn: lightsOn, odometer: odometer, voltage: voltage, current: abs(current), isCharging: current < 0, errorCode: Int(bytes[10]), lockStatus: bytes[9] > 0, turnSignal: turnSignal)
    }

    /// Register read poll command (encrypted)
    static func buildReadCommand(target: BoardID, register: UInt8, length: UInt8 = 2, via crypto: NbCrypto) -> [UInt8] {
        crypto.encrypt(NinebotFrame.readReg(target: target, register: register, readLen: length))
    }

    /// Decrypt and parse register read response
    static func parseReadResponse(_ encrypted: [UInt8], via crypto: NbCrypto) -> (register: UInt8, value: [UInt8])? {
        let (pt, rc) = crypto.decrypt(encrypted)
        guard rc == 0, let frame = NinebotFrame.parse(pt), frame.cmd == 0x04 else { return nil }
        return (frame.index, frame.data)
    }
}
