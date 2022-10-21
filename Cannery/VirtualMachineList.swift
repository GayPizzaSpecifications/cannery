//
//  VirtualMachineList.swift
//  macOS
//
//  Created by Alex Zenla on 4/17/22.
//

import Foundation

class VirtualMachineList: ObservableObject {
    @Published
    var machines: [CannedMac] = []

    init() {
        do {
            try loadCurrentVirtualMachines()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private func loadCurrentVirtualMachines() throws {
        let virtualMachinesDirectory = try FileUtilities.getApplicationSupportDirectory()
        let virtualMachineURLs = try FileManager.default.contentsOfDirectory(
            at: virtualMachinesDirectory,
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { url in
            try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }

        let virtualMachinesNames = virtualMachineURLs.map { url in
            url.lastPathComponent
        }

        for virtualMachineName in virtualMachinesNames {
            machines.append(CannedMac(virtualMachineName: virtualMachineName))
        }
    }

    public func addVirtualMachine(options: VirtualMachineOptions) throws {
        let virtualMachinesDirectory = try FileUtilities.getApplicationSupportDirectory()
        let virtualMachineDirectory = virtualMachinesDirectory.appendingPathComponent(options.virtualMachineName)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(at: virtualMachineDirectory, isDirectory: &isDirectory),
           isDirectory.boolValue
        {
            throw UserError(.VirtualMachineExists, "Virtual Machine '\(options.virtualMachineName)' already exists.")
        }
        machines.append(CannedMac(virtualMachineName: options.virtualMachineName, options: options))
    }
}
