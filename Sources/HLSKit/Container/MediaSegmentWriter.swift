// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates HLS media segments (moof + mdat).
///
/// Each segment contains one movie fragment per track with
/// sample metadata and the raw media data.
///
/// ```swift
/// let writer = MediaSegmentWriter()
/// let segment = try writer.generateMediaSegment(
///     segmentInfo: segmentInfo,
///     sequenceNumber: 1,
///     trackAnalysis: videoAnalysis,
///     sourceData: mp4Data
/// )
/// ```
///
/// - SeeAlso: ISO 14496-12, Section 8.8
public struct MediaSegmentWriter: Sendable {

    /// Creates a new media segment writer.
    public init() {}

    /// Generate a media segment for the given sample range.
    ///
    /// - Parameters:
    ///   - segmentInfo: Segment boundaries from SampleLocator.
    ///   - sequenceNumber: 1-based sequence number.
    ///   - trackAnalysis: Track analysis with sample table.
    ///   - sourceData: Original MP4 file data.
    /// - Returns: The segment data (styp + moof + mdat).
    public func generateMediaSegment(
        segmentInfo: SegmentInfo,
        sequenceNumber: UInt32,
        trackAnalysis: MP4TrackAnalysis,
        sourceData: Data
    ) throws(MP4Error) -> Data {
        let locator = trackAnalysis.locator
        let sampleData = collectSampleData(
            segmentInfo: segmentInfo,
            locator: locator,
            sourceData: sourceData
        )
        let traf = buildTraf(
            segmentInfo: segmentInfo,
            trackAnalysis: trackAnalysis,
            locator: locator,
            mdatPayloadSize: sampleData.count
        )
        return assembleSegment(
            sequenceNumber: sequenceNumber,
            trafs: [traf],
            mdatPayload: sampleData
        )
    }

    /// Generate a media segment for multiple tracks (muxed).
    ///
    /// - Parameters:
    ///   - video: Video track input (segment + analysis).
    ///   - audio: Audio track input (segment + analysis).
    ///   - sequenceNumber: 1-based sequence number.
    ///   - sourceData: Original MP4 file data.
    /// - Returns: The segment data (styp + moof + mdat).
    public func generateMuxedSegment(
        video: MuxedTrackInput,
        audio: MuxedTrackInput,
        sequenceNumber: UInt32,
        sourceData: Data
    ) throws(MP4Error) -> Data {
        let videoLocator = video.analysis.locator
        let audioLocator = audio.analysis.locator
        let videoData = collectSampleData(
            segmentInfo: video.segment,
            locator: videoLocator,
            sourceData: sourceData
        )
        let audioData = collectSampleData(
            segmentInfo: audio.segment,
            locator: audioLocator,
            sourceData: sourceData
        )
        let mdatPayload = videoData + audioData
        let videoTraf = buildTraf(
            segmentInfo: video.segment,
            trackAnalysis: video.analysis,
            locator: videoLocator,
            mdatPayloadSize: mdatPayload.count,
            mdatSampleOffset: 0
        )
        let audioTraf = buildTraf(
            segmentInfo: audio.segment,
            trackAnalysis: audio.analysis,
            locator: audioLocator,
            mdatPayloadSize: mdatPayload.count,
            mdatSampleOffset: videoData.count
        )
        return assembleSegment(
            sequenceNumber: sequenceNumber,
            trafs: [videoTraf, audioTraf],
            mdatPayload: mdatPayload
        )
    }
}

// MARK: - styp

extension MediaSegmentWriter {

    private func buildStyp() -> Data {
        var payload = BinaryWriter()
        payload.writeFourCC("msdh")  // major brand
        payload.writeUInt32(0)  // minor version
        payload.writeFourCC("msdh")  // compatible brands
        payload.writeFourCC("msix")
        payload.writeFourCC("isom")
        var box = BinaryWriter()
        box.writeBox(type: "styp", payload: payload.data)
        return box.data
    }
}

// MARK: - Sample Data Collection

extension MediaSegmentWriter {

    private func collectSampleData(
        segmentInfo: SegmentInfo,
        locator: SampleLocator,
        sourceData: Data
    ) -> Data {
        var sampleData = Data()
        let start = segmentInfo.firstSample
        let end = start + segmentInfo.sampleCount
        for i in start..<end {
            let offset = locator.sampleOffset(forSample: i)
            let size = locator.sampleSize(forSample: i)
            let byteStart = sourceData.startIndex + Int(offset)
            let byteEnd = byteStart + Int(size)
            guard byteEnd <= sourceData.endIndex else { continue }
            sampleData.append(sourceData[byteStart..<byteEnd])
        }
        return sampleData
    }
}

// MARK: - moof

extension MediaSegmentWriter {

    private func buildTraf(
        segmentInfo: SegmentInfo,
        trackAnalysis: MP4TrackAnalysis,
        locator: SampleLocator,
        mdatPayloadSize: Int,
        mdatSampleOffset: Int = 0
    ) -> TrafData {
        let info = trackAnalysis.info
        let tfhd = buildTfhd(trackId: info.trackId)
        let tfdt = buildTfdt(
            baseDecodeTime: segmentInfo.startDTS
        )
        let trun = buildTrun(
            segmentInfo: segmentInfo,
            locator: locator,
            hasCompositionOffsets:
                trackAnalysis.sampleTable.compositionOffsets != nil,
            hasSyncSamples: info.hasSyncSamples
        )
        return TrafData(
            tfhd: tfhd, tfdt: tfdt, trun: trun,
            mdatSampleOffset: mdatSampleOffset
        )
    }

