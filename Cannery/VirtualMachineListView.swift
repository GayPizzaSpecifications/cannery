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
    
    @ObservedObject
    private var machineEditState: EditState = EditState()

    var body: some View {
        ForEach(virtualMachineList.machines, id: \.virtualMachineName) { mac in
            NavigationLink {
                MacVirtualMachineView(mac: mac)
                    .navigationTitle(mac.virtualMachineName)
            } label: {
                Label(mac.virtualMachineName, systemImage: "desktopcomputer")
            }
            .sheet(isPresented: $isEditMachineShown) {
                if let machineUnderEdit = machineEditState.machineUnderEdit {
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
                            machineEditState.machineUnderEdit = nil
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
                    machineEditState.machineUnderEdit = mac
                    isEditMachineShown = true
                }
            }
        }
    }
    
    private class EditState: ObservableObject {
        var machineUnderEdit: CannedMac? = nil
    }
}
