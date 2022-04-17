//
//  CannedMacApp.swift
//  macOS
//
//  Created by Kenneth Endfinger on 3/22/22.
//

import SwiftUI

@main
struct CannedMacApp: App {
    @ObservedObject
    var can = CannedMac(virtualMachineName: UserDefaults.standard.string(
        forKey: "virtualMachineName") ?? CannedMac.defaultVirtualMachineName)

    var body: some Scene {
        WindowGroup {
            CannedMacView(can: can, nextMachineName: can.virtualMachineName)
        }
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Create Virtual Machine") {
                    can.isCreateMachine = true
                }

                Button("Reset Virtual Machine") {
                    can.isResetRequested = true
                }

                Button("Switch Virtual Machine") {
                    can.isSwitchMachine = true
                }
            }

            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            CannedMacSettings()
        }
    }
}
