//
//  CannedMacSettings.swift
//  macOS
//
//  Created by Kenneth Endfinger on 3/23/22.
//

import Foundation
import SwiftUI
import Virtualization

struct CannedMacSettings: View {
    @AppStorage("virtualMachineMemory")
    var virtualMachineMemoryGigabytes = 4.0

    @AppStorage("virtualMachineAutoBoot")
    var virtualMachineAutoBoot = true

    #if CANNED_MAC_USE_PRIVATE_APIS
    @AppStorage("virtualMachineBootRecovery")
    var virtualMachineBootRecovery = false

    @AppStorage("virtualMachineBootDfu")
    var virtualMachineBootDfu = false

    @AppStorage("virtualMachineBootStopInIBootStage1")
    var virtualMachineBootStopInIBootStage1 = false

    @AppStorage("virtualMachineBootStopInIBootStage2")
    var virtualMachineBootStopInIBootStage2 = false

    @AppStorage("virtualMachineEnableDebugStub")
    var virtualMachineEnableDebugStub = false

    @AppStorage("virtualMachineEnableVncServer")
    var virtualMachineEnableVncServer = false

    @AppStorage("virtualMachineEnableVncServerAuthentication")
    var virtualMachineEnableVncServerAuthentication = false

    @AppStorage("virtualMachineVncServerPort")
    var virtualMachineVncServerPort = 5905

    @AppStorage("virtualMachineVncServerPassword")
    var virtualMachineVncServerPassword = "hunter2"

    @AppStorage("virtualMachineEnableMacInput")
    var virtualMachineEnableMacInput = false
    #endif

    @AppStorage("virtualMachineEnableSerialPortOutput")
    var virtualMachineEnableSerialPortOutput = false

    @AppStorage("virtualMachineDisplayResolution")
    var virtualMachineDisplayResolution: DisplayResolution = .r1920_1080

    @AppStorage("virtualMachineSerialPortOutputType")
    var virtualMachineSerialPortOutputType: SerialPortType = .virtio

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Slider(value: $virtualMachineMemoryGigabytes, in: toGigabytes(VZVirtualMachineConfiguration.minimumAllowedMemorySize) ... toGigabytes(VZVirtualMachineConfiguration.maximumAllowedMemorySize)) {
                    Text("Virtual Machine Memory: \(virtualMachineMemoryGigabytes, specifier: "%.0f")GB")
                }

                Picker("Display Resolution", selection: $virtualMachineDisplayResolution) {
                    Text("1920x1080").tag(DisplayResolution.r1920_1080)
                    Text("3840x2160").tag(DisplayResolution.r3840_2160)
                    Text("Window Size on Boot").tag(DisplayResolution.automatic)
                }
            }

            Section(header: Text("Boot")) {
                Toggle("Auto-Boot", isOn: $virtualMachineAutoBoot)
                #if CANNED_MAC_USE_PRIVATE_APIS
                Toggle("Force Recovery Mode", isOn: $virtualMachineBootRecovery)
                Toggle("Force DFU Mode", isOn: $virtualMachineBootDfu)
                Toggle("Stop in iBoot Stage 1", isOn: $virtualMachineBootStopInIBootStage1)
                Toggle("Stop in iBoot Stage 2", isOn: $virtualMachineBootStopInIBootStage2)
                #endif
            }

            #if CANNED_MAC_USE_PRIVATE_APIS
            Section(header: Text("VNC")) {
                Toggle("VNC Server", isOn: $virtualMachineEnableVncServer)

                if virtualMachineEnableVncServer {
                    Toggle("VNC Server Authentication", isOn: $virtualMachineEnableVncServerAuthentication)
                }

                if virtualMachineEnableVncServer {
                    TextField("VNC Server Port", value: $virtualMachineVncServerPort, formatter: portNumberFormatter)
                        .textFieldStyle(.roundedBorder)
                }

                if virtualMachineEnableVncServerAuthentication {
                    SecureField("VNC Server Password", text: $virtualMachineVncServerPassword)
                }
            }
            #endif

            Section(header: Text("Advanced")) {
                Toggle("Serial Port Console", isOn: $virtualMachineEnableSerialPortOutput)

                if virtualMachineEnableSerialPortOutput {
                    Picker("Serial Port Type", selection: $virtualMachineSerialPortOutputType) {
                        Text("Virtio").tag(SerialPortType.virtio)
                        #if CANNED_MAC_USE_PRIVATE_APIS
                        Text("PL011").tag(SerialPortType.pl011)
                        Text("16550").tag(SerialPortType.p16550)
                        #endif
                    }
                }

                #if CANNED_MAC_USE_PRIVATE_APIS
                Toggle("Mac Input", isOn: $virtualMachineEnableMacInput)
                Toggle("Debug Stub", isOn: $virtualMachineEnableDebugStub)
                #endif
            }
        }
        .frame(width: 400)
        .padding()
    }

    private func toGigabytes(_ value: UInt64) -> Double {
        Double(value) / 1024.0 / 1024.0 / 1024.0
    }

    var portNumberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        return formatter
    }
}
