//
//  VirtualMachineOptions.swift
//  macOS
//
//  Created by Alex Zenla on 3/25/22.
//

import Foundation

struct VirtualMachineOptions: Codable {
    var virtualMachineName: String

    var memoryInGigabytes: Float64 = 4
    var displayResolution: DisplayResolution = .r1920_1080

    var bootToRecovery: Bool? = false
    var macInputMode: Bool? = true

    #if CANNED_MAC_USE_PRIVATE_APIS
    var bootToDfuMode: Bool? = false
    var stopInIBootStage1: Bool? = false
    var stopInIBootStage2: Bool? = false
    var gdbDebugStub: Bool? = false
    var vncServerEnabled: Bool? = false
    var vncServerPort: Int? = 5905
    var vncServerAuthenticationEnabled: Bool? = false
    var vncServerPassword: String? = "hunter2"
    #endif

    var serialPortOutputEnabled: Bool = false
    var serialPortOutputType: SerialPortType = .virtio

    var restoreIpswPath: String?

    func saveTo(url: URL) throws {
        let encoded = try PropertyListEncoder().encode(self)
        try encoded.write(to: url)
    }
}
