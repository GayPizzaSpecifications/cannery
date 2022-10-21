//
//  MacVirtualMachineContainerView.swift
//  macOS
//
//  Created by Alex Zenla on 5/1/22.
//

import Foundation
import SwiftUI
import Virtualization

struct MacVirtualMachineContainerView: View {
    @ObservedObject var mac: CannedMac

    var body: some View {
        if mac.state == .bootVirtualMachine {
            VirtualMachineView(mac.vm, capturesSystemKeys: true)
        } else {
            PlayButtonView {
                Task {
                    await bootVirtualMachine()
                }
            }.onTapGesture {
                Task {
                    await bootVirtualMachine()
                }
            }
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
