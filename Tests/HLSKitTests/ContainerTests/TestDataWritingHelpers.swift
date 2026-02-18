// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Data Writing Helpers

extension Data {

    mutating func appendUInt8(_ value: UInt8) {
        append(value)
    }

    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }

    mutating func appendUInt64(_ value: UInt64) {
        for i in stride(from: 56, through: 0, by: -8) {
            append(UInt8((value >> i) & 0xFF))
        }
    }

    mutating func appendFourCC(_ str: String) {
        let ascii = str.prefix(4)
        for char in ascii {
            append(char.asciiValue ?? 0x20)
        }
        for _ in ascii.count..<4 {
            append(0x20)
        }
    }

    mutating func appendFixedPoint16x16(_ value: Double) {
        let fixed = Int32(value * 65536.0)
        appendUInt32(UInt32(bitPattern: fixed))
    }
}