    private func buildTfhd(trackId: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(trackId)
        var box = BinaryWriter()
        // flags 0x020000 = default-base-is-moof
        box.writeFullBox(
            type: "tfhd", version: 0, flags: 0x020000,
            payload: payload.data
        )
        return box.data
    }

    private func buildTfdt(baseDecodeTime: UInt64) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt64(baseDecodeTime)
        var box = BinaryWriter()
        // version 1 for 64-bit decode time
        box.writeFullBox(
            type: "tfdt", version: 1, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildTrun(
        segmentInfo: SegmentInfo,
        locator: SampleLocator,
        hasCompositionOffsets: Bool,
        hasSyncSamples: Bool
    ) -> TrunData {
        var flags: UInt32 = 0x000301
        // 0x001 = data-offset-present
        // 0x100 = sample-duration-present
        // 0x200 = sample-size-present
        if hasSyncSamples {
            flags |= 0x400  // sample-flags-present
        }
        let hasCTO =
            hasCompositionOffsets
            && hasCTOffsets(
                segmentInfo: segmentInfo, locator: locator
            )
        if hasCTO {
            flags |= 0x800  // sample-ct-offsets-present
        }
        var payload = BinaryWriter()
        payload.writeUInt32(UInt32(segmentInfo.sampleCount))
        // data_offset placeholder (will be patched)
        let dataOffsetPosition = payload.count
        payload.writeInt32(0)
        let start = segmentInfo.firstSample
        let end = start + segmentInfo.sampleCount
        for i in start..<end {
            payload.writeUInt32(
                locator.sampleDuration(forSample: i)
            )
            payload.writeUInt32(
                locator.sampleSize(forSample: i)
            )
            if hasSyncSamples {
                let isKeyframe = locator.isSyncSample(i)
                payload.writeUInt32(
                    isKeyframe
                        ? SampleFlags.syncSample
                        : SampleFlags.nonSyncSample
                )
            }
            if hasCTO {
                let dts = locator.decodingTime(forSample: i)
                let pts = locator.presentationTime(forSample: i)
                let offset = Int32(Int64(pts) - Int64(dts))
                payload.writeInt32(offset)
            }
        }
        return TrunData(
            flags: flags,
            payload: payload.data,
            dataOffsetPosition: dataOffsetPosition
        )
    }

    private func hasCTOffsets(
        segmentInfo: SegmentInfo, locator: SampleLocator
    ) -> Bool {
        let start = segmentInfo.firstSample
        let end = start + segmentInfo.sampleCount
        for i in start..<end {
            let dts = locator.decodingTime(forSample: i)
            let pts = locator.presentationTime(forSample: i)
            if dts != pts { return true }
        }
        return false
    }
}

// MARK: - Assembly

extension MediaSegmentWriter {

    private func assembleSegment(
        sequenceNumber: UInt32,
        trafs: [TrafData],
        mdatPayload: Data
    ) -> Data {
        let mdatHeaderSize = 8
        // Build moof with data_offset = 0 first to measure size
        let moof0 = buildMoof(
            sequenceNumber: sequenceNumber,
            trafs: trafs,
            dataOffset: 0,
            mdatSampleOffsets: trafs.map(\.mdatSampleOffset)
        )
        let moofSize = moof0.count
        // Rebuild with correct data_offset per traf
        let moof = buildMoof(
            sequenceNumber: sequenceNumber,
            trafs: trafs,
            dataOffset: Int32(moofSize + mdatHeaderSize),
            mdatSampleOffsets: trafs.map(\.mdatSampleOffset)
        )
        let styp = buildStyp()
        let mdat = buildMdat(payload: mdatPayload)
        var result = Data(capacity: styp.count + moof.count + mdat.count)
        result.append(styp)
        result.append(moof)
        result.append(mdat)
        return result
    }

    private func buildMoof(
        sequenceNumber: UInt32,
        trafs: [TrafData],
        dataOffset: Int32,
        mdatSampleOffsets: [Int]
    ) -> Data {
        let mfhd = buildMfhd(sequenceNumber: sequenceNumber)
        var children: [Data] = [mfhd]
        for (index, traf) in trafs.enumerated() {
            let offset = dataOffset + Int32(mdatSampleOffsets[index])
            let trafBox = buildTrafBox(
                traf: traf, dataOffset: offset
            )
            children.append(trafBox)
        }
        var writer = BinaryWriter()
        writer.writeContainerBox(type: "moof", children: children)
        return writer.data
    }

    private func buildMfhd(sequenceNumber: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(sequenceNumber)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mfhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildTrafBox(
        traf: TrafData, dataOffset: Int32
    ) -> Data {
        // Patch data_offset in trun payload
        var trunPayload = traf.trun.payload
        patchInt32(
            in: &trunPayload,
            at: traf.trun.dataOffsetPosition,
            value: dataOffset
        )
        var trunBox = BinaryWriter()
        trunBox.writeFullBox(
            type: "trun", version: 0,
            flags: traf.trun.flags,
            payload: trunPayload
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "traf",
            children: [traf.tfhd, traf.tfdt, trunBox.data]
        )
        return writer.data
    }

    private func buildMdat(payload: Data) -> Data {
        var writer = BinaryWriter()
        writer.writeBox(type: "mdat", payload: payload)
        return writer.data
    }
}

// MARK: - Helpers

extension MediaSegmentWriter {

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
