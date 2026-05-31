import Foundation
import CoreBluetooth
import Combine
import CoreLocation
import SwiftData
import UIKit

@MainActor
class ScooterManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var speed: Double = 0
    @Published var batteryLevel: Double = 85
    @Published var mode: String = "Drive"
    @Published var lightsOn = false
    @Published var turnSignal: TurnSignal = .off
    @Published var odometer: Double = 0
    @Published var voltage: Double = 41.5
    @Published var current: Double = 0
    @Published var acceleration: Double = 0
    @Published var isBraking = false
    @Published var isRecording = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastPoint: RidePoint?

    @Published var scooterModel: NinebotScooterModel = .unknown
    @Published var scooterFeatures: ScooterFeatures = [.cruiseControl, .walkMode, .regenBrake]
    @Published var authState: AuthState = .idle

    enum ConnectionState { case disconnected, scanning, connecting, connected }
    enum AuthState: Equatable {
        case idle, preComm, setPwd, auth, complete, failed(String)
        var isHandshaking: Bool {
            self == .preComm || self == .setPwd || self == .auth
        }
        var isFailed: Bool { if case .failed = self { return true }; return false }
    }

    let scanner = BLEScanner()
    let locationManager = CLLocationManager()

    private var previousSpeed: Double = 0
    private var previousTimestamp: Date = Date()
    private var activeRide: Ride?
    private var modelContext: ModelContext?
    private var rideTimer: Timer?
    private var pollTimer: Timer?
    private var peripheral: CBPeripheral?
    private var peripheralID: UUID? { peripheral?.identifier }
    private var peripheralName: String? { peripheral?.name }
    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    private let liveActivityManager = LiveActivityManager()

    // Auth
    private var handshake: NinebotHandshake?
    private var authCrypto: NbCrypto?
    private var authBuffer = Data()
    private var authStepTimer: Timer?
    private var authRetryCount = 0
    private var notificationsReady = false
    private let maxAuthRetries = 3
    private let authStepTimeout: TimeInterval = 2.0

    // Reconnection
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10

    override init() {
        super.init()
        locationManager.requestWhenInUseAuthorization()
        scanner.onReconnect = { [weak self] peripheral in
            Task { @MainActor in self?.onReconnected(peripheral) }
        }
        scanner.onDisconnect = { [weak self] peripheral in
            Task { @MainActor in self?.handleDisconnect(peripheral) }
        }
        scanner.onFailToConnect = { [weak self] peripheral, error in
            Task { @MainActor in self?.handleReconnectFailed(peripheral, error) }
        }
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
    }

    // MARK: - Scan / Connect

    func scan() {
        connectionState = .scanning
        scanner.startScanning()
    }

    func stopScan() {
        scanner.stopScanning()
        if connectionState == .scanning { connectionState = .disconnected }
    }

    func connect(to newPeripheral: CBPeripheral) async -> Bool {
        connectionState = .connecting
        peripheral = newPeripheral
        peripheral?.delegate = self
        let success = await scanner.connect(to: newPeripheral)
        if success {
            isConnected = true
            connectionState = .connected
            detectModel(from: newPeripheral.name ?? "")
            discoverServices(for: newPeripheral)
        } else {
            connectionState = .disconnected
        }
        return success
    }

    private func detectModel(from name: String) {
        scooterModel = NinebotProtocol.detectModel(from: name)
        scooterFeatures = NinebotProtocol.features(for: scooterModel)
    }

    func disconnect() {
        stopAllTimers()
        authStepTimer?.invalidate(); authStepTimer = nil
        reconnectTimer?.invalidate(); reconnectTimer = nil
        scanner.disconnect()
        isConnected = false
        connectionState = .disconnected
        isRecording = false
        peripheral = nil
        handshake = nil
        authCrypto = nil
        authBuffer.removeAll()
        authRetryCount = 0
        reconnectAttempts = 0
        authState = .idle
    }

    private func stopAllTimers() {
        rideTimer?.invalidate(); rideTimer = nil
        pollTimer?.invalidate(); pollTimer = nil
    }

    private func discoverServices(for peripheral: CBPeripheral) {
        peripheral.discoverServices(NinebotProtocol.allServiceUUIDs)
    }

    // MARK: - Auth Handshake (with retry)

    private func startAuthHandshake() {
        authRetryCount = 0
        authBuffer.removeAll()
        guard let p = peripheral, let name = p.name, !name.isEmpty else {
            authState = .failed("No scooter name")
            return
        }
        let mac = p.identifier.uuidString
        let gen: ProtocolGen = scooterModel.isGen3 ? .gen3 : .gen2
        handshake = NinebotHandshake(gen: gen, btName: name, mac: mac)
        if let saved = retrievePassword(mac: mac) {
            handshake?.password = saved
        }
        sendPRE_COMM()
    }

    private func sendPRE_COMM() {
        guard let handshake = handshake else { return }
        authState = .preComm
        authBuffer.removeAll()
        startAuthTimeout()
        let frame = handshake.buildPRE_COMM()
        writeRaw(frame)
    }

    private func sendSET_PWD() {
        guard let handshake = handshake else { return }
        authState = .setPwd
        authBuffer.removeAll()
        startAuthTimeout()
        let frame = handshake.buildSET_PWD()
        writeRaw(frame)
    }

    private func sendAUTH() {
        guard let handshake = handshake else { return }
        authState = .auth
        authBuffer.removeAll()
        startAuthTimeout()
        let frame = handshake.buildAUTH()
        writeRaw(frame)
    }

    private func authComplete() {
        authStepTimer?.invalidate(); authStepTimer = nil
        guard let handshake = handshake else {
            authState = .failed("No handshake")
            return
        }
        let mac = peripheral?.identifier.uuidString ?? ""
        if !handshake.password.isEmpty {
            storePassword(mac: mac, password: handshake.password)
        }
        authCrypto = handshake.cryptoRef
        authRetryCount = 0
        authState = .complete
        startPolling()
    }

    private func authFailed(_ reason: String) {
        authStepTimer?.invalidate(); authStepTimer = nil
        authRetryCount += 1
        guard authRetryCount < maxAuthRetries else {
            authState = .failed("Auth failed after \(maxAuthRetries) retries: \(reason)")
            return
        }
        authState = .failed("Retrying (\(authRetryCount)/\(maxAuthRetries)): \(reason)")
        // Small delay then retry from scratch
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            startAuthHandshake()
        }
    }

    private func startAuthTimeout() {
        authStepTimer?.invalidate()
        authStepTimer = Timer.scheduledTimer(withTimeInterval: authStepTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.authFailed("Timeout waiting for response")
            }
        }
    }

    private func handleAuthResponse(_ data: Data) {
        authStepTimer?.invalidate()
        authStepTimer = nil
        authBuffer.append(data)

        guard authBuffer.count >= 10 else {
            startAuthTimeout()
            return
        }

        let bytes = [UInt8](authBuffer)
        guard bytes.count >= 3, bytes[0] == 0x5A, bytes[1] == 0xA5 else {
            authBuffer.removeAll()
            authFailed("Bad sync")
            return
        }

        let payloadLen = Int(bytes[2])
        let totalLen = 3 + payloadLen + 6
        guard bytes.count >= totalLen else {
            startAuthTimeout()
            return
        }

        let frame = Array(bytes[..<totalLen])
        authBuffer = Data(bytes[totalLen...])

        guard let handshake = handshake else { return }
        let mac = peripheral?.identifier.uuidString ?? ""

        switch authState {
        case .preComm:
            do {
                _ = try handshake.processPRE_COMM(response: frame)
                sendSET_PWD()
            } catch {
                authFailed("PRE_COMM: \(error.localizedDescription)")
            }
        case .setPwd:
            do {
                let rc = try handshake.processResponse(frame)
                guard rc == 0 else {
                    authFailed("SET_PWD rejected: rc=\(rc)")
                    return
                }
                sendAUTH()
            } catch {
                authFailed("SET_PWD: \(error.localizedDescription)")
            }
        case .auth:
            do {
                let rc = try handshake.processResponse(frame)
                guard rc == 0 else {
                    authFailed("AUTH rejected: rc=\(rc)")
                    return
                }
                authComplete()
            } catch {
                authFailed("AUTH: \(error.localizedDescription)")
            }
        default:
            break
        }
    }

    // MARK: - BLE Reconnection

    private func handleDisconnect(_ disconnectedPeripheral: CBPeripheral) {
        guard self.peripheral?.identifier == disconnectedPeripheral.identifier else { return }
        isConnected = false
        connectionState = .connecting
        authState = .idle
        stopAllTimers()
        authStepTimer?.invalidate(); authStepTimer = nil
        pollTimer?.invalidate(); pollTimer = nil
        authCrypto = nil
        handshake = nil
        authBuffer.removeAll()
        authRetryCount = 0
        reconnectAttempts = 0
        startReconnection()
    }

    private func startReconnection() {
        guard let p = peripheral else {
            reconnectAttempts += 1
            guard reconnectAttempts < maxReconnectAttempts else {
                connectionState = .disconnected
                return
            }
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.startReconnection() }
            }
            return
        }
        p.delegate = self
        scanner.reconnect(p)
    }

    // Called when centralManager reconnects (didConnect fires on BLEScanner)
    func onReconnected(_ peripheral: CBPeripheral) {
        reconnectTimer?.invalidate(); reconnectTimer = nil
        reconnectAttempts = 0
        isConnected = true
        connectionState = .connected
        peripheral.delegate = self
        discoverServices(for: peripheral)
    }

    private func handleReconnectFailed(_ peripheral: CBPeripheral, _ error: Error?) {
        reconnectAttempts += 1
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .disconnected
            return
        }
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.startReconnection() }
        }
    }

    private func writeRaw(_ bytes: [UInt8]) {
        guard let characteristic = writeCharacteristic, let p = peripheral else { return }
        let mtu = p.maximumWriteValueLength(for: .withoutResponse)
        let limit = mtu > 0 ? mtu : 20
        let data = Data(bytes)
        var offset = 0
        while offset < data.count {
            let chunk = data.dropFirst(offset).prefix(limit)
            p.writeValue(Data(chunk), for: characteristic, type: .withoutResponse)
            offset += chunk.count
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollTick() }
        }
    }

    private func pollTick() {
        guard let crypto = authCrypto else { return }
        let cmds: [[UInt8]] = [
            NinebotProtocol.buildReadCommand(target: .dis, register: DISReg.speed.rawValue, via: crypto),
            NinebotProtocol.buildReadCommand(target: .dis, register: DISReg.battery.rawValue, via: crypto),
            NinebotProtocol.buildReadCommand(target: .dis, register: DISReg.workMode.rawValue, via: crypto),
            NinebotProtocol.buildReadCommand(target: .dis, register: DISReg.tailLight.rawValue, via: crypto),
            NinebotProtocol.buildReadCommand(target: .dis, register: DISReg.voltage.rawValue, via: crypto),
        ]
        for cmd in cmds { writeRaw(cmd) }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        previousSpeed = speed
        previousTimestamp = Date()

        let ride = Ride(scooterName: peripheralName)
        modelContext?.insert(ride)
        activeRide = ride

        rideTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickRide() }
        }

        liveActivityManager.start(
            scooterName: peripheralName ?? "Ninebot",
            speed: speed, mode: mode, batteryLevel: batteryLevel
        )
    }

    func stopRecording() {
        guard isRecording, let ride = activeRide else { return }
        isRecording = false
        rideTimer?.invalidate(); rideTimer = nil
        ride.endDate = Date()
        ride.isActive = false
        try? modelContext?.save()
        activeRide = nil
        liveActivityManager.end()
    }

    private func tickRide() {
        guard let ride = activeRide else { return }
        updateRideStats(for: ride)
    }

    private func recordPoint() {
        guard let ride = activeRide else { return }
        let now = Date()
        let coord = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let accel = calculateAcceleration()

        let point = RidePoint(
            timestamp: now, coordinate: coord,
            speed: speed, mode: mode, lightsOn: lightsOn,
            batteryLevel: batteryLevel, voltage: voltage, current: current,
            odometer: odometer, acceleration: accel, isBraking: isBraking, isEvent: false
        )

        if ride.points == nil { ride.points = [] }
        ride.points?.append(point)
        lastPoint = point

        if accel > 3.0 {
            recordEvent(ride: ride, type: "rapid_accel",
                       description: String(format: "Rapid acceleration: %.1f m/s²", accel))
        } else if accel < -3.0 {
            recordEvent(ride: ride, type: "hard_brake",
                       description: String(format: "Hard braking: %.1f m/s² deceleration", abs(accel)))
        }
    }

    private func recordEvent(ride: Ride, type: String, description: String) {
        let coord = locationManager.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let event = EventRecord(
            timestamp: Date(), eventType: type, eventDescription: description,
            speed: speed, batteryLevel: batteryLevel,
            latitude: coord.latitude, longitude: coord.longitude
        )
        if ride.events == nil { ride.events = [] }
        ride.events?.append(event)
        ride.eventCount = (ride.events?.count ?? 0)
    }

    private func calculateAcceleration() -> Double {
        let now = Date()
        let dt = now.timeIntervalSince(previousTimestamp)
        guard dt > 0 else { return 0 }
        let accel = (speed - previousSpeed) / dt
        previousSpeed = speed
        previousTimestamp = now
        return accel
    }

    private func updateRideStats(for ride: Ride) {
        guard let points = ride.points, !points.isEmpty else { return }
        let speeds = points.map { $0.speed }
        ride.maxSpeed = speeds.max() ?? 0
        ride.minSpeed = speeds.min() ?? 0
        ride.averageSpeed = speeds.reduce(0, +) / Double(speeds.count)

        if points.count > 1 {
            var totalDist: Double = 0
            for i in 1..<points.count {
                let p = points[i-1], c = points[i]
                let pl = CLLocation(latitude: p.latitude, longitude: p.longitude)
                let cl = CLLocation(latitude: c.latitude, longitude: c.longitude)
                totalDist += cl.distance(from: pl)
            }
            ride.distance = totalDist
        }
        let accels = points.map { abs($0.acceleration) }
        ride.maxAcceleration = accels.max() ?? 0
        ride.maxDeceleration = points.map { abs($0.acceleration) }.max() ?? 0
    }

    // MARK: - Commands

    func sendCommand(_ frame: [UInt8]) {
        guard let crypto = authCrypto else { return }
        let encrypted = crypto.encrypt(frame)
        writeRaw(encrypted)
    }

    func setWorkMode(_ modeValue: UInt16) {
        sendCommand(NinebotFrame.setMode(modeValue))
    }

    func setLights(_ on: Bool) {
        sendCommand(NinebotFrame.setLights(on))
    }

    func setSpeedLimit(_ limit: UInt16) {
        sendCommand(NinebotFrame.setSpeedLimit(limit))
    }

    func readRegister(_ board: BoardID, _ register: UInt8) {
        guard let crypto = authCrypto else { return }
        let cmd = NinebotProtocol.buildReadCommand(target: board, register: register, via: crypto)
        writeRaw(cmd)
    }
}

