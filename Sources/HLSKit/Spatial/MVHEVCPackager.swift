// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Produces fMP4 init and media segments for MV-HEVC stereoscopic video.
///
/// Creates ISOBMFF boxes with `hvc1` sample entries containing
/// the `vexu` (Video Extended Usage) box hierarchy required for
/// Apple Vision Pro spatial video playback.
///
/// The init segment includes stereoscopic signaling via:
/// - `stri` (Stereo View Information): signals left+right eyes
/// - `hero` (Hero Eye Description): designates the fallback eye
///
/// ```swift
/// let packager = MVHEVCPackager()
/// let processor = MVHEVCSampleProcessor()
/// let nalus = processor.extractNALUs(from: annexBData)
/// guard let params = processor.extractParameterSets(from: nalus)
/// else { return }
///
/// let config = SpatialVideoConfiguration.visionProStandard
/// let initSeg = packager.createInitSegment(
///     configuration: config,
///     parameterSets: params
/// )
/// let mediaSeg = packager.createMediaSegment(
///     nalus: mediaData,
///     configuration: config,
///     sequenceNumber: 1,
///     baseDecodeTime: 0,
///     sampleDurations: [3000]
/// )
/// ```
public struct MVHEVCPackager: Sendable {

    /// Creates a new MV-HEVC packager.
    public init() {}

    /// Creates an fMP4 initialization segment for MV-HEVC video.
    ///
    /// Structure: `ftyp` + `moov` (mvhd + trak + mvex).
    /// The trak contains an `hvc1` sample entry with `hvcC` and
    /// `vexu` (eyes/stri + hero) boxes.
    ///
    /// - Parameters:
    ///   - configuration: Spatial video configuration (resolution, codec).
    ///   - parameterSets: HEVC VPS/SPS/PPS from the bitstream.
    /// - Returns: The complete init segment data.
    public func createInitSegment(
        configuration: SpatialVideoConfiguration,
        parameterSets: HEVCParameterSets
    ) -> Data {
        let ftyp = buildFtyp()
        let moov = buildMoov(
            configuration: configuration,
            parameterSets: parameterSets
        )
        var writer = BinaryWriter()
        writer.writeData(ftyp)
        writer.writeData(moov)
        return writer.data
    }

    /// Creates an fMP4 media segment containing MV-HEVC video samples.
    ///
    /// Structure: `moof` (mfhd + traf) + `mdat` (length-prefixed NALUs).
    ///
    /// - Parameters:
    ///   - nalus: Length-prefixed NAL unit data for all samples.
    ///   - configuration: Spatial video configuration.
    ///   - sequenceNumber: Fragment sequence number (1-based).
    ///   - baseDecodeTime: Decode timestamp in timescale units.
    ///   - sampleDurations: Duration per sample in timescale units.
    /// - Returns: The complete media segment data.
    public func createMediaSegment(
        nalus: Data,
        configuration: SpatialVideoConfiguration,
        sequenceNumber: UInt32,
        baseDecodeTime: UInt64,
        sampleDurations: [UInt32]
    ) -> Data {
        let sampleSizes = computeSampleSizes(
            from: nalus, count: sampleDurations.count
        )
        let moof = assembleMoof(
            sequenceNumber: sequenceNumber,
            baseDecodeTime: baseDecodeTime,
            sampleSizes: sampleSizes,
            sampleDurations: sampleDurations
        )
        let mdat = buildMdat(payload: nalus)
        var writer = BinaryWriter()
        writer.writeData(moof)
        writer.writeData(mdat)
        return writer.data
    }
}

// MARK: - Init Segment Boxes

extension MVHEVCPackager {

    func buildFtyp() -> Data {
        var payload = BinaryWriter()
        payload.writeFourCC("isom")  // major brand
        payload.writeUInt32(0x200)  // minor version
        payload.writeFourCC("isom")  // compatible brand
        payload.writeFourCC("iso6")  // compatible brand
        var writer = BinaryWriter()
        writer.writeBox(type: "ftyp", payload: payload.data)
        return writer.data
    }

