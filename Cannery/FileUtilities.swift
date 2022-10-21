//
//  FileUtilities.swift
//  macOS
//
//  Created by Alex Zenla on 3/22/22.
//

import Foundation

struct FileUtilities {
    static func createSparseImage(_ url: URL, size: Int64) throws {
        try adviseEnoughDiskSpace(url.deletingLastPathComponent(), size: size)

        let diskFd = open(url.path, O_RDWR | O_CREAT, S_IRUSR | S_IWUSR)
        if diskFd == -1 {
            fatalError("Cannot create empty image.")
        }

        var result = ftruncate(diskFd, size)
        if result != 0 {
            fatalError("ftruncate() failed.")
        }

        result = close(diskFd)
        if result != 0 {
            fatalError("Failed to close the image.")
        }
    }

    static func adviseEnoughDiskSpace(_ url: URL, size: Int64) throws {
        func throwDiskSpaceUnavailable(_ available: Int64) throws {
            let formatter = ByteCountFormatter()
            let neededSizePretty = formatter.string(fromByteCount: size)
            let availableSizePretty = formatter.string(fromByteCount: available)

            throw UserError(.DiskSpaceUnavailable, "Need \(neededSizePretty) of disk space, but only \(availableSizePretty) was available.")
        }

        let diskSpaceAvailable = try diskSpaceAvailable(url)
        if diskSpaceAvailable < size {
            try throwDiskSpaceUnavailable(diskSpaceAvailable)
        }
    }

    static func diskSpaceAvailable(_ url: URL? = nil) throws -> Int64 {
        let applicationSupportDirectoryUrl = try getApplicationSupportDirectory()
        let urlToCheck = url ?? applicationSupportDirectoryUrl

        let results = try urlToCheck.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let availableCapacityOnVolume = results.volumeAvailableCapacityForImportantUsage {
            return availableCapacityOnVolume
        } else {
            throw UserError(.DiskSpaceUnavailable, "Unable to query available capacity for the volume.")
        }
    }

    static func getApplicationSupportDirectory() throws -> URL {
        let url = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let vmDirUrl = url.appendingPathComponent("macOS-Virtual-Machines")
        try FileManager.default.createDirectory(at: vmDirUrl, withIntermediateDirectories: true)
        return vmDirUrl
    }

    static func getLegacyApplicationSupportDirectory() throws -> URL {
        let url = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return url.appendingPathComponent("macOS.vm")
    }
}
