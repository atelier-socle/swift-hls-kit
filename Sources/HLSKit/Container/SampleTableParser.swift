// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Parses sample table (stbl) box contents.
///
/// Extracts timing, sizing, chunk mapping, and sync sample
/// information needed for HLS segmentation.
///
/// ```swift
/// let parser = SampleTableParser()
/// let table = try parser.parse(stbl: stblBox)
/// print("Samples: \(table.sampleCount)")
/// ```
///
/// - SeeAlso: ISO 14496-12, Section 8.6
public struct SampleTableParser: Sendable {

    /// Creates a new sample table parser.
    public init() {}

    /// Parse a complete sample table from an stbl box.
    ///
    /// - Parameter stblBox: The stbl container box with children.
    /// - Returns: Parsed sample table.
    /// - Throws: `MP4Error` if required tables are missing or corrupt.
    public func parse(
        stbl stblBox: MP4Box
    ) throws(MP4Error) -> SampleTable {
        // stts is required
        guard let sttsBox = stblBox.findChild(MP4Box.BoxType.stts),
            let sttsData = sttsBox.payload
        else {
            throw .missingBox("stts")
        }
        let timeToSample = try parseTimeToSample(from: sttsData)

        // ctts is optional
        let compositionOffsets: [CompositionOffsetEntry]?
        if let cttsBox = stblBox.findChild(MP4Box.BoxType.ctts),
            let cttsData = cttsBox.payload
        {
            compositionOffsets = try parseCompositionOffsets(
                from: cttsData
            )
        } else {
            compositionOffsets = nil
        }

        // stsc is required
        guard let stscBox = stblBox.findChild(MP4Box.BoxType.stsc),
            let stscData = stscBox.payload
        else {
            throw .missingBox("stsc")
        }
        let sampleToChunk = try parseSampleToChunk(from: stscData)

        // stsz is required
        guard let stszBox = stblBox.findChild(MP4Box.BoxType.stsz),
            let stszData = stszBox.payload
        else {
            throw .missingBox("stsz")
        }
        let (uniformSize, sizes) = try parseSampleSizes(
            from: stszData
        )

        let chunkOffsets = try parseChunkOffsets(from: stblBox)
        let syncSamples = try parseSyncSamplesIfPresent(
            from: stblBox
        )

        return SampleTable(
            timeToSample: timeToSample,
            compositionOffsets: compositionOffsets,
            sampleToChunk: sampleToChunk,
            sampleSizes: sizes,
            uniformSampleSize: uniformSize,
            chunkOffsets: chunkOffsets,
            syncSamples: syncSamples
        )
    }
}

// MARK: - Composite Helpers

extension SampleTableParser {

    /// Parse chunk offsets from stco or co64.
    private func parseChunkOffsets(
        from stblBox: MP4Box
    ) throws(MP4Error) -> [UInt64] {
        if let stcoBox = stblBox.findChild(MP4Box.BoxType.stco),
            let stcoData = stcoBox.payload
        {
            return try parseChunkOffsets32(from: stcoData)
        }
        if let co64Box = stblBox.findChild(MP4Box.BoxType.co64),
            let co64Data = co64Box.payload
        {
            return try parseChunkOffsets64(from: co64Data)
        }
        throw .missingBox("stco/co64")
    }

    /// Parse sync samples if stss box is present.
    private func parseSyncSamplesIfPresent(
        from stblBox: MP4Box
    ) throws(MP4Error) -> [UInt32]? {
        guard
            let stssBox = stblBox.findChild(MP4Box.BoxType.stss),
            let stssData = stssBox.payload
        else {
            return nil
        }
        return try parseSyncSamples(from: stssData)
    }
}

// MARK: - Individual Table Parsers

extension SampleTableParser {

    /// Parse stts (decoding time-to-sample).
    ///
    /// - Parameter data: Raw stts box payload.
    /// - Returns: Array of time-to-sample entries.
    /// - Throws: `MP4Error` if data is truncated.
    func parseTimeToSample(
        from data: Data
    ) throws(MP4Error) -> [TimeToSampleEntry] {
        do {
            var reader = BinaryReader(data: data)
            try reader.skip(4)  // version + flags
            let entryCount = try reader.readUInt32()
            var entries: [TimeToSampleEntry] = []
            entries.reserveCapacity(Int(entryCount))
            for _ in 0..<entryCount {
                let sampleCount = try reader.readUInt32()
                let sampleDelta = try reader.readUInt32()
                entries.append(
                    TimeToSampleEntry(
                        sampleCount: sampleCount,
                        sampleDelta: sampleDelta
                    )
                )
            }
            return entries
        } catch {
            throw .invalidBoxData(
                box: "stts",
                reason: error.localizedDescription
            )
        }
    }

