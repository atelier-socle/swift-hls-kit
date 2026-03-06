// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Produces fMP4 init and media segments for IMSC1 subtitle tracks.
///
/// Creates ISOBMFF boxes with `stpp` sample entries per the
/// CMAF text track specification. The media segment payload
/// is rendered TTML XML from ``IMSC1Renderer``.
///
/// ```swift
/// let segmenter = IMSC1Segmenter()
/// let initSeg = segmenter.createInitSegment(language: "en")
/// let mediaSeg = segmenter.createMediaSegment(
///     document: doc,
///     sequenceNumber: 1,
///     baseDecodeTime: 0,
///     duration: 6000
/// )
/// ```
public struct IMSC1Segmenter: Sendable {

    /// Creates a new IMSC1 segmenter.
    public init() {}

    /// Creates an fMP4 initialization segment for an IMSC1 subtitle track.
    ///
    /// Structure: `ftyp` + `moov` (mvhd + trak + mvex).
    ///
    /// - Parameters:
    ///   - language: ISO 639-2/T three-letter language code (e.g. "eng").
    ///   - timescale: Media timescale (default 1000 for milliseconds).
    /// - Returns: The complete init segment data.
    public func createInitSegment(
        language: String = "und",
        timescale: UInt32 = 1000
    ) -> Data {
        let ftyp = buildFtyp()
        let moov = buildMoov(
            language: language,
            timescale: timescale
        )
        var writer = BinaryWriter()
        writer.writeData(ftyp)
        writer.writeData(moov)
        return writer.data
    }

    /// Creates an fMP4 media segment containing rendered TTML.
    ///
    /// Structure: `moof` (mfhd + traf) + `mdat` (TTML XML).
    ///
    /// - Parameters:
    ///   - document: The IMSC1 document to embed.
    ///   - sequenceNumber: Fragment sequence number (1-based).
    ///   - baseDecodeTime: Decode timestamp in timescale units.
    ///   - duration: Sample duration in timescale units.
    /// - Returns: The complete media segment data.
    public func createMediaSegment(
        document: IMSC1Document,
        sequenceNumber: UInt32,
        baseDecodeTime: UInt64,
        duration: UInt32
    ) -> Data {
        let ttml = IMSC1Renderer.render(document)
        let mdatPayload = Data(ttml.utf8)

        let moof = assembleMoof(
            sequenceNumber: sequenceNumber,
            baseDecodeTime: baseDecodeTime,
            sampleSize: UInt32(mdatPayload.count),
            duration: duration
        )
        let mdat = buildMdat(payload: mdatPayload)

        var writer = BinaryWriter()
        writer.writeData(moof)
        writer.writeData(mdat)
        return writer.data
    }
}

// MARK: - Init Segment Boxes

extension IMSC1Segmenter {

    private func buildFtyp() -> Data {
        var payload = BinaryWriter()
        payload.writeFourCC("isom")  // major brand
        payload.writeUInt32(0x200)  // minor version
        payload.writeFourCC("isom")  // compatible brand
        payload.writeFourCC("iso6")  // compatible brand
        var writer = BinaryWriter()
        writer.writeBox(type: "ftyp", payload: payload.data)
        return writer.data
    }

