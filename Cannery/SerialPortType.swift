//
//  SerialPortType.swift
//  macOS
//
//  Created by Alex Zenla on 3/25/22.
//

import Foundation
import Virtualization

struct SerialPortType: Codable, RawRepresentable, Hashable {
    typealias RawValue = Int

    let rawValue: Int

    static let virtio = SerialPortType(rawValue: 0)

    #if CANNED_MAC_USE_PRIVATE_APIS
    static let pl011 = SerialPortType(rawValue: 1)
    static let p16550 = SerialPortType(rawValue: 2)
    #endif

    func createSerialPortConfiguration() -> VZSerialPortConfiguration {
        if rawValue == SerialPortType.virtio.rawValue {
            return VZVirtioConsoleDeviceSerialPortConfiguration()
        }

        #if CANNED_MAC_USE_PRIVATE_APIS
        if rawValue == SerialPortType.pl011.rawValue {
            return VZPrivateUtilities.createPL011SerialPortConfiguration()
        } else if rawValue == SerialPortType.p16550.rawValue {
            return VZPrivateUtilities.create16550SerialPortConfiguration()
        }
        #endif

        fatalError()
    }

    var hashValue: Int { rawValue.hashValue }
}
