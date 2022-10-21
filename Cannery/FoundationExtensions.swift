//
//  FoundationExtensions.swift
//  macOS
//
//  Created by Alex Zenla on 4/14/22.
//

import Foundation

extension FileManager {
    func fileExists(at url: URL) -> Bool {
        fileExists(atPath: url.path)
    }

    func fileExists(at url: URL, isDirectory: UnsafeMutablePointer<ObjCBool>) -> Bool {
        fileExists(atPath: url.path, isDirectory: isDirectory)
    }
}