    func buildMoov(
        configuration: SpatialVideoConfiguration,
        parameterSets: HEVCParameterSets
    ) -> Data {
        let timescale = timescaleFromFrameRate(
            configuration.frameRate
        )
        let mvhd = buildMvhd(timescale: timescale)
        let trak = buildTrak(
            configuration: configuration,
            parameterSets: parameterSets,
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

    func timescaleFromFrameRate(_ frameRate: Double) -> UInt32 {
        if frameRate == 30.0 { return 90000 }
        if frameRate == 60.0 { return 90000 }
        if frameRate == 24.0 { return 48000 }
        if frameRate == 25.0 { return 50000 }
        return UInt32(frameRate * 1000)
    }

    func buildMvhd(timescale: UInt32) -> Data {
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

    func buildTrak(
        configuration: SpatialVideoConfiguration,
        parameterSets: HEVCParameterSets,
        timescale: UInt32
    ) -> Data {
        let tkhd = buildTkhd(
            width: configuration.width,
            height: configuration.height
        )
        let mdia = buildMdia(
            configuration: configuration,
            parameterSets: parameterSets,
            timescale: timescale
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "trak", children: [tkhd, mdia]
        )
        return writer.data
    }

    func buildTkhd(width: Int, height: Int) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(1)  // track ID
        payload.writeUInt32(0)  // reserved
        payload.writeUInt32(0)  // duration
        payload.writeZeros(8)  // reserved
        payload.writeUInt16(0)  // layer
        payload.writeUInt16(0)  // alternate group
        payload.writeUInt16(0)  // volume (0 for video)
        payload.writeZeros(2)  // reserved
        writeIdentityMatrix(to: &payload)
        payload.writeFixedPoint16x16(Double(width))
        payload.writeFixedPoint16x16(Double(height))
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tkhd", version: 0, flags: 0x03,
            payload: payload.data
        )
        return box.data
    }
}

// MARK: - Sample Size Computation

extension MVHEVCPackager {

    func computeSampleSizes(
        from data: Data, count: Int
    ) -> [UInt32] {
        guard count > 0, !data.isEmpty else {
            return Array(repeating: UInt32(data.count), count: max(count, 1))
        }
        if count == 1 {
            return [UInt32(data.count)]
        }
        // For multiple samples, distribute evenly
        let sampleSize = UInt32(data.count / count)
        let remainder = data.count % count
        var sizes = Array(repeating: sampleSize, count: count)
        if remainder > 0 {
            sizes[count - 1] += UInt32(remainder)
        }
        return sizes
    }
}

// MARK: - Shared Helpers

extension MVHEVCPackager {

    func writeIdentityMatrix(
        to writer: inout BinaryWriter
    ) {
        writer.writeUInt32(0x0001_0000)  // 1.0
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeUInt32(0x0001_0000)  // 1.0
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeUInt32(0x4000_0000)  // 2.30 format
    }

    func encodeLanguage(_ lang: String) -> UInt16 {
        let chars = Array(lang.prefix(3))
        guard chars.count == 3 else { return 0x55C4 }
        let c1 = UInt16(chars[0].asciiValue ?? 0) - 0x60
        let c2 = UInt16(chars[1].asciiValue ?? 0) - 0x60
        let c3 = UInt16(chars[2].asciiValue ?? 0) - 0x60
        return (c1 << 10) | (c2 << 5) | c3
    }

    func patchInt32(
        in data: inout Data,
        at offset: Int,
        value: Int32
    ) {
        let unsigned = UInt32(bitPattern: value)
        let start = data.startIndex + offset
        data[start] = UInt8((unsigned >> 24) & 0xFF)
        data[start + 1] = UInt8((unsigned >> 16) & 0xFF)
        data[start + 2] = UInt8((unsigned >> 8) & 0xFF)
        data[start + 3] = UInt8(unsigned & 0xFF)
    }
}
