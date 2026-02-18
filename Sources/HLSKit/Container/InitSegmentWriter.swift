// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates the HLS initialization segment (init.mp4).
///
/// The init segment contains ftyp + moov with empty sample tables
/// and an mvex box. It provides the decoder with codec configuration
/// without any media data.
///
/// ```swift
/// let writer = InitSegmentWriter()
/// let initData = try writer.generateInitSegment(
///     fileInfo: fileInfo,
///     trackAnalyses: analyses
/// )
/// ```
///
/// - SeeAlso: ISO 14496-12, Section 8.8 (Movie Fragments)
public struct InitSegmentWriter: Sendable {

    /// Creates a new init segment writer.
    public init() {}

    /// Generate an initialization segment from parsed MP4 info.
    ///
    /// - Parameters:
    ///   - fileInfo: Parsed file info from MP4InfoParser.
    ///   - trackAnalyses: Track analyses with sample descriptions.
    /// - Returns: The init.mp4 data (ftyp + moov).
    public func generateInitSegment(
        fileInfo: MP4FileInfo,
        trackAnalyses: [MP4TrackAnalysis]
    ) throws(MP4Error) -> Data {
        var writer = BinaryWriter()
        let ftyp = buildFtyp()
        let moov = try buildMoov(
            fileInfo: fileInfo,
            trackAnalyses: trackAnalyses
        )
        writer.writeData(ftyp)
        writer.writeData(moov)
        return writer.data
    }
}

// MARK: - ftyp

extension InitSegmentWriter {

    private func buildFtyp() -> Data {
        var payload = BinaryWriter()
        payload.writeFourCC("isom")  // major brand
        payload.writeUInt32(0x200)  // minor version
        payload.writeFourCC("isom")  // compatible brands
        payload.writeFourCC("iso6")
        payload.writeFourCC("mp41")
        var box = BinaryWriter()
        box.writeBox(type: "ftyp", payload: payload.data)
        return box.data
    }
}

// MARK: - moov

extension InitSegmentWriter {

    private func buildMoov(
        fileInfo: MP4FileInfo,
        trackAnalyses: [MP4TrackAnalysis]
    ) throws(MP4Error) -> Data {
        let nextTrackId = (fileInfo.tracks.map(\.trackId).max() ?? 0) + 1
        let mvhd = buildMvhd(
            timescale: fileInfo.timescale,
            nextTrackId: nextTrackId
        )
        var children: [Data] = [mvhd]
        for analysis in trackAnalyses {
            let trak = buildTrak(analysis: analysis)
            children.append(trak)
        }
        let mvex = buildMvex(trackAnalyses: trackAnalyses)
        children.append(mvex)
        var writer = BinaryWriter()
        writer.writeContainerBox(type: "moov", children: children)
        return writer.data
    }

    private func buildMvhd(
        timescale: UInt32, nextTrackId: UInt32
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(0)  // duration = 0 (fragmented)
        payload.writeFixed16_16(1.0)  // rate
        payload.writeUInt16(0x0100)  // volume (1.0 as 8.8)
        payload.writeZeros(10)  // reserved
        // Identity matrix (36 bytes)
        writeIdentityMatrix(to: &payload)
        payload.writeZeros(24)  // pre_defined
        payload.writeUInt32(nextTrackId)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mvhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }
}

// MARK: - trak

extension InitSegmentWriter {

    private func buildTrak(analysis: MP4TrackAnalysis) -> Data {
        let info = analysis.info
        let tkhd = buildTkhd(info: info)
        let mdia = buildMdia(info: info)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "trak", children: [tkhd, mdia]
        )
        return writer.data
    }

    private func buildTkhd(info: TrackInfo) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(info.trackId)
        payload.writeUInt32(0)  // reserved
        payload.writeUInt32(0)  // duration = 0
        payload.writeZeros(8)  // reserved
        payload.writeUInt16(0)  // layer
        payload.writeUInt16(0)  // alternate group
        if info.mediaType == .audio {
            payload.writeUInt16(0x0100)  // volume 1.0
        } else {
            payload.writeUInt16(0)  // volume 0
        }
        payload.writeZeros(2)  // reserved
        writeIdentityMatrix(to: &payload)
        let width = Double(info.dimensions?.width ?? 0)
        let height = Double(info.dimensions?.height ?? 0)
        payload.writeFixed16_16(width)
        payload.writeFixed16_16(height)
        // flags 0x03 = track_enabled | track_in_movie
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tkhd", version: 0, flags: 0x03,
            payload: payload.data
        )
        return box.data
    }
}

// MARK: - mdia

extension InitSegmentWriter {

    private func buildMdia(info: TrackInfo) -> Data {
        let mdhd = buildMdhd(info: info)
        let hdlr = buildHdlr(mediaType: info.mediaType)
        let minf = buildMinf(info: info)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mdia", children: [mdhd, hdlr, minf]
        )
        return writer.data
    }

    private func buildMdhd(info: TrackInfo) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(info.timescale)
        payload.writeUInt32(0)  // duration = 0
        let langCode = encodeLanguage(info.language ?? "und")
        payload.writeUInt16(langCode)
        payload.writeUInt16(0)  // pre_defined
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mdhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildHdlr(mediaType: MediaTrackType) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // pre_defined
        payload.writeFourCC(mediaType.rawValue)
        payload.writeZeros(12)  // reserved
        let name: String
        switch mediaType {
        case .video: name = "VideoHandler"
        case .audio: name = "SoundHandler"
        default: name = "Handler"
        }
        payload.writeData(Data(name.utf8))
        payload.writeUInt8(0)  // null terminator
        var box = BinaryWriter()
        box.writeFullBox(
            type: "hdlr", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }
}

