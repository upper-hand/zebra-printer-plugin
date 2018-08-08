//
//  ZebraPrinterBluetooth.swift
//  Upper Hand
//
//  Created by Tim Baker on 8/7/18.
//

import Foundation
import CoreBluetooth

typealias BluetoothSuccess = ()->()
typealias BluetoothFailure = (ZebraPrinterBluetooth.ZebraError)->()


protocol CbuuidConvertible: RawRepresentable {}
extension CbuuidConvertible {
    var cbuuuid: CBUUID {
        return CBUUID(string: rawValue as? String ?? "")
    }
}

extension Notification.Name {
    static var writeResponse = NSNotification.Name(rawValue: "zebra.printer.bluetooth.write")
}

// Adapted from https://github.com/Zebra/LinkOS-iOS-Samples/tree/ZebraPrinterBLEDemo
class ZebraPrinterBluetooth: NSObject {

    enum ZebraError: Error, LocalizedError {
        case printerNotFound
        case disconnected
        case connectionIncomplete
        case failedToReadZPL
        case internalError
        case other(Error)

        var errorDescription: String? {
            switch self {
            case .printerNotFound:      return "Printer not found"
            case .disconnected:         return "Printer not connected"
            case .connectionIncomplete:  return "Connection Incomplete. Please try again."
            case .failedToReadZPL:      return "Could not read ZPL command"
            case .internalError:        return "Internal error"
            case .other(let error):     return description(for: error)
            }
        }

        private func description(for error: Error) -> String {
            let message = error.localizedDescription != "" ? error.localizedDescription : "unknown error"
            let code = (error as NSError).code
            return "Zebra SDK Error (\(code)): \(message)"
        }
    }

    enum Service: String, CbuuidConvertible {
        case action = "38EB4A80-C570-11E3-9507-0002A5D5C51B"
        case info = "180A"
    }

    enum Characteristic: String, CbuuidConvertible {
        case write = "38EB4A82-C570-11E3-9507-0002A5D5C51B"
        case read = "38EB4A81-C570-11E3-9507-0002A5D5C51B"
        case modelName = "2A24"
        case serialNumber = "2A25"
        case firmware = "2A26"
        case hardware = "2A27"
        case software = "2A28"
        case manufacturer = "2A29"
    }

    enum WriteResponse {
        case success(Data?)
        case failure(ZebraError)
    }

    fileprivate var centralManager: CBCentralManager!
    fileprivate var availablePrinters: [String: CBPeripheral] = [:]
    fileprivate var printer: CBPeripheral?
    fileprivate var writeCharacteristic: CBCharacteristic?
    fileprivate var readCharacteristic: CBCharacteristic?
    fileprivate var deviceData: Data?
    fileprivate var finishConnecting: ((ZebraPrinterBluetooth.ZebraError?)->())?
    fileprivate var finishSending: ((WriteResponse)->())?

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
}


// - MARK: Printer interface

extension ZebraPrinterBluetooth {

    func discover(scanDuration: Double, success: @escaping ([String])->()) {
        availablePrinters = [:]
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey : true
        ])
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + scanDuration) {
            self.centralManager.stopScan()
            let printerNames = Array(self.availablePrinters.keys)
            success(printerNames)
        }
    }

    func isConnected() -> Bool {
        return (printer != nil && writeCharacteristic != nil)
    }

    func connect(device: String, success: @escaping BluetoothSuccess, failure: @escaping BluetoothFailure) {
        PrinterQueue.shared.async {
            self.printer = nil
            self.centralManager.stopScan()
            guard let peripheral = self.availablePrinters[device] else { return failure(.printerNotFound) }

            self.finishConnecting = { error in
                guard error == nil else {
                    self.centralManager.cancelPeripheralConnection(peripheral)
                    self.printer = nil
                    return failure(error!)
                }
                success()
            }
            self.printer = peripheral
            peripheral.delegate = self
            self.centralManager.connect(self.printer!, options: nil)
        }
    }

    func disconnect() {
        centralManager.stopScan()
        if let printer = self.printer {
            centralManager.cancelPeripheralConnection(printer)
        }
        guard isConnected() else { return }
        printer = nil
        writeCharacteristic = nil
    }

    func send(_ zpl: String, success: @escaping (String)->(), failure: @escaping BluetoothFailure) {
        PrinterQueue.shared.async {
            guard let printer = self.printer else { return failure(.printerNotFound) }
            guard self.isConnected() else { return failure(.disconnected) }
            guard let payload = zpl.data(using: .utf8) else { return failure(.failedToReadZPL) }
            guard let writeCharacteristic = self.writeCharacteristic else { return failure(.internalError) }

            self.finishSending = { response in
                switch response {
                case .success(let data):
                    guard let data = data else { return success("") }
                    let result = String(data: data, encoding: .utf8)
                    success(result ?? "")
                case .failure(let error):
                    failure(error)
                }
            }

            printer.writeValue(payload, for: writeCharacteristic, type: CBCharacteristicWriteType.withResponse)
        }
    }
}

