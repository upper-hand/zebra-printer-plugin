//
//  ZebraPrinterWifi.swift
//  Upper Hand
//
//  Created by Tim Baker on 8/7/18.
//

import Foundation

typealias WifiSuccess = ()->()
typealias WifiFailure = (ZebraPrinterWifi.ZebraError)->()

class ZebraPrinterWifi: NSObject {

    fileprivate static let DEFAULT_PORT = 6101

    enum ZebraError: Error, LocalizedError {
        case initializationFailed
        case disconnected
        case notReadyToPrint
        case internalError
        case other(Error)

        var errorDescription: String? {
            switch self {
            case .initializationFailed: return "Printer failed to initialize"
            case .notReadyToPrint:      return "Not ready to print"
            case .disconnected:         return "Printer not connected"
            case .internalError:        return "Internal Error"
            case .other(let error):     return description(for: error)
            }
        }

        private func description(for error: Error) -> String {
            let message = error.localizedDescription != "" ? error.localizedDescription : "unknown error"
            let code = (error as NSError).code
            return "Zebra SDK Error (\(code)): \(message)"
        }
    }

    fileprivate var printerConnection: ZebraPrinterConnection?
    fileprivate var printer: ZebraPrinter?

    fileprivate func isConnected() -> Bool {
        return self.printerConnection != nil && self.printerConnection!.isConnected()
    }
}


// - MARK: Printer interface

extension ZebraPrinterWifi {

    func discover(responsesTimeout: Double, success: @escaping ([String])->()) {
        PrinterQueue.shared.async {
            let timeout = Int(responsesTimeout * 1000)
            let printers = (try? NetworkDiscoverer.localBroadcast(withTimeout: timeout)) as? [DiscoveredPrinter] ?? [] // use default timeout
            let devices = printers.flatMap({ $0.address })
            success(devices)
        }
    }

    func checkConnection(result: @escaping (Bool)->()) {
        PrinterQueue.shared.async {
            result(self.isConnected())
        }
    }

    func connect(address: String, port: Int?, success: @escaping WifiSuccess, failure: @escaping WifiFailure) {
        PrinterQueue.shared.async {
            self.printer = nil
            let port = port ?? ZebraPrinterWifi.DEFAULT_PORT
            self.printerConnection = TcpPrinterConnection(address: address, andWithPort: port)
            self.printerConnection?.open()

            guard self.isConnected() else { return failure(.disconnected) }

            // Just load the printer to ensure initialization worked
            self.printer = try? ZebraPrinterFactory.getInstance(self.printerConnection as! NSObjectProtocol & ZebraPrinterConnection)
            guard self.printer != nil else { return failure(.initializationFailed) }

            success()
        }
    }

    func disconnect(complete: @escaping WifiSuccess) {
        PrinterQueue.shared.async {
            self.printerConnection?.close()
            complete()
        }
    }

    func send(_ zpl: String, success: @escaping WifiSuccess, failure: @escaping WifiFailure) {
        PrinterQueue.shared.async {
            guard self.isConnected() else { return failure(.disconnected) }
            guard let printer = self.printer else { return failure(.internalError) }

            do {
                let status = try printer.getCurrentStatus()
                guard status.isReadyToPrint else {
                    return failure(.notReadyToPrint)
                }
                try printer.getToolsUtil().sendCommand(zpl)
                success()
            } catch (let error) {
                failure(.other(error))
            }
        }
    }

    func print(_ zpl: String, success: @escaping WifiSuccess, failure: @escaping WifiFailure) {
        PrinterQueue.shared.async {
            guard self.isConnected() else { return failure(.disconnected) }

            let data = zpl.data(using: .utf8)
            var error: NSError?
            self.printerConnection!.write(data, error:&error)

            guard error == nil else { return failure(.other(error!)) }

            success()
        }
    }

    func read(success: @escaping (String)->(), failure: @escaping WifiFailure) {
        PrinterQueue.shared.async {
            guard self.isConnected() else { return failure(.disconnected) }
            do {
                let data = try self.printerConnection!.read()
                let dataAsString = String(bytes: data, encoding: .utf8) ?? ""
                success(dataAsString)
            } catch (let error) {
                failure(.other(error))
            }
        }
    }
}
