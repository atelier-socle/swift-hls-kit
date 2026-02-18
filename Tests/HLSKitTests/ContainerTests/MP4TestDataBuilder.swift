// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Helper to build synthetic MP4 box data for testing.
enum MP4TestDataBuilder {

    // MARK: - Generic Box Builders

    /// Build a box with header + payload.
    static func box(type: String, payload: Data) -> Data {
        let size = UInt32(8 + payload.count)
        var data = Data()
        data.appendUInt32(size)
        data.appendFourCC(type)
        data.append(payload)
        return data
    }

    /// Build a container box with children.
    static func containerBox(
        type: String, children: [Data]
    ) -> Data {
        var payload = Data()
        for child in children {
            payload.append(child)
        }
        return box(type: type, payload: payload)
    }

    /// Build an extended size box (size == 1, 8-byte extended).
    static func extendedSizeBox(
        type: String, payload: Data
    ) -> Data {
        let totalSize = UInt64(16 + payload.count)
        var data = Data()
        data.appendUInt32(1)  // marker
        data.appendFourCC(type)
        data.appendUInt64(totalSize)
        data.append(payload)
        return data
    }

    /// Build a zero-size box (extends to end of container).
    static func zeroSizeBox(
        type: String, payload: Data
    ) -> Data {
        var data = Data()
        data.appendUInt32(0)  // size = 0
        data.appendFourCC(type)
        data.append(payload)
        return data
    }

    // MARK: - Specific Box Builders

    /// Build an ftyp box.
    static func ftyp(
        majorBrand: String = "isom",
        minorVersion: UInt32 = 0,
        compatibleBrands: [String] = ["isom", "iso2"]
    ) -> Data {
        var payload = Data()
        payload.appendFourCC(majorBrand)
        payload.appendUInt32(minorVersion)
        for brand in compatibleBrands {
            payload.appendFourCC(brand)
        }
        return box(type: "ftyp", payload: payload)
    }

    /// Build an mvhd box (version 0).
    static func mvhd(
        timescale: UInt32, duration: UInt32
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(0)  // creation time
        payload.appendUInt32(0)  // modification time
        payload.appendUInt32(timescale)
        payload.appendUInt32(duration)
        // rate(4) + volume(2) + reserved(10) + matrix(36) +
        // pre_defined(24) + next_track_ID(4) = 80 bytes
        payload.append(Data(repeating: 0, count: 80))
        return box(type: "mvhd", payload: payload)
    }

    /// Build an mvhd box (version 1).
    static func mvhdV1(
        timescale: UInt32, duration: UInt64
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(1)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt64(0)  // creation time
        payload.appendUInt64(0)  // modification time
        payload.appendUInt32(timescale)
        payload.appendUInt64(duration)
        payload.append(Data(repeating: 0, count: 80))
        return box(type: "mvhd", payload: payload)
    }

    /// Build a tkhd box (version 0).
    static func tkhd(
        trackId: UInt32,
        duration: UInt32,
        width: Double = 0,
        height: Double = 0
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(0)  // creation time
        payload.appendUInt32(0)  // modification time
        payload.appendUInt32(trackId)
        payload.appendUInt32(0)  // reserved
        payload.appendUInt32(duration)
        // reserved(8) + layer(2) + alternateGroup(2) +
        // volume(2) + reserved(2) + matrix(36) = 52 bytes
        payload.append(Data(repeating: 0, count: 52))
        payload.appendFixedPoint16x16(width)
        payload.appendFixedPoint16x16(height)
        return box(type: "tkhd", payload: payload)
    }

    /// Build an mdhd box (version 0).
    static func mdhd(
        timescale: UInt32,
        duration: UInt32,
        language: String = "und"
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(0)  // creation time
        payload.appendUInt32(0)  // modification time
        payload.appendUInt32(timescale)
        payload.appendUInt32(duration)
        payload.appendUInt16(encodeLanguage(language))
        payload.appendUInt16(0)  // pre_defined
        return box(type: "mdhd", payload: payload)
    }

    /// Build an mdhd box (version 1).
    static func mdhdV1(
        timescale: UInt32,
        duration: UInt64,
        language: String = "und"
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(1)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt64(0)  // creation time
        payload.appendUInt64(0)  // modification time
        payload.appendUInt32(timescale)
        payload.appendUInt64(duration)
        payload.appendUInt16(encodeLanguage(language))
        payload.appendUInt16(0)  // pre_defined
        return box(type: "mdhd", payload: payload)
    }

    /// Build an hdlr box.
    static func hdlr(
        handlerType: String, name: String = ""
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(0)  // pre_defined
        payload.appendFourCC(handlerType)
        payload.append(Data(repeating: 0, count: 12))  // reserved
        if !name.isEmpty {
            payload.append(
                name.data(using: .utf8) ?? Data()
            )
        }
        payload.appendUInt8(0)  // null terminator
        return box(type: "hdlr", payload: payload)
    }

    /// Build a minimal stsd box.
    static func stsd(
        codec: String, data: Data = Data()
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(1)  // entry count
        // Entry: size(4) + codec(4) + extra data
        let entrySize = UInt32(8 + data.count)
        payload.appendUInt32(entrySize)
        payload.appendFourCC(codec)
        payload.append(data)
        return box(type: "stsd", payload: payload)
    }

