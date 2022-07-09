//
//  VirtualMachineListView.swift
//  macOS
//
//  Created by Kenneth Endfinger on 5/7/22.
//

import Foundation
import SwiftUI

struct VirtualMachineListView: View {
    @ObservedObject var virtualMachineList: VirtualMachineList
    
    @State
    var isEditMachineShown = false
    
    @State
    var machineUnderEdit: CannedMac? = nil
    
    var body: some View {
        ForEach(virtualMachineList.machines, id: \.virtualMachineName) { mac in
            NavigationLink {
                MacVirtualMachineView(mac: mac)
                    .navigationTitle(mac.virtualMachineName)
            } label: {
                Label(mac.virtualMachineName, systemImage: "desktopcomputer")
            }
            .sheet(isPresented: $isEditMachineShown) {
                if let machineUnderEdit {
                    MacVirtualMachineConfigurationView(
                        actionButtonName: "Save",
                        options: machineUnderEdit.options,
                        saveAction: { options in
                            machineUnderEdit.options = options
                            do {
                                try machineUnderEdit.saveCurrentOptions()
                            } catch {
                                fatalError(error.localizedDescription)
                            }
                            self.machineUnderEdit = nil
                            isEditMachineShown = false
                        },
                        cancelAction: {
                            isEditMachineShown = false
                        }
                    )
                } else {
                    Text("Invalid Edit")
                }
            }
            .contextMenu {
                Button("Delete Virtual Machine") {
                    Task {
                        try await mac.deleteVirtualMachine()
                        virtualMachineList.machines.removeAll { $0.virtualMachineName == mac.virtualMachineName }
                    }
                }
                
                Button("Edit Virtual Machine") {
                    machineUnderEdit = mac
                    isEditMachineShown = true
                }
            }
        }
    }
}
