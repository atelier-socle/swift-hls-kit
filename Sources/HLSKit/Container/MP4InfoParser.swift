// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Parses semantic information from MP4 box hierarchy.
///
/// Interprets raw box payloads into structured track information
/// needed for HLS segmentation.
///
/// ```swift
/// let boxReader = MP4BoxReader()
/// let boxes = try boxReader.readBoxes(from: mp4Data)
/// let parser = MP4InfoParser()
/// let fileInfo = try parser.parseFileInfo(from: boxes)
/// ```
public struct MP4InfoParser: Sendable {

    /// Creates a new MP4 info parser.
    public init() {}

    /// Parse file-level info from top-level boxes.
    ///
    /// - Parameter boxes: Top-level boxes from MP4BoxReader.
    /// - Returns: Parsed file information.
    /// - Throws: `MP4Error` if required boxes are missing.
    public func parseFileInfo(
        from boxes: [MP4Box]
    ) throws(MP4Error) -> MP4FileInfo {
        let brands = parseBrands(from: boxes)
        guard
            let moov = boxes.first(where: {
                $0.type == MP4Box.BoxType.moov
            })
        else {
            throw .missingBox("moov")
        }
        let (timescale, duration) = try parseMvhd(moov)
        let tracks = try parseTracks(moov)
        return MP4FileInfo(
            timescale: timescale,
            duration: duration,
            brands: brands,
            tracks: tracks
        )
    }
}

// MARK: - ftyp Parsing

extension MP4InfoParser {

    private func parseBrands(
        from boxes: [MP4Box]
    ) -> [String] {
        guard
            let ftyp = boxes.first(where: {
                $0.type == MP4Box.BoxType.ftyp
            }),
            let payload = ftyp.payload,
            payload.count >= 8
        else {
            return []
        }
        var brands: [String] = []
        var reader = BinaryReader(data: payload)
        // Major brand (4 bytes)
        if let major = try? reader.readFourCC() {
            brands.append(major)
        }
        // Minor version (4 bytes) — skip
        _ = try? reader.skip(4)
        // Compatible brands (4 bytes each)
        while reader.remaining >= 4 {
            if let brand = try? reader.readFourCC() {
                if !brands.contains(brand) {
                    brands.append(brand)
                }
            }
        }
        return brands
    }
}

// MARK: - mvhd Parsing

extension MP4InfoParser {

    private func parseMvhd(
        _ moov: MP4Box
    ) throws(MP4Error) -> (UInt32, UInt64) {
        guard let mvhd = moov.findChild(MP4Box.BoxType.mvhd),
            let payload = mvhd.payload,
            payload.count >= 20
        else {
            throw .missingBox("mvhd")
        }
        do {
            var reader = BinaryReader(data: payload)
            let version = try reader.readUInt8()
            try reader.skip(3)  // flags

            let timescale: UInt32
            let duration: UInt64
            if version == 1 {
                try reader.skip(16)  // creation + modification
                timescale = try reader.readUInt32()
                duration = try reader.readUInt64()
            } else {
                try reader.skip(8)  // creation + modification
                timescale = try reader.readUInt32()
                duration = UInt64(try reader.readUInt32())
            }
            return (timescale, duration)
        } catch {
            throw .invalidBoxData(
                box: "mvhd",
                reason: error.localizedDescription
            )
        }
    }
}

// MARK: - Track Parsing

extension MP4InfoParser {

    private func parseTracks(
        _ moov: MP4Box
    ) throws(MP4Error) -> [TrackInfo] {
        var tracks: [TrackInfo] = []
        for trak in moov.tracks {
            let track = try parseTrack(trak)
            tracks.append(track)
        }
        return tracks
    }

