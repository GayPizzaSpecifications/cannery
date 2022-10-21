//
//  UserError.swift
//  macOS
//
//  Created by Alex Zenla on 3/22/22.
//

import Foundation

struct UserError: Error {
    let kind: UserErrorKind
    let message: String

    init(_ kind: UserErrorKind, _ message: String) {
        self.kind = kind
        self.message = message
    }
}

enum UserErrorKind {
    case DiskSpaceUnavailable
    case RestoreImageBad
    case DownloadFailed
    case VirtualMachineExists
}