// MARK: - minf + stbl

extension InitSegmentWriter {

    private func buildMinf(info: TrackInfo) -> Data {
        let mediaHeader = buildMediaHeader(
            mediaType: info.mediaType
        )
        let dinf = buildDinf()
        let stbl = buildEmptyStbl(
            sampleDescriptionData: info.sampleDescriptionData
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "minf",
            children: [mediaHeader, dinf, stbl]
        )
        return writer.data
    }

    private func buildMediaHeader(
        mediaType: MediaTrackType
    ) -> Data {
        var box = BinaryWriter()
        if mediaType == .video {
            var payload = BinaryWriter()
            payload.writeUInt16(0)  // graphicsmode
            payload.writeZeros(6)  // opcolor
            box.writeFullBox(
                type: "vmhd", version: 0, flags: 1,
                payload: payload.data
            )
        } else {
            var payload = BinaryWriter()
            payload.writeUInt16(0)  // balance
            payload.writeUInt16(0)  // reserved
            box.writeFullBox(
                type: "smhd", version: 0, flags: 0,
                payload: payload.data
            )
        }
        return box.data
    }

    private func buildDinf() -> Data {
        // dref with a single self-reference entry
        var drefPayload = BinaryWriter()
        drefPayload.writeUInt32(1)  // entry count
        // url entry: self-contained (flag 0x01)
        var urlBox = BinaryWriter()
        urlBox.writeFullBox(
            type: "url ", version: 0, flags: 1,
            payload: Data()
        )
        drefPayload.writeData(urlBox.data)
        var dref = BinaryWriter()
        dref.writeFullBox(
            type: "dref", version: 0, flags: 0,
            payload: drefPayload.data
        )
        var dinf = BinaryWriter()
        dinf.writeContainerBox(
            type: "dinf", children: [dref.data]
        )
        return dinf.data
    }

    private func buildEmptyStbl(
        sampleDescriptionData: Data
    ) -> Data {
        // stsd: preserve from source (codec config)
        var stsd = BinaryWriter()
        stsd.writeBox(
            type: "stsd", payload: sampleDescriptionData
        )
        // Empty full boxes (version + flags + 0 entries)
        let emptyFullPayload = emptyEntryPayload()
        var stts = BinaryWriter()
        stts.writeFullBox(
            type: "stts", version: 0, flags: 0,
            payload: emptyFullPayload
        )
        var stsc = BinaryWriter()
        stsc.writeFullBox(
            type: "stsc", version: 0, flags: 0,
            payload: emptyFullPayload
        )
        // stsz: sample_size=0, sample_count=0
        var stszPayload = BinaryWriter()
        stszPayload.writeUInt32(0)  // sample_size
        stszPayload.writeUInt32(0)  // sample_count
        var stsz = BinaryWriter()
        stsz.writeFullBox(
            type: "stsz", version: 0, flags: 0,
            payload: stszPayload.data
        )
        var stco = BinaryWriter()
        stco.writeFullBox(
            type: "stco", version: 0, flags: 0,
            payload: emptyFullPayload
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "stbl",
            children: [
                stsd.data, stts.data, stsc.data,
                stsz.data, stco.data
            ]
        )
        return writer.data
    }

    private func emptyEntryPayload() -> Data {
        var w = BinaryWriter()
        w.writeUInt32(0)  // entry count = 0
        return w.data
    }
}

// MARK: - mvex

extension InitSegmentWriter {

    private func buildMvex(
        trackAnalyses: [MP4TrackAnalysis]
    ) -> Data {
        var children: [Data] = []
        for analysis in trackAnalyses {
            children.append(buildTrex(trackId: analysis.info.trackId))
        }
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mvex", children: children
        )
        return writer.data
    }

    private func buildTrex(trackId: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(trackId)
        payload.writeUInt32(1)  // default_sample_description_index
        payload.writeUInt32(0)  // default_sample_duration
        payload.writeUInt32(0)  // default_sample_size
        payload.writeUInt32(0)  // default_sample_flags
        var box = BinaryWriter()
        box.writeFullBox(
            type: "trex", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }
}

// MARK: - Helpers

extension InitSegmentWriter {

    private func writeIdentityMatrix(
        to writer: inout BinaryWriter
    ) {
        // 3x3 identity matrix in 16.16 fixed point (36 bytes)
        // [1, 0, 0, 0, 1, 0, 0, 0, 16384 (0x40000000)]
        writer.writeUInt32(0x0001_0000)  // 1.0
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeUInt32(0x0001_0000)  // 1.0
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeUInt32(0x4000_0000)  // 16384 (2.30 format)
    }

    private func encodeLanguage(_ lang: String) -> UInt16 {
        let chars = Array(lang.prefix(3))
        guard chars.count == 3 else { return 0x55C4 }
        let c1 = UInt16(chars[0].asciiValue ?? 0) - 0x60
        let c2 = UInt16(chars[1].asciiValue ?? 0) - 0x60
        let c3 = UInt16(chars[2].asciiValue ?? 0) - 0x60
        return (c1 << 10) | (c2 << 5) | c3
    }
}