    private func parseTrack(
        _ trak: MP4Box
    ) throws(MP4Error) -> TrackInfo {
        let trackId = try parseTkhd(trak)
        let mdia = try requireChild(trak, type: "mdia")
        let mdhd = try parseMdhd(mdia)
        let mediaType = parseHdlr(mdia)
        let dimensions = parseTkhdDimensions(trak)
        let minf = try requireChild(mdia, type: "minf")
        let stbl = try requireChild(minf, type: "stbl")
        let (codec, stsdData) = parseStsd(stbl)
        let hasSyncSamples =
            stbl.findChild(MP4Box.BoxType.stss) != nil

        return TrackInfo(
            trackId: trackId,
            mediaType: mediaType,
            timescale: mdhd.timescale,
            duration: mdhd.duration,
            codec: codec,
            dimensions: dimensions,
            language: mdhd.language,
            sampleDescriptionData: stsdData,
            hasSyncSamples: hasSyncSamples
        )
    }
}

// MARK: - tkhd Parsing

extension MP4InfoParser {

    private func parseTkhd(
        _ trak: MP4Box
    ) throws(MP4Error) -> UInt32 {
        guard let tkhd = trak.findChild(MP4Box.BoxType.tkhd),
            let payload = tkhd.payload,
            payload.count >= 20
        else {
            throw .missingBox("tkhd")
        }
        do {
            var reader = BinaryReader(data: payload)
            let version = try reader.readUInt8()
            try reader.skip(3)  // flags
            if version == 1 {
                try reader.skip(16)  // creation + modification
            } else {
                try reader.skip(8)  // creation + modification
            }
            return try reader.readUInt32()
        } catch {
            throw .invalidBoxData(
                box: "tkhd",
                reason: error.localizedDescription
            )
        }
    }

    private func parseTkhdDimensions(
        _ trak: MP4Box
    ) -> VideoDimensions? {
        guard let tkhd = trak.findChild(MP4Box.BoxType.tkhd),
            let payload = tkhd.payload
        else {
            return nil
        }
        do {
            var reader = BinaryReader(data: payload)
            let version = try reader.readUInt8()
            try reader.skip(3)  // flags
            if version == 1 {
                // v1: creation(8) + modification(8) + trackId(4)
                // + reserved(4) + duration(8) = 32
                try reader.skip(32)
            } else {
                // v0: creation(4) + modification(4) + trackId(4)
                // + reserved(4) + duration(4) = 20
                try reader.skip(20)
            }
            // reserved(8) + layer(2) + alternateGroup(2)
            // + volume(2) + reserved(2) + matrix(36)
            try reader.skip(52)
            let widthFixed = try reader.readFixedPoint16x16()
            let heightFixed = try reader.readFixedPoint16x16()
            let width = UInt16(widthFixed)
            let height = UInt16(heightFixed)
            if width == 0 && height == 0 {
                return nil
            }
            return VideoDimensions(width: width, height: height)
        } catch {
            return nil
        }
    }
}

// MARK: - mdhd Parsing

extension MP4InfoParser {

    /// Parsed mdhd result (avoids 3-member tuple).
    private struct MdhdResult {
        let timescale: UInt32
        let duration: UInt64
        let language: String?
    }

    private func parseMdhd(
        _ mdia: MP4Box
    ) throws(MP4Error) -> MdhdResult {
        guard let mdhd = mdia.findChild(MP4Box.BoxType.mdhd),
            let payload = mdhd.payload,
            payload.count >= 20
        else {
            throw .missingBox("mdhd")
        }
        do {
            var reader = BinaryReader(data: payload)
            let version = try reader.readUInt8()
            try reader.skip(3)  // flags

            let timescale: UInt32
            let duration: UInt64
            if version == 1 {
                try reader.skip(16)  // creation + modification
                timescale = try reader.readUInt32()
                duration = try reader.readUInt64()
            } else {
                try reader.skip(8)  // creation + modification
                timescale = try reader.readUInt32()
                duration = UInt64(try reader.readUInt32())
            }
            let langCode = try reader.readUInt16()
            let language = decodeLanguage(langCode)
            return MdhdResult(
                timescale: timescale,
                duration: duration,
                language: language
            )
        } catch {
            throw .invalidBoxData(
                box: "mdhd",
                reason: error.localizedDescription
            )
        }
    }