    /// Parse ctts (composition time offsets).
    ///
    /// - Parameter data: Raw ctts box payload.
    /// - Returns: Array of composition offset entries.
    /// - Throws: `MP4Error` if data is truncated.
    func parseCompositionOffsets(
        from data: Data
    ) throws(MP4Error) -> [CompositionOffsetEntry] {
        do {
            var reader = BinaryReader(data: data)
            let version = try reader.readUInt8()
            try reader.skip(3)  // flags
            let entryCount = try reader.readUInt32()
            var entries: [CompositionOffsetEntry] = []
            entries.reserveCapacity(Int(entryCount))
            for _ in 0..<entryCount {
                let sampleCount = try reader.readUInt32()
                let offset: Int32
                if version == 1 {
                    offset = try reader.readInt32()
                } else {
                    offset = Int32(
                        bitPattern: try reader.readUInt32()
                    )
                }
                entries.append(
                    CompositionOffsetEntry(
                        sampleCount: sampleCount,
                        sampleOffset: offset
                    )
                )
            }
            return entries
        } catch {
            throw .invalidBoxData(
                box: "ctts",
                reason: error.localizedDescription
            )
        }
    }

    /// Parse stsc (sample-to-chunk).
    ///
    /// - Parameter data: Raw stsc box payload.
    /// - Returns: Array of sample-to-chunk entries.
    /// - Throws: `MP4Error` if data is truncated.
    func parseSampleToChunk(
        from data: Data
    ) throws(MP4Error) -> [SampleToChunkEntry] {
        do {
            var reader = BinaryReader(data: data)
            try reader.skip(4)  // version + flags
            let entryCount = try reader.readUInt32()
            var entries: [SampleToChunkEntry] = []
            entries.reserveCapacity(Int(entryCount))
            for _ in 0..<entryCount {
                let firstChunk = try reader.readUInt32()
                let samplesPerChunk = try reader.readUInt32()
                let descIndex = try reader.readUInt32()
                entries.append(
                    SampleToChunkEntry(
                        firstChunk: firstChunk,
                        samplesPerChunk: samplesPerChunk,
                        sampleDescriptionIndex: descIndex
                    )
                )
            }
            return entries
        } catch {
            throw .invalidBoxData(
                box: "stsc",
                reason: error.localizedDescription
            )
        }
    }

    /// Parse stsz (sample sizes).
    ///
    /// - Parameter data: Raw stsz box payload.
    /// - Returns: Tuple of (uniform size, individual sizes).
    /// - Throws: `MP4Error` if data is truncated.
    func parseSampleSizes(
        from data: Data
    ) throws(MP4Error) -> (uniformSize: UInt32, sizes: [UInt32]) {
        do {
            var reader = BinaryReader(data: data)
            try reader.skip(4)  // version + flags
            let sampleSize = try reader.readUInt32()
            let sampleCount = try reader.readUInt32()
            if sampleSize > 0 {
                return (sampleSize, [])
            }
            var sizes: [UInt32] = []
            sizes.reserveCapacity(Int(sampleCount))
            for _ in 0..<sampleCount {
                sizes.append(try reader.readUInt32())
            }
            return (0, sizes)
        } catch {
            throw .invalidBoxData(
                box: "stsz",
                reason: error.localizedDescription
            )
        }
    }

    /// Parse stco (32-bit chunk offsets).
    ///
    /// - Parameter data: Raw stco box payload.
    /// - Returns: Array of chunk offsets as UInt64.
    /// - Throws: `MP4Error` if data is truncated.
    func parseChunkOffsets32(
        from data: Data
    ) throws(MP4Error) -> [UInt64] {
        do {
            var reader = BinaryReader(data: data)
            try reader.skip(4)  // version + flags
            let entryCount = try reader.readUInt32()
            var offsets: [UInt64] = []
            offsets.reserveCapacity(Int(entryCount))
            for _ in 0..<entryCount {
                offsets.append(UInt64(try reader.readUInt32()))
            }
            return offsets
        } catch {
            throw .invalidBoxData(
                box: "stco",
                reason: error.localizedDescription
            )
        }
    }

    /// Parse co64 (64-bit chunk offsets).
    ///
    /// - Parameter data: Raw co64 box payload.
    /// - Returns: Array of chunk offsets.
    /// - Throws: `MP4Error` if data is truncated.
    func parseChunkOffsets64(
        from data: Data
    ) throws(MP4Error) -> [UInt64] {
        do {
            var reader = BinaryReader(data: data)
            try reader.skip(4)  // version + flags
            let entryCount = try reader.readUInt32()
            var offsets: [UInt64] = []
            offsets.reserveCapacity(Int(entryCount))
            for _ in 0..<entryCount {
                offsets.append(try reader.readUInt64())
            }
            return offsets
        } catch {
            throw .invalidBoxData(
                box: "co64",
                reason: error.localizedDescription
            )
        }
    }

    /// Parse stss (sync samples / keyframes).
    ///
    /// - Parameter data: Raw stss box payload.
    /// - Returns: Array of 1-based sync sample indices.
    /// - Throws: `MP4Error` if data is truncated.
    func parseSyncSamples(
        from data: Data
    ) throws(MP4Error) -> [UInt32] {
        do {
            var reader = BinaryReader(data: data)
            try reader.skip(4)  // version + flags
            let entryCount = try reader.readUInt32()
            var samples: [UInt32] = []
            samples.reserveCapacity(Int(entryCount))
            for _ in 0..<entryCount {
                samples.append(try reader.readUInt32())
            }
            return samples
        } catch {
            throw .invalidBoxData(
                box: "stss",
                reason: error.localizedDescription
            )
        }
    }
}
