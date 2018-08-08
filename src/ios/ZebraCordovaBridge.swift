//
//  ZebraCordovaBridge.swift
//  Upper Hand
//
//  Created by Tim Baker on 8/7/18.
//

import Foundation

@objc(ZebraCordovaBridge)
class ZebraCordovaBridge: CDVPlugin {
    fileprivate var wifi: ZebraPrinterWifi!
    fileprivate var bluetooth: ZebraPrinterBluetooth!

    override func pluginInitialize() {
        super.pluginInitialize()
        wifi = ZebraPrinterWifi()
        bluetooth = ZebraPrinterBluetooth()
    }

  // - MARK: WiFi

  enum GenericError: Error, LocalizedError {
      case addressRequired

      var errorDescription: String? {
          switch self {
          case .addressRequired: return "Address is required"
          }
      }
  }

  @objc func wifiDiscover(_ command: CDVInvokedUrlCommand) {
    let timeout = command.arguments[0] as? Double ?? 10
    wifi.discover(responsesTimeout: timeout) { devices in
      self.respond(.success(devices), for: command)
    }
  }

  @objc func wifiIsConnected(_  command: CDVInvokedUrlCommand) {
    wifi.checkConnection { (result) in
        self.respond(.success(result), for: command)
    }
  }

  @objc func wifiConnect(_  command: CDVInvokedUrlCommand) {
    let address = command.arguments[0] as? String ?? ""
    guard address != "" else { return respond(.failure(GenericError.addressRequired), for: command) }
    let port = command.arguments[0] as? Int

    wifi.connect(address: address, port: port, success: {
      self.respond(.success(nil), for: command)
    }) { error in
      self.respond(.failure(error), for: command)
    }
  }

  @objc func wifiDisconnect(_ command: CDVInvokedUrlCommand) {
    wifi.disconnect {
        self.respond(.success(nil), for: command)
    }
  }

  @objc func wifiSend(_ command: CDVInvokedUrlCommand) {
    let zpl = command.arguments[0] as? String ?? ""
    wifi.send(zpl, success: { data in
      self.respond(.success(nil), for: command)
    }) { error in
      self.respond(.failure(error), for: command)
    }
  }

  @objc func wifiPrint(_ command: CDVInvokedUrlCommand) {
    let zpl = command.arguments[0] as? String ?? ""
    wifi.print(zpl, success: { data in
      self.respond(.success(nil), for: command)
    }) { error in
      self.respond(.failure(error), for: command)
    }
  }

  @objc func wifiRead(_ command: CDVInvokedUrlCommand) {
    wifi.read(success: { data in
      self.respond(.success(data), for: command)
    }) { error in
      self.respond(.failure(error), for: command)
    }
  }


// - MARK: Bluetooth

  @objc func bluetoothDiscover(_ command: CDVInvokedUrlCommand) {
      let scanDuration = command.arguments[0] as? Double ?? 10
      bluetooth.discover(scanDuration: scanDuration) { devices in
          self.respond(.success(devices), for: command)
      }
  }

  @objc func bluetoothIsConnected(_  command: CDVInvokedUrlCommand) {
    respond(.success(bluetooth.isConnected()), for: command)
  }

  @objc func bluetoothConnect(_  command: CDVInvokedUrlCommand) {
    let device = command.arguments[0] as? String ?? ""
    guard device != "" else { return self.respond(.failure(GenericError.addressRequired), for: command) }
    bluetooth.connect(device: device, success: {
      self.respond(.success(nil), for: command)
    }) { error in
      self.respond(.failure(error), for: command)
    }
  }

  @objc func bluetoothDisconnect(_ command: CDVInvokedUrlCommand) {
    bluetooth.disconnect()
    respond(.success(nil), for: command)
  }

  @objc func bluetoothSend(_ command: CDVInvokedUrlCommand) {
    let zpl = command.arguments[0] as? String ?? ""
    bluetooth.send(zpl, success: { data in
      self.respond(.success(nil), for: command)
    }) { error in
      self.respond(.failure(error), for: command)
    }
  }
}
