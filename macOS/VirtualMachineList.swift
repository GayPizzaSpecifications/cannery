//
//  VirtualMachineList.swift
//  macOS
//
//  Created by Kenneth Endfinger on 4/17/22.
//

import Foundation

class VirtualMachineList: ObservableObject {
    @Published
    var virtualMachinesNames: [String] = []

    init() {
        do {
            try loadCurrentVirtualMachines()
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private func loadCurrentVirtualMachines() throws {
        let virtualMachinesDirectory = try FileUtilities.getApplicationSupportDirectory()
        let virtualMachineURLs = try FileManager.default.contentsOfDirectory(at: virtualMachinesDirectory, includingPropertiesForKeys: [.isDirectoryKey]).filter { url in
            try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }

        let virtualMachinesNames = virtualMachineURLs.map { url in
            url.lastPathComponent
        }
        self.virtualMachinesNames = virtualMachinesNames
    }

    public func addVirtualMachine(_ name: String) throws {
        let virtualMachinesDirectory = try FileUtilities.getApplicationSupportDirectory()
        let virtualMachineDirectory = virtualMachinesDirectory.appendingPathComponent(name)

        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(at: virtualMachineDirectory, isDirectory: &isDirectory),
           isDirectory.boolValue {
            throw UserError(.VirtualMachineExists, "Virtual Machine '\(name)' already exists.")
        }
        try FileManager.default.createDirectory(at: virtualMachineDirectory, withIntermediateDirectories: true)
        try loadCurrentVirtualMachines()
    }
}
