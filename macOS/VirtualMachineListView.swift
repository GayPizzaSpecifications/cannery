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

    var body: some View {
        ForEach(virtualMachineList.machines, id: \.virtualMachineName) { mac in
            NavigationLink {
                MacVirtualMachineView(mac: mac)
                    .navigationTitle(mac.virtualMachineName)
            } label: {
                Label(mac.virtualMachineName, systemImage: "desktopcomputer")
            }
            .contextMenu {
                Button("Delete Virtual Machine") {
                    Task {
                        try await mac.deleteVirtualMachine()
                        virtualMachineList.machines.removeAll { $0.virtualMachineName == mac.virtualMachineName }
                    }
                }
            }
        }
    }
}
