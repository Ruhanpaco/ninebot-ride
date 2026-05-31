import Foundation
import CoreBluetooth
import Combine

@MainActor
class BLEScanner: NSObject, ObservableObject {
    @Published var discoveredPeripherals: [CBPeripheral] = []
    @Published var isScanning = false
    @Published var connectedPeripheral: CBPeripheral?

    var onReconnect: ((CBPeripheral) -> Void)?
    var onDisconnect: ((CBPeripheral) -> Void)?
    var onFailToConnect: ((CBPeripheral, Error?) -> Void)?

    private var centralManager: CBCentralManager!
    private var connectContinuation: CheckedContinuation<Bool, Never>?
    private var continuationTargetID: UUID?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        isScanning = true
        discoveredPeripherals.removeAll()
        centralManager.scanForPeripherals(withServices: [NinebotProtocol.serviceUUID], options: nil)
    }

    func stopScanning() {
        isScanning = false
        centralManager.stopScan()
    }

    func connect(to peripheral: CBPeripheral) async -> Bool {
        stopScanning()
        connectedPeripheral = peripheral
        continuationTargetID = peripheral.identifier

        return await withCheckedContinuation { continuation in
            connectContinuation = continuation
            centralManager.connect(peripheral, options: nil)
        }
    }

    func reconnect(_ peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        continuationTargetID = peripheral.identifier
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect() {
        continuationTargetID = nil
        connectContinuation = nil
        guard let p = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(p)
        connectedPeripheral = nil
    }
}

extension BLEScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && isScanning {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? ""
        guard NinebotProtocol.matchesNinebot(name) else { return }

        if !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPeripherals.append(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Only honour the connection if it matches the peripheral we intended to connect to.
        // Prevents race where user taps a different scooter before the first finishes connecting.
        if peripheral.identifier == continuationTargetID {
            continuationTargetID = nil
            if let cc = connectContinuation {
                cc.resume(returning: true)
                connectContinuation = nil
            } else {
                onReconnect?(peripheral)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if peripheral.identifier == continuationTargetID {
            continuationTargetID = nil
            if let cc = connectContinuation {
                cc.resume(returning: false)
                connectContinuation = nil
                return
            }
        }
        onFailToConnect?(peripheral, error)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedPeripheral = nil
        onDisconnect?(peripheral)
    }
}