    private func buildMoov(
        language: String,
        timescale: UInt32
    ) -> Data {
        let mvhd = buildMvhd(timescale: timescale)
        let trak = buildTrak(
            language: language,
            timescale: timescale
        )
        let mvex = buildMvex()
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "moov",
            children: [mvhd, trak, mvex]
        )
        return writer.data
    }

    private func buildMvhd(timescale: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(0)  // duration (fragmented)
        payload.writeFixedPoint16x16(1.0)  // rate
        payload.writeUInt16(0x0100)  // volume (1.0 as 8.8)
        payload.writeZeros(10)  // reserved
        writeIdentityMatrix(to: &payload)
        payload.writeZeros(24)  // pre_defined
        payload.writeUInt32(2)  // next_track_ID
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mvhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildTrak(
        language: String,
        timescale: UInt32
    ) -> Data {
        let tkhd = buildTkhd()
        let mdia = buildMdia(
            language: language,
            timescale: timescale
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "trak", children: [tkhd, mdia]
        )
        return writer.data
    }

    private func buildTkhd() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(1)  // track ID
        payload.writeUInt32(0)  // reserved
        payload.writeUInt32(0)  // duration
        payload.writeZeros(8)  // reserved
        payload.writeUInt16(0)  // layer
        payload.writeUInt16(0)  // alternate group
        payload.writeUInt16(0)  // volume (0 for subtitle)
        payload.writeZeros(2)  // reserved
        writeIdentityMatrix(to: &payload)
        payload.writeFixedPoint16x16(0)  // width
        payload.writeFixedPoint16x16(0)  // height
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tkhd", version: 0, flags: 0x03,
            payload: payload.data
        )
        return box.data
    }

    private func buildMdia(
        language: String,
        timescale: UInt32
    ) -> Data {
        let mdhd = buildMdhd(
            language: language,
            timescale: timescale
        )
        let hdlr = buildHdlr()
        let minf = buildMinf(timescale: timescale)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mdia", children: [mdhd, hdlr, minf]
        )
        return writer.data
    }

    private func buildMdhd(
        language: String,
        timescale: UInt32
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(0)  // duration
        payload.writeUInt16(encodeLanguage(language))
        payload.writeUInt16(0)  // pre_defined
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mdhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildHdlr() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // pre_defined
        payload.writeFourCC("subt")  // handler type
        payload.writeZeros(12)  // reserved
        let name = "IMSC1 Subtitle Handler"
        payload.writeData(Data(name.utf8))
        payload.writeUInt8(0)  // null terminator
        var box = BinaryWriter()
        box.writeFullBox(
            type: "hdlr", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildMinf(timescale: UInt32) -> Data {
        let nmhd = buildNmhd()
        let dinf = buildDinf()
        let stbl = buildStbl(timescale: timescale)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "minf", children: [nmhd, dinf, stbl]
        )
        return writer.data
    }

    private func buildNmhd() -> Data {
        var box = BinaryWriter()
        box.writeFullBox(
            type: "nmhd", version: 0, flags: 0,
            payload: Data()
        )
        return box.data
    }

    private func buildDinf() -> Data {
        var drefPayload = BinaryWriter()
        drefPayload.writeUInt32(1)  // entry count
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

    private func buildStbl(timescale: UInt32) -> Data {
        let stsd = buildStsd(timescale: timescale)
        let emptyTables = buildEmptySampleTables()
        var children = [stsd]
        children.append(contentsOf: emptyTables)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "stbl", children: children
        )
        return writer.data
    }

    private func buildStsd(timescale: UInt32) -> Data {
        let stpp = buildStpp(timescale: timescale)
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // entry count
        payload.writeData(stpp)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "stsd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildStpp(timescale: UInt32) -> Data {
        let namespace = "http://www.w3.org/ns/ttml"
        let schemaLocation = ""
        var payload = BinaryWriter()
        // SampleEntry base: 6 reserved + data_reference_index
        payload.writeZeros(6)
        payload.writeUInt16(1)  // data_reference_index
        // stpp-specific: namespace (null-terminated)
        payload.writeData(Data(namespace.utf8))
        payload.writeUInt8(0)
        // schema_location (null-terminated, empty)
        payload.writeData(Data(schemaLocation.utf8))
        payload.writeUInt8(0)
        var box = BinaryWriter()
        box.writeBox(type: "stpp", payload: payload.data)
        return box.data
    }

    private func buildEmptySampleTables() -> [Data] {
        let empty = emptyEntryPayload()
        var stts = BinaryWriter()
        stts.writeFullBox(
            type: "stts", version: 0, flags: 0, payload: empty
        )
        var stsc = BinaryWriter()
        stsc.writeFullBox(
            type: "stsc", version: 0, flags: 0, payload: empty
        )
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
            type: "stco", version: 0, flags: 0, payload: empty
        )
        return [stts.data, stsc.data, stsz.data, stco.data]
    }

    private func buildMvex() -> Data {
        let trex = buildTrex()
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mvex", children: [trex]
        )
        return writer.data
    }

    private func buildTrex() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // track ID
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

    private func emptyEntryPayload() -> Data {
        var w = BinaryWriter()
        w.writeUInt32(0)
        return w.data
    }
}
