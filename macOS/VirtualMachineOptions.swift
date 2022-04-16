//
//  VirtualMachineOptions.swift
//  macOS
//
//  Created by Kenneth Endfinger on 3/25/22.
//

import Foundation

struct VirtualMachineOptions: Codable {
    var memoryInGigabytes: Int = 4
    var displayResolution: DisplayResolution = .r1920_1080

    #if CANNED_MAC_USE_PRIVATE_APIS
    var bootToRecovery: Bool = false
    var bootToDfuMode: Bool = false
    var gdbDebugStub: Bool = false
    var macInputMode: Bool = false
    var vncServerEnabled: Bool = false
    var vncServerPort: Int = 5905
    var vncServerAuthenticationEnabled: Bool = false
    var vncServerPassword: String = "hunter2"
    #endif

    var serialPortOutputEnabled: Bool = false
    var serialPortOutputType: SerialPortType = .virtio

    static func loadFromUserDefaults(_ defaults: UserDefaults = UserDefaults.standard) -> VirtualMachineOptions {
        var options = VirtualMachineOptions()

        var memoryInGigabytes = defaults.double(forKey: "virtualMachineMemory")
        if memoryInGigabytes == 0.0 {
            memoryInGigabytes = 4.0
        }
        options.memoryInGigabytes = Int(memoryInGigabytes)

        let displayResolutionRawValue = defaults.integer(forKey: "virtualMachineDisplayResolution")
        options.displayResolution = DisplayResolution(rawValue: displayResolutionRawValue) ?? .r1920_1080
        options.serialPortOutputEnabled = defaults.bool(forKey: "virtualMachineEnableSerialPortOutput")
        let serialPortOutputTypeRawValue = defaults.integer(forKey: "virtualMachineSerialPortOutputType")
        let serialPortOutputType = SerialPortType(rawValue: serialPortOutputTypeRawValue)
        options.serialPortOutputType = serialPortOutputType

        #if CANNED_MAC_USE_PRIVATE_APIS
        options.bootToRecovery = defaults.bool(forKey: "virtualMachineBootRecovery")
        options.bootToDfuMode = defaults.bool(forKey: "virtualMachineBootDfu")
        options.gdbDebugStub = defaults.bool(forKey: "virtualMachineEnableDebugStub")
        options.vncServerEnabled = defaults.bool(forKey: "virtualMachineEnableVncServer")
        options.vncServerPort = defaults.integer(forKey: "virtualMachineVncServerPort")

        if options.vncServerPort == 0 {
            options.vncServerPort = 5905
        }

        options.vncServerAuthenticationEnabled = defaults.bool(forKey: "virtualMachineEnableVncServerAuthentication")
        options.vncServerPassword = defaults.string(forKey: "virtualMachineVncServerPassword") ?? "hunter2"

        options.macInputMode = defaults.bool(forKey: "virtualMachineEnableMacInput")
        #endif
        return options
    }
}
