//
//  DownloadInstallerView.swift
//  macOS
//
//  Created by Kenneth Endfinger on 3/22/22.
//

import Foundation
import SwiftUI

struct DownloadInstallerView: View {
    @ObservedObject var can: CannedMac

    var body: some View {
        VStack {
            Text("Downloading macOS Installer: \(DownloadInstallerView.formatCurrentProgress(can.downloadCurrentProgress))%")

            ProgressView(value: can.downloadCurrentProgress)
        }
    }

    private static func formatCurrentProgress(_ value: Double) -> String {
        String(format: "%.2f", value * 100.0)
    }
}
