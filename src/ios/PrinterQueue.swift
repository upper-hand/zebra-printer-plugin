//
//  PrinterQueue.swift
//  Upper Hand
//
//  Created by Tim Baker on 11/4/18.
//

import Foundation

class PrinterQueue {

  static let shared = PrinterQueue()

  let queue = DispatchQueue(label: "zebra.upperhand.io", qos: DispatchQoS.userInitiated)

  func async(block: @escaping ()->()) {
    queue.async(execute: block)
  }
}
