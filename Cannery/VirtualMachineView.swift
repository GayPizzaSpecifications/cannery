//
//  VirtualMachineView.swift
//  macOS
//
//  Created by Alex Zenla on 3/22/22.
//

import Foundation
import SwiftUI
import Virtualization

struct VirtualMachineView: NSViewRepresentable {
    typealias NSViewType = VZVirtualMachineView

    let virtualMachine: VZVirtualMachine?
    let capturesSystemKeys: Bool

    init(_ virtualMachine: VZVirtualMachine?, capturesSystemKeys: Bool = false) {
        self.virtualMachine = virtualMachine
        self.capturesSystemKeys = capturesSystemKeys
    }

    func makeNSView(context _: Context) -> VZVirtualMachineView {
        VZVirtualMachineView()
    }

    func updateNSView(_ view: VZVirtualMachineView, context _: Context) {
        view.virtualMachine = virtualMachine
        view.capturesSystemKeys = capturesSystemKeys
    }
}
