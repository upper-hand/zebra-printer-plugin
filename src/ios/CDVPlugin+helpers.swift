
import Foundation

protocol ResultValue {}
extension Double: ResultValue {}
extension Int: ResultValue {}
extension Bool: ResultValue {}
extension String: ResultValue {}
extension Array: ResultValue {}

extension CDVPlugin {

  enum Result {
    case success(ResultValue?)
    case failure(Error?)

    var status: CDVCommandStatus {
      switch self {
      case .success(_): return CDVCommandStatus_OK
      case .failure(_): return CDVCommandStatus_ERROR
      }
    }
    var value: ResultValue? {
      switch self {
      case .success(let value): return value
      case .failure(let error): return error?.localizedDescription
      }
    }
  }

  private func buildPluginResult(status: CDVCommandStatus, value: ResultValue?) -> CDVPluginResult {
    guard let value = value else { return CDVPluginResult(status: status) }

    switch value {
    case let value as Double:
      return CDVPluginResult(status: status, messageAs: value)
    case let value as Int:
      return CDVPluginResult(status: status, messageAs: value)
    case let value as Bool:
      return CDVPluginResult(status: status, messageAs: value)
    case let value as String:
      return CDVPluginResult(status: status, messageAs: value)
    case let value as Array<Any>:
      return CDVPluginResult(status: status, messageAs: value)
    default:
      return CDVPluginResult(status: status)
    }
  }

  func respond(_ result: Result, for command: CDVInvokedUrlCommand) {
    let pluginResult = buildPluginResult(status: result.status, value: result.value)
    commandDelegate!.send(pluginResult, callbackId: command.callbackId)
  }
}