fileprivate extension ZebraPrinterBluetooth {
    func completeConnection(_ error: ZebraError?) {
        finishConnecting?(error)
        finishConnecting = nil
    }

    func cleanup() {
        guard printer?.state == .connected else { return }
        guard let services = printer?.services else { return }

        for service in services {
            guard let characteristics = service.characteristics else { continue }
            for characteristic in characteristics {
                guard characteristic.uuid == Characteristic.read.cbuuuid else { continue }
                guard characteristic.isNotifying else { continue }
                printer?.setNotifyValue(false, for: characteristic)
            }
        }
    }
}

// - MARK: Printer interface

extension ZebraPrinterBluetooth : CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let rssi = RSSI.intValue
        guard -70 < rssi || rssi < -15 else { return }
        guard let rawName = peripheral.name else { return }
        let name = rawName.trimmingCharacters(in: CharacterSet.whitespaces)
        guard !availablePrinters.contains(where: { $0.key == name }) else { return }
        availablePrinters[name] = peripheral
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.printer = nil
        cleanup()
        completeConnection(error != nil ? ZebraError.other(error!) : ZebraError.internalError)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        centralManager.stopScan()
        let services = [
            Service.action.cbuuuid,
            Service.info.cbuuuid
        ]
        peripheral.discoverServices(services)
    }
}

extension ZebraPrinterBluetooth : CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            completeConnection(.other(error!))
            return cleanup()
        }

        for btService in peripheral.services ?? [] {
            guard let service = Service(rawValue: btService.uuid.uuidString) else { continue }
            switch service {
            case .action:
                let all: [Characteristic] = [.write, .read]
                let cbuuids = all.map { $0.cbuuuid }
                peripheral.discoverCharacteristics(cbuuids, for: btService)
            case .info:
                let all: [Characteristic] = [.modelName, .serialNumber, .firmware, .hardware, .software, .manufacturer]
                let cbuuids = all.map { $0.cbuuuid }
                peripheral.discoverCharacteristics(cbuuids, for: btService)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            completeConnection(.other(error!))
            return cleanup()
        }

        for btCharacteristic in service.characteristics ?? [] {
            guard let characteristic = Characteristic(rawValue: btCharacteristic.uuid.uuidString) else { continue }
            switch characteristic {
            case .write:
                writeCharacteristic = btCharacteristic
            default:
                break
//            case .read:
//                readCharacteristic = btCharacteristic
//            case .modelName, .serialNumber, .firmware, .hardware, .software, .manufacturer:
//                printer?.readValue(for: btCharacteristic)
            }
        }
        // complete after all characteristics are processed
        self.completeConnection(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            return print("Error discovering characteristics: \(error?.localizedDescription ?? "")")
        }

        deviceData = characteristic.value
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            return print("Error changing notification state: \(error?.localizedDescription ?? "")")
        }

        guard characteristic.uuid == Characteristic.read.cbuuuid else { return }

        if characteristic.isNotifying {
            print("Notification began on \(characteristic)")
        } else {
            print("Notification stopped on \(characteristic).  Disconnecting")
            centralManager.cancelPeripheralConnection(peripheral)
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        printer = nil
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            finishSending?(.failure(.other(error!)))
            finishSending = nil
            return print("Error writing characteristic value: \(error?.localizedDescription ?? "")")
        }
        finishSending?(.success(characteristic.value))
        finishSending = nil
    }
}
