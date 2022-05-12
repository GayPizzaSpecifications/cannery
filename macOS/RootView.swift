//
//  RootView.swift
//  macOS
//
//  Created by Kenneth Endfinger on 4/20/22.
//

import Foundation
import SwiftUI

struct RootView: View {
    @ObservedObject
    var virtualMachineList = VirtualMachineList()

    @State
    var newVirtualMachineName: String = ""

    @State
    var isCreateMachineShown = false

    var body: some View {
        NavigationView {
            List {
                NavigationLink {
                    Image(nsImage: NSImage(named: "AppIcon")!)
                        .navigationTitle("Home")
                        .toolbar {
                            ToolbarItem {
                                Button(action: createVirtualMachineClicked, label: {
                                    Image(systemName: "plus.square")
                                })
                            }
                        }
                } label: {
                    Label("Home", systemImage: "house")
                }

                Section("Virtual Machines") {
                    VirtualMachineListView(virtualMachineList: virtualMachineList)
                }
            }
            .listStyle(.sidebar)
        }
        .sheet(isPresented: $isCreateMachineShown) {
            MacVirtualMachineConfigurationView(
                actionButtonName: "Create",
                options: VirtualMachineOptions(virtualMachineName: "NewMachine"),
                saveAction: { options in
                    isCreateMachineShown = false
                    do {
                        try virtualMachineList.addVirtualMachine(options: options)
                    } catch {
                        fatalError(error.localizedDescription)
                    }
                },
                cancelAction: {
                    isCreateMachineShown = false
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleNavigationSidebar, label: {
                    Image(systemName: "sidebar.left")
                })
            }
        }
    }

    func createVirtualMachineClicked() {
        isCreateMachineShown = true
    }

    func toggleNavigationSidebar() {
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }

    func delete(at offsets: IndexSet) {
        Task {
            for offset in offsets {
                let machine = virtualMachineList.machines[offset]
                do {
                    try await machine.deleteVirtualMachine()
                } catch {
                    fatalError(error.localizedDescription)
                }
            }

            virtualMachineList.machines.remove(atOffsets: offsets)
        }
    }
}
