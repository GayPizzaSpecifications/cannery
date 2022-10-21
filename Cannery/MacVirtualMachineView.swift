//
//  MacVirtualMachineView.swift
//  macOS
//
//  Created by Alex Zenla on 4/20/22.
//

import Foundation
import SwiftUI

struct MacVirtualMachineView: View {
    @ObservedObject
    var mac: CannedMac

    @State
    var isDownloadInstallerMode = false

    @State
    var isInstallationMode = false

    @State
    var isErrorMode = false

    @State
    var currentStateString = "Stopped"

    var body: some View {
        MacVirtualMachineContainerView(mac: mac)
            .toolbar {
                ToolbarItem {
                    if mac.currentVmState == .stopped {
                        Button("􀊄") {
                            Task {
                                await bootVirtualMachine()
                            }
                        }
                    } else {
                        Button("􀛷") {
                            mac.vm?.stop { _ in }
                        }
                    }
                }
            }
            .navigationSubtitle(currentStateString)
            .sheet(isPresented: $isDownloadInstallerMode) {
                VStack {
                    DownloadInstallerView(can: mac)
                    Button("Cancel Download", role: .cancel) {
                        mac.cancelInstallerDownload()
                    }
                }
                .frame(minWidth: 300, minHeight: 100)
                .padding(.horizontal, 100)
                .padding(.vertical)
            }
            .sheet(isPresented: $isInstallationMode) {
                VStack {
                    InstallerView(can: mac)
                }
                .frame(minWidth: 300, minHeight: 100)
                .padding(.horizontal, 100)
                .padding(.vertical)
            }
            .alert(mac.error?.localizedDescription ?? "Unknown Error", isPresented: $isErrorMode) {
                Button("Continue", role: .cancel) {}
            }
            .onChange(of: mac.state) { state in
                isDownloadInstallerMode = state == .downloadInstaller
                isInstallationMode = state == .installingMacOS
                isErrorMode = state == .error
            }
            .onChange(of: mac.currentVmState) { state in
                currentStateString = mac.stateToString(state).capitalized
            }
    }

    func bootVirtualMachine() async {
        do {
            try await mac.bootVirtualMachine()
        } catch {
            mac.setCurrentError(error)
        }
    }
}
