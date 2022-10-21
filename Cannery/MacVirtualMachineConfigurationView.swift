//
//  MacVirtualMachineConfigurationView.swift
//  macOS
//
//  Created by Alex Zenla on 4/20/22.
//

import Foundation
import SwiftUI
import Virtualization

struct MacVirtualMachineConfigurationView: View {
    let actionButtonName: String
    let saveAction: (VirtualMachineOptions) -> Void
    let cancelAction: () -> Void

    @State var virtualMachineName: String = ""

    @State
    var virtualMachineMemoryGigabytes: Float64

    @State
    var virtualMachineDisplayResolution: DisplayResolution

    @State
    var virtualMachineBootRecovery: Bool
    
    #if CANNED_MAC_USE_PRIVATE_APIS
    @State
    var virtualMachineBootDfu: Bool

    @State
    var virtualMachineBootStopInIBootStage1: Bool

    @State
    var virtualMachineBootStopInIBootStage2: Bool

    @State
    var virtualMachineEnableDebugStub: Bool

    @State
    var virtualMachineEnableVncServer: Bool

    @State
    var virtualMachineEnableVncServerAuthentication: Bool

    @State
    var virtualMachineVncServerPort: Int

    @State
    var virtualMachineVncServerPassword: String
    #endif
    
    @State
    var virtualMachineEnableMacInput: Bool

    @State
    var virtualMachineEnableSerialPortOutput: Bool

    @State
    var virtualMachineSerialPortOutputType: SerialPortType

    @State
    var customIpswPath: String? = nil

    init(actionButtonName: String, options: VirtualMachineOptions, saveAction: @escaping (_ options: VirtualMachineOptions) -> Void, cancelAction: @escaping () -> Void) {
        self.actionButtonName = actionButtonName
        self.saveAction = saveAction
        self.cancelAction = cancelAction

        virtualMachineName = options.virtualMachineName
        virtualMachineMemoryGigabytes = options.memoryInGigabytes
        virtualMachineDisplayResolution = options.displayResolution
        #if CANNED_MAC_USE_PRIVATE_APIS
        virtualMachineBootRecovery = options.bootToRecovery ?? false
        virtualMachineBootDfu = options.bootToDfuMode ?? false
        virtualMachineBootStopInIBootStage1 = options.stopInIBootStage1 ?? false
        virtualMachineBootStopInIBootStage2 = options.stopInIBootStage2 ?? false
        virtualMachineEnableDebugStub = options.gdbDebugStub ?? false
        virtualMachineEnableVncServer = options.vncServerEnabled ?? false
        virtualMachineEnableVncServerAuthentication = options.vncServerAuthenticationEnabled ?? false
        virtualMachineVncServerPort = options.vncServerPort ?? 5905
        virtualMachineVncServerPassword = options.vncServerPassword ?? "hunter2"
        #endif
        virtualMachineEnableMacInput = options.macInputMode ?? true
        
        virtualMachineEnableSerialPortOutput = options.serialPortOutputEnabled
        virtualMachineSerialPortOutputType = options.serialPortOutputType
        virtualMachineBootRecovery = options.bootToRecovery ?? false
    }

    var body: some View {
        Text("\(actionButtonName) Virtual Machine")
            .fontWeight(.heavy)

        Form {
            TextField("Virtual Machine Name", text: $virtualMachineName)

            Slider(value: $virtualMachineMemoryGigabytes, in: toGigabytes(VZVirtualMachineConfiguration.minimumAllowedMemorySize) ... toGigabytes(VZVirtualMachineConfiguration.maximumAllowedMemorySize)) {
                Text("Virtual Machine Memory: \(virtualMachineMemoryGigabytes, specifier: "%.0f")GB")
            }

            Picker("Display Resolution", selection: $virtualMachineDisplayResolution) {
                Text("1920x1080").tag(DisplayResolution.r1920_1080)
                Text("3840x2160").tag(DisplayResolution.r3840_2160)
                Text("Window Size on Boot").tag(DisplayResolution.automatic)
            }

            Section(header: Text("Boot")) {
                Toggle("Force Recovery Mode", isOn: $virtualMachineBootRecovery)
                #if CANNED_MAC_USE_PRIVATE_APIS
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

                Toggle("Mac Input", isOn: $virtualMachineEnableMacInput)
                #if CANNED_MAC_USE_PRIVATE_APIS
                Toggle("Debug Stub", isOn: $virtualMachineEnableDebugStub)
                #endif

                Button("Custom Installation IPSW") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseDirectories = false
                    panel.allowedContentTypes = [
                        .init(filenameExtension: "ipsw")!
                    ]

                    if panel.runModal() == .OK {
                        customIpswPath = panel.url!.absoluteURL.path
                    }
                }
            }

            HStack {
                Button(actionButtonName) {
                    saveAction(saveToOptions())
                }

                Button("Cancel", role: .cancel) {
                    cancelAction()
                }
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .padding()
    }

    private func saveToOptions() -> VirtualMachineOptions {
        var options = VirtualMachineOptions(virtualMachineName: virtualMachineName)
        options.memoryInGigabytes = virtualMachineMemoryGigabytes
        options.displayResolution = virtualMachineDisplayResolution
        options.bootToRecovery = virtualMachineBootRecovery
        #if CANNED_MAC_USE_PRIVATE_APIS
        options.bootToDfuMode = virtualMachineBootDfu
        options.stopInIBootStage1 = virtualMachineBootStopInIBootStage1
        options.stopInIBootStage2 = virtualMachineBootStopInIBootStage2
        options.gdbDebugStub = virtualMachineEnableDebugStub
        options.vncServerEnabled = virtualMachineEnableVncServer
        options.vncServerPort = virtualMachineVncServerPort
        options.vncServerAuthenticationEnabled = virtualMachineEnableVncServerAuthentication
        options.vncServerPassword = virtualMachineVncServerPassword
        #endif
        options.macInputMode = virtualMachineEnableMacInput
        options.serialPortOutputEnabled = virtualMachineEnableSerialPortOutput
        options.serialPortOutputType = virtualMachineSerialPortOutputType
        options.restoreIpswPath = customIpswPath
        return options
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