    /// Decode ISO 639-2/T packed language code.
    ///
    /// Each character is 5 bits, offset by 0x60:
    /// `bits[14:10] = char1, bits[9:5] = char2, bits[4:0] = char3`
    func decodeLanguage(_ packed: UInt16) -> String? {
        let c1 = (packed >> 10) & 0x1F
        let c2 = (packed >> 5) & 0x1F
        let c3 = packed & 0x1F
        guard c1 > 0, c2 > 0, c3 > 0 else { return nil }
        let chars: [Character] = [c1, c2, c3].compactMap {
            UnicodeScalar($0 + 0x60).map(Character.init)
        }
        let result = String(chars)
        return result == "und" ? nil : result
    }
}

// MARK: - hdlr Parsing

extension MP4InfoParser {

    private func parseHdlr(_ mdia: MP4Box) -> MediaTrackType {
        guard let hdlr = mdia.findChild(MP4Box.BoxType.hdlr),
            let payload = hdlr.payload,
            payload.count >= 12
        else {
            return .unknown
        }
        // version(1) + flags(3) + pre_defined(4) = skip 8
        // handler_type is at offset 8 (4 bytes)
        let start = payload.startIndex + 8
        guard start + 4 <= payload.endIndex else {
            return .unknown
        }
        let typeData = payload[start..<(start + 4)]
        guard
            let typeStr = String(
                data: Data(typeData), encoding: .ascii
            )
        else {
            return .unknown
        }
        return MediaTrackType(rawValue: typeStr) ?? .unknown
    }
}

// MARK: - stsd Parsing

extension MP4InfoParser {

    private func parseStsd(
        _ stbl: MP4Box
    ) -> (String, Data) {
        guard let stsd = stbl.findChild(MP4Box.BoxType.stsd),
            let payload = stsd.payload,
            payload.count >= 12
        else {
            return ("unknown", Data())
        }
        // version(1) + flags(3) + entryCount(4) = 8 bytes
        // Entry starts at offset 8
        // Entry: size(4) + type(4) + data...
        let entryStart = payload.startIndex + 8
        guard entryStart + 8 <= payload.endIndex else {
            return ("unknown", Data())
        }
        // Skip entry size (4 bytes), read codec FourCC
        let codecStart = entryStart + 4
        let codecData = payload[codecStart..<(codecStart + 4)]
        let codec =
            String(data: Data(codecData), encoding: .ascii)
            ?? "unknown"
        // Return entire stsd payload as sample description data
        return (codec, Data(payload))
    }
}

// MARK: - Track Analysis

extension MP4InfoParser {

    /// Parse detailed track analysis including sample tables.
    ///
    /// Use this when you need sample-level access for segmentation.
    /// For simple inspection, use `parseFileInfo` instead.
    ///
    /// - Parameter boxes: Top-level boxes from MP4BoxReader.
    /// - Returns: Array of track analyses with sample tables.
    /// - Throws: `MP4Error` if required boxes are missing.
    public func parseTrackAnalysis(
        from boxes: [MP4Box]
    ) throws(MP4Error) -> [MP4TrackAnalysis] {
        guard
            let moov = boxes.first(where: {
                $0.type == MP4Box.BoxType.moov
            })
        else {
            throw .missingBox("moov")
        }
        let stParser = SampleTableParser()
        var analyses: [MP4TrackAnalysis] = []
        for trak in moov.tracks {
            let info = try parseTrack(trak)
            let mdia = try requireChild(trak, type: "mdia")
            let minf = try requireChild(mdia, type: "minf")
            let stbl = try requireChild(minf, type: "stbl")
            let sampleTable = try stParser.parse(stbl: stbl)
            analyses.append(
                MP4TrackAnalysis(
                    info: info,
                    sampleTable: sampleTable
                )
            )
        }
        return analyses
    }
}

// MARK: - Helpers

extension MP4InfoParser {

    private func requireChild(
        _ box: MP4Box, type: String
    ) throws(MP4Error) -> MP4Box {
        guard let child = box.findChild(type) else {
            throw .missingBox(type)
        }
        return child
    }
}