// MARK: - CBPeripheralDelegate

extension ScooterManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services,
              let service = NinebotProtocol.findUARTService(in: services) else {
            return
        }
        let charUUIDs = [NinebotProtocol.nordicWriteUUID, NinebotProtocol.nordicNotifyUUID,
                         NinebotProtocol.nbWriteUUID, NinebotProtocol.nbNotifyUUID]
        peripheral.discoverCharacteristics(charUUIDs, for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        readCharacteristic = NinebotProtocol.findNotifyChar(in: chars)
        writeCharacteristic = NinebotProtocol.findWriteChar(in: chars)
        notificationsReady = false
        if let readChar = readCharacteristic {
            peripheral.setNotifyValue(true, for: readChar)
            // Fallback: start auth after 300ms even if notification state not confirmed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self, !self.notificationsReady else { return }
                self.notificationsReady = true
                self.startAuthHandshake()
            }
        } else {
            // No notify characteristic found — try auth anyway
            notificationsReady = true
            startAuthHandshake()
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic == readCharacteristic, !notificationsReady else { return }
        notificationsReady = true
        startAuthHandshake()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, !data.isEmpty else { return }

        let bytes = [UInt8](data)

        // Route through auth handler while handshake is in progress
        if authState.isHandshaking {
            handleAuthResponse(data)
            return
        }

        // After auth: decrypt encrypted frames, then parse
        if bytes.count >= 2 && bytes[1] == 0xA5 {
            guard let crypto = authCrypto else { return }
            let (pt, rc) = crypto.decrypt(bytes)
            guard rc == 0 else { return }
            handleDecryptedFrame(Data(pt))
        } else if bytes.count >= 1 && bytes[0] == 0x5A {
            handleDecryptedFrame(data)
        }
    }

    private func handleDecryptedFrame(_ data: Data) {
        let bytes = [UInt8](data)

        // Try as a register response frame
        if let frame = NinebotFrame.parse(bytes), frame.cmd == 0x04 {
            applyRegisterValue(register: frame.index, value: frame.data)
            return
        }

        // Fallback: treat as raw sensor data (skip 3-byte frame header)
        let payload = bytes.count >= 7 ? Data(bytes.dropFirst(3)) : data
        guard let sensorData = NinebotProtocol.parseRealtimeData(payload) else { return }
        speed = sensorData.speed
        batteryLevel = sensorData.batteryLevel
        mode = sensorData.mode
        lightsOn = sensorData.lightsOn
        turnSignal = sensorData.turnSignal
        odometer = sensorData.odometer
        voltage = sensorData.voltage
        current = sensorData.current
        acceleration = calculateAcceleration()
        isBraking = acceleration < -0.5
        if isRecording { recordPoint() }
    }

    private func applyRegisterValue(register: UInt8, value: [UInt8]) {
        guard value.count >= 1 else { return }
        switch register {
        case DISReg.speed.rawValue:
            if value.count >= 2 { speed = Double(value.readU16LE()) / 100.0 }
        case DISReg.battery.rawValue:
            batteryLevel = Double(value[0])
        case DISReg.workMode.rawValue:
            switch value[0] { case 0: mode = "Eco"; case 1: mode = "Drive"; case 2: mode = "Sport"; default: break }
        case DISReg.tailLight.rawValue:
            lightsOn = value[0] > 0
        case DISReg.voltage.rawValue:
            if value.count >= 2 { voltage = Double(value.readU16LE()) / 100.0 }
        default:
            break
        }
    }
}
