//
//  CannedMacView.swift
//  macOS
//
//  Created by Kenneth Endfinger on 3/22/22.
//

import SwiftUI
import Virtualization

struct CannedMacView: View {
    @ObservedObject
    var can: CannedMac

    @State
    var isResetVirtualMachineDialogOpen = false

    @State
    var isDownloadRestoreImageShown = false

    @State
    var isInstallerShown = false

    @State
    var isErrorShown = false

    @AppStorage("virtualMachineAutoBoot")
    private var virtualMachineAutoBoot = true

    var inhibitAutoBoot: Bool = false

    @State
    var size: CGSize?

    @State
    var nextMachineName: String

    @State
    var newMachineName: String = ""

    @ObservedObject
    var virtualMachineList = VirtualMachineList()

    var body: some View {
        GeometryReader { geometry in
            VirtualMachineView(can.vm, capturesSystemKeys: true)
                .task {
                    if !inhibitAutoBoot, virtualMachineAutoBoot, can.currentVmState == .stopped, can.state == .unknown {
                        await bootVirtualMachine()
                    }
                }
                .toolbar {
                    ToolbarItem {
                        if can.currentVmState == .stopped {
                            Button("􀊄") {
                                Task {
                                    await bootVirtualMachine()
                                }
                            }
                        } else {
                            Button("􀛷") {
                                can.vm?.stop { _ in }
                            }
                        }
                    }

                    ToolbarItem {
                        Button("􀺻") {
                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                        }
                    }
                }
                .sheet(isPresented: $isDownloadRestoreImageShown) {
                    DownloadInstallerView(can: can)
                        .frame(minWidth: 300, minHeight: 100)
                        .padding(.horizontal, 100)
                        .padding(.vertical)
                }
                .sheet(isPresented: $isInstallerShown) {
                    InstallerView(can: can)
                        .frame(minWidth: 300, minHeight: 100)
                        .padding(.horizontal, 100)
                        .padding(.vertical)
                }
                .sheet(isPresented: $can.isSwitchMachine) {
                    Form {
                        VStack {
                            Picker("Virtual Machine", selection: $nextMachineName) {
                                ForEach(virtualMachineList.virtualMachinesNames, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                            }

                            HStack {
                                Button("Cancel", role: .cancel) {
                                    can.isSwitchMachine = false
                                }

                                Button("Switch") {
                                    can.swapMachineName(name: nextMachineName)
                                    Task {
                                        await bootVirtualMachine()
                                    }
                                }
                            }
                        }
                    }.padding()
                }
                .sheet(isPresented: $can.isCreateMachine) {
                    Form {
                        VStack {
                            TextField("Virtual Machine Name", text: $newMachineName)
                                .frame(minWidth: 400)

                            HStack {
                                Button("Cancel", role: .cancel) {
                                    can.isCreateMachine = false
                                }

                                Button("Create") {
                                    do {
                                        try virtualMachineList.addVirtualMachine(newMachineName)
                                    } catch {
                                        can.setCurrentError(error)
                                        return
                                    }

                                    can.swapMachineName(name: newMachineName)
                                    Task {
                                        await bootVirtualMachine()
                                    }
                                }
                            }
                        }
                    }.padding()
                }
                .onChange(of: can.virtualMachineName) { nextMachineName in
                    self.nextMachineName = nextMachineName
                }
                .onChange(of: can.state) { state in
                    isDownloadRestoreImageShown = state == .downloadInstaller
                    isInstallerShown = state == .installingMacOS
                    isErrorShown = state == .error
                }
                .onChange(of: can.isResetRequested) { value in
                    if value {
                        isResetVirtualMachineDialogOpen = true
                    }
                }
                .onChange(of: geometry.size) { value in
                    self.size = value
                }
                .onChange(of: can.virtualMachineName) { value in
                    self.nextMachineName = value
                }
                .alert(can.error?.localizedDescription ?? "Unknown Error", isPresented: $isErrorShown) {}
                .confirmationDialog("Reset Virtual Machine", isPresented: $isResetVirtualMachineDialogOpen) {
                    Button("Delete All Data", role: .destructive) {
                        Task {
                            do {
                                try await can.deleteVirtualMachine()
                                await bootVirtualMachine()
                            } catch {
                                can.setCurrentError(error)
                            }
                        }
                    }

                    Button("Keep", role: .cancel) {
                        isResetVirtualMachineDialogOpen = false
                    }.keyboardShortcut(.defaultAction)
                }
        }
        .frame(
            minWidth: 800,
            idealWidth: 1920,
            maxWidth: nil,
            minHeight: 510,
            idealHeight: 1080,
            maxHeight: nil,
            alignment: .center
        )
    }

    func bootVirtualMachine() async {
        do {
            try await can.bootVirtualMachine(VirtualMachineOptions.loadFromUserDefaults(), currentViewSize: size ?? DisplayResolution.r1920_1080.cgSize)
        } catch {
            can.setCurrentError(error)
        }
    }
}

struct CannedMacView_Previews: PreviewProvider {
    static var previews: some View {
        CannedMacView(
            can: CannedMac(),
            inhibitAutoBoot: true,
            nextMachineName: "macOS"
        )
    }
}