    /// Build a minimal stbl box with required children.
    static func minimalStbl(
        codec: String = "avc1",
        hasSyncSamples: Bool = false
    ) -> Data {
        var children = [
            stsd(codec: codec),
            box(type: "stts", payload: emptyFullBox()),
            box(type: "stsc", payload: emptyFullBox()),
            box(type: "stsz", payload: emptyFullBox()),
            box(type: "stco", payload: emptyFullBox())
        ]
        if hasSyncSamples {
            children.append(
                box(type: "stss", payload: emptyFullBox())
            )
        }
        return containerBox(type: "stbl", children: children)
    }

    // MARK: - Complete Track Builders

    /// Build a complete video track.
    static func videoTrack(
        trackId: UInt32,
        timescale: UInt32 = 90000,
        duration: UInt32,
        width: Double,
        height: Double,
        codec: String = "avc1",
        hasSyncSamples: Bool = true
    ) -> Data {
        let tkhdBox = tkhd(
            trackId: trackId, duration: duration,
            width: width, height: height
        )
        let stblBox = minimalStbl(
            codec: codec, hasSyncSamples: hasSyncSamples
        )
        let minfBox = containerBox(
            type: "minf",
            children: [
                box(type: "vmhd", payload: emptyFullBox()),
                stblBox
            ]
        )
        let mdiaBox = containerBox(
            type: "mdia",
            children: [
                mdhd(
                    timescale: timescale, duration: duration,
                    language: "und"
                ),
                hdlr(handlerType: "vide", name: "VideoHandler"),
                minfBox
            ]
        )
        return containerBox(
            type: "trak", children: [tkhdBox, mdiaBox]
        )
    }

    /// Build a complete audio track.
    static func audioTrack(
        trackId: UInt32,
        timescale: UInt32 = 44100,
        duration: UInt32,
        codec: String = "mp4a",
        language: String = "eng"
    ) -> Data {
        let tkhdBox = tkhd(
            trackId: trackId, duration: duration
        )
        let stblBox = minimalStbl(codec: codec)
        let minfBox = containerBox(
            type: "minf",
            children: [
                box(type: "smhd", payload: emptyFullBox()),
                stblBox
            ]
        )
        let mdiaBox = containerBox(
            type: "mdia",
            children: [
                mdhd(
                    timescale: timescale, duration: duration,
                    language: language
                ),
                hdlr(handlerType: "soun", name: "SoundHandler"),
                minfBox
            ]
        )
        return containerBox(
            type: "trak", children: [tkhdBox, mdiaBox]
        )
    }

}

// MARK: - Full File Builders

extension MP4TestDataBuilder {

    /// Build a minimal MP4 file with ftyp + moov + mdat.
    static func minimalMP4(
        timescale: UInt32 = 600,
        duration: UInt32 = 6000
    ) -> Data {
        let ftypBox = ftyp()
        let moovBox = containerBox(
            type: "moov",
            children: [
                mvhd(timescale: timescale, duration: duration)
            ]
        )
        let mdatBox = box(
            type: "mdat",
            payload: Data(repeating: 0xFF, count: 16)
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        data.append(mdatBox)
        return data
    }

    /// Build a video MP4 with one video track.
    static func videoMP4(
        width: Double = 1920,
        height: Double = 1080,
        timescale: UInt32 = 90000,
        duration: UInt32 = 900000
    ) -> Data {
        let ftypBox = ftyp(
            majorBrand: "isom",
            compatibleBrands: ["isom", "iso2", "mp41"]
        )
        let track = videoTrack(
            trackId: 1,
            timescale: timescale,
            duration: duration,
            width: width, height: height
        )
        let moovBox = containerBox(
            type: "moov",
            children: [
                mvhd(timescale: 600, duration: 6000),
                track
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        return data
    }

    /// Build an MP4 with video + audio tracks.
    static func avMP4() -> Data {
        let ftypBox = ftyp(
            majorBrand: "isom",
            compatibleBrands: ["isom", "iso2", "mp41"]
        )
        let vTrack = videoTrack(
            trackId: 1, duration: 900000,
            width: 1920, height: 1080
        )
        let aTrack = audioTrack(
            trackId: 2, duration: 441000
        )
        let moovBox = containerBox(
            type: "moov",
            children: [
                mvhd(timescale: 600, duration: 6000),
                vTrack,
                aTrack
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        return data
    }
}

// MARK: - Language Encoding

extension MP4TestDataBuilder {

    static func encodeLanguage(_ lang: String) -> UInt16 {
        let chars = Array(lang.prefix(3))
        guard chars.count == 3 else { return 0x55C4 }  // "und"
        let c1 = UInt16(chars[0].asciiValue ?? 0) - 0x60
        let c2 = UInt16(chars[1].asciiValue ?? 0) - 0x60
        let c3 = UInt16(chars[2].asciiValue ?? 0) - 0x60
        return (c1 << 10) | (c2 << 5) | c3
    }

    private static func emptyFullBox() -> Data {
        // version(1) + flags(3) + entryCount(4) = 8 bytes
        var data = Data()
        data.appendUInt8(0)
        data.append(contentsOf: [0, 0, 0])
        data.appendUInt32(0)
        return data
    }
}
