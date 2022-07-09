//
//  DisplayResolution.swift
//  macOS
//
//  Created by Kenneth Endfinger on 3/25/22.
//

import Foundation

struct DisplayResolution: Codable, RawRepresentable, Hashable {
    let width: Int
    let height: Int
    let pixelsPerInch: Int
    let rawValue: Int

    init(rawValue: Int, width: Int, height: Int, pixelsPerInch: Int) {
        self.rawValue = rawValue
        self.width = width
        self.height = height
        self.pixelsPerInch = pixelsPerInch
    }

    init?(rawValue: Int) {
        if rawValue == 1 {
            self.rawValue = rawValue
            width = DisplayResolution.r1920_1080.width
            height = DisplayResolution.r1920_1080.height
            pixelsPerInch = DisplayResolution.r1920_1080.pixelsPerInch
        } else if rawValue == 2 {
            self.rawValue = rawValue
            width = DisplayResolution.r3840_2160.width
            height = DisplayResolution.r3840_2160.height
            pixelsPerInch = DisplayResolution.r3840_2160.pixelsPerInch
        } else if rawValue == 100 {
            self.rawValue = rawValue
            width = DisplayResolution.automatic.width
            height = DisplayResolution.automatic.height
            pixelsPerInch = DisplayResolution.automatic.pixelsPerInch
        } else {
            return nil
        }
    }

    typealias RawValue = Int

    static let r1920_1080 = DisplayResolution(rawValue: 1, width: 1920, height: 1080, pixelsPerInch: 80)
    static let r3840_2160 = DisplayResolution(rawValue: 2, width: 3840, height: 2160, pixelsPerInch: 157)
    static let automatic = DisplayResolution(rawValue: 100, width: 1920, height: 1080, pixelsPerInch: 80)

    var isAutomatic: Bool { width == 0 && height == 0 && pixelsPerInch == 0 }

    var hashValue: Int { rawValue.hashValue }

    var cgSize: CGSize { CGSize(width: width, height: height) }
}
