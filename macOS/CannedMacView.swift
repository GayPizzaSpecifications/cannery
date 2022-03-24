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

    @AppStorage("virtualMachineMemory")
    private var virtualMachineMemoryGigabytes = 4.0

    @AppStorage("virtualMachineAutoBoot")
    private var virtualMachineAutoBoot = true

    var inhibitAutoBoot: Bool = false

    var body: some View {
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
            .alert("macOS Virtual Machine Error", isPresented: $isErrorShown) {
                Text(can.error?.localizedDescription ?? "Unknown Error")
                    .padding()
            }
            .frame(
                minWidth: 800,
                idealWidth: 1920,
                maxWidth: nil,
                minHeight: 500,
                idealHeight: 1080,
                maxHeight: nil,
                alignment: .center
            )
    }

    func bootVirtualMachine() async {
        do {
            try await can.bootVirtualMachine(
                memory: Int(virtualMachineMemoryGigabytes)
            )
        } catch {
            can.setCurrentError(error)
        }
    }
}

struct CannedMacView_Previews: PreviewProvider {
    static var previews: some View {
        CannedMacView(
            can: CannedMac(),
            inhibitAutoBoot: true
        )
    }
}
