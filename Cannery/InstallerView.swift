//
//  InstallerView.swift
//  macOS
//
//  Created by Kenneth Endfinger on 3/22/22.
//

import Foundation
import SwiftUI

struct InstallerView: View {
    @ObservedObject var can: CannedMac

    var body: some View {
        VStack {
            Text("Installing macOS: \(InstallerView.formatCurrentProgress(can.installerCurrentProgress))%")

            ProgressView(value: can.installerCurrentProgress)
        }
    }

    private static func formatCurrentProgress(_ value: Double) -> String {
        String(format: "%.f", value * 100.0)
    }
}
