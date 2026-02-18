// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Provides sample-level queries on parsed MP4 sample tables.
///
/// Answers the questions needed for HLS segmentation:
/// - Where is sample N in the file?
/// - What is the timestamp of sample N?
/// - Which samples are keyframes?
/// - What are the byte ranges for a group of samples?
///
/// ```swift
/// let locator = SampleLocator(
///     sampleTable: table, timescale: 90000
/// )
/// let dts = locator.decodingTime(forSample: 0)
/// let segments = locator.calculateSegments(targetDuration: 6.0)
/// ```
///
/// - SeeAlso: ISO 14496-12, Section 8.6
public struct SampleLocator: Sendable {

    /// The underlying sample table.
    public let sampleTable: SampleTable

    /// The track timescale (ticks per second).
    public let timescale: UInt32

    /// Creates a sample locator.
    ///
    /// - Parameters:
    ///   - sampleTable: The parsed sample table.
    ///   - timescale: The track timescale from mdhd.
    public init(sampleTable: SampleTable, timescale: UInt32) {
        self.sampleTable = sampleTable
        self.timescale = timescale
    }
}

// MARK: - Timing

extension SampleLocator {

    /// Get the decoding timestamp (DTS) for a sample.
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: DTS in timescale units.
    public func decodingTime(forSample sampleIndex: Int) -> UInt64 {
        var dts: UInt64 = 0
        var remaining = sampleIndex
        for entry in sampleTable.timeToSample {
            let count = Int(entry.sampleCount)
            if remaining < count {
                dts += UInt64(remaining) * UInt64(entry.sampleDelta)
                return dts
            }
            dts += UInt64(count) * UInt64(entry.sampleDelta)
            remaining -= count
        }
        return dts
    }

    /// Get the presentation timestamp (PTS) for a sample.
    ///
    /// PTS = DTS + composition offset (if ctts is present).
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: PTS in timescale units.
    public func presentationTime(
        forSample sampleIndex: Int
    ) -> UInt64 {
        let dts = decodingTime(forSample: sampleIndex)
        guard let offsets = sampleTable.compositionOffsets else {
            return dts
        }
        var remaining = sampleIndex
        for entry in offsets {
            let count = Int(entry.sampleCount)
            if remaining < count {
                let offset = Int64(entry.sampleOffset)
                return UInt64(Int64(dts) + offset)
            }
            remaining -= count
        }
        return dts
    }

    /// Get the decoding timestamp in seconds.
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: DTS in seconds.
    public func decodingTimeSeconds(
        forSample sampleIndex: Int
    ) -> Double {
        guard timescale > 0 else { return 0 }
        let dts = decodingTime(forSample: sampleIndex)
        return Double(dts) / Double(timescale)
    }

    /// Get the duration of a sample in timescale units.
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: Sample duration in timescale units.
    public func sampleDuration(
        forSample sampleIndex: Int
    ) -> UInt32 {
        var remaining = sampleIndex
        for entry in sampleTable.timeToSample {
            let count = Int(entry.sampleCount)
            if remaining < count {
                return entry.sampleDelta
            }
            remaining -= count
        }
        return 0
    }
}

// MARK: - Location

extension SampleLocator {

    /// Get the byte size of a sample.
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: Size in bytes.
    public func sampleSize(forSample sampleIndex: Int) -> UInt32 {
        if sampleTable.uniformSampleSize > 0 {
            return sampleTable.uniformSampleSize
        }
        guard sampleIndex < sampleTable.sampleSizes.count else {
            return 0
        }
        return sampleTable.sampleSizes[sampleIndex]
    }

    /// Get the file offset of a sample.
    ///
    /// Uses stsc + stco + stsz to calculate:
    /// chunk offset + offset within chunk.
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: Byte offset from the start of the file.
    public func sampleOffset(forSample sampleIndex: Int) -> UInt64 {
        let (chunkIndex, sampleInChunk) = resolveChunk(
            forSample: sampleIndex
        )
        guard chunkIndex < sampleTable.chunkOffsets.count else {
            return 0
        }
        let chunkOffset = sampleTable.chunkOffsets[chunkIndex]
        // Sum sizes of samples before this one in the chunk
        let firstSampleInChunk = sampleIndex - sampleInChunk
        var offset = chunkOffset
        for i in firstSampleInChunk..<sampleIndex {
            offset += UInt64(sampleSize(forSample: i))
        }
        return offset
    }

    /// Get the file offset and size of a range of samples.
    ///
    /// - Parameters:
    ///   - start: First sample index (0-based).
    ///   - count: Number of samples.
    /// - Returns: Array of (offset, size) pairs.
    public func sampleRanges(
        start: Int, count: Int
    ) -> [(offset: UInt64, size: UInt32)] {
        var ranges: [(offset: UInt64, size: UInt32)] = []
        ranges.reserveCapacity(count)
        for i in start..<(start + count) {
            let offset = sampleOffset(forSample: i)
            let size = sampleSize(forSample: i)
            ranges.append((offset: offset, size: size))
        }
        return ranges
    }
}

// MARK: - Keyframes

extension SampleLocator {

    /// Check if a sample is a sync sample (keyframe).
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: True if the sample is a sync sample.
    public func isSyncSample(_ sampleIndex: Int) -> Bool {
        guard let syncSamples = sampleTable.syncSamples else {
            return true  // No stss means all samples are sync
        }
        // stss uses 1-based indices
        return syncSamples.contains(UInt32(sampleIndex + 1))
    }

    /// Get all sync sample indices (0-based).
    ///
    /// If stss is absent, returns all sample indices (all are sync).
    ///
    /// - Returns: Array of 0-based sync sample indices.
    public func syncSampleIndices() -> [Int] {
        if let syncSamples = sampleTable.syncSamples {
            return syncSamples.map { Int($0) - 1 }
        }
        return Array(0..<sampleTable.sampleCount)
    }

    /// Get the nearest sync sample at or before the given sample.
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: 0-based index of the nearest preceding sync sample.
    public func nearestSyncSample(
        atOrBefore sampleIndex: Int
    ) -> Int {
        guard let syncSamples = sampleTable.syncSamples else {
            return sampleIndex  // All are sync
        }
        // stss is 1-based, sorted ascending
        let target = UInt32(sampleIndex + 1)
        var best: UInt32 = syncSamples.first ?? 1
        for sample in syncSamples {
            if sample <= target {
                best = sample
            } else {
                break
            }
        }
        return Int(best) - 1
    }
}

// MARK: - Segmentation

extension SampleLocator {

    /// Calculate segment boundaries based on target duration.
    ///
    /// Segments are cut at keyframe boundaries closest to the
    /// target duration. For audio tracks (no stss), segments are
    /// cut at the target duration.
    ///
    /// - Parameter targetDuration: Target segment duration in seconds.
    /// - Returns: Array of segment descriptions.
    public func calculateSegments(
        targetDuration: Double
    ) -> [SegmentInfo] {
        let totalSamples = sampleTable.sampleCount
        guard totalSamples > 0, timescale > 0 else { return [] }

        let targetTicks = UInt64(targetDuration * Double(timescale))
        let syncIndices = syncSampleIndices()
        guard !syncIndices.isEmpty else { return [] }

        var segments: [SegmentInfo] = []
        var segmentStart = syncIndices[0]
        let segmentStartDTS = decodingTime(forSample: segmentStart)
        var accumulatedDTS = segmentStartDTS

        for i in 1..<syncIndices.count {
            let syncIndex = syncIndices[i]
            let syncDTS = decodingTime(forSample: syncIndex)
            let elapsed = syncDTS - accumulatedDTS

            if elapsed >= targetTicks {
                let count = syncIndex - segmentStart
                let duration = Double(elapsed) / Double(timescale)
                segments.append(
                    SegmentInfo(
                        firstSample: segmentStart,
                        sampleCount: count,
                        duration: duration,
                        startDTS: accumulatedDTS,
                        startPTS: presentationTime(
                            forSample: segmentStart
                        ),
                        startsWithKeyframe: true
                    )
                )
                segmentStart = syncIndex
                accumulatedDTS = syncDTS
            }
        }

        // Last segment: from current start to end
        let lastCount = totalSamples - segmentStart
        if lastCount > 0 {
            let lastSample = totalSamples - 1
            let endDTS =
                decodingTime(forSample: lastSample)
                + UInt64(sampleDuration(forSample: lastSample))
            let duration =
                Double(endDTS - accumulatedDTS) / Double(timescale)
            segments.append(
                SegmentInfo(
                    firstSample: segmentStart,
                    sampleCount: lastCount,
                    duration: duration,
                    startDTS: accumulatedDTS,
                    startPTS: presentationTime(
                        forSample: segmentStart
                    ),
                    startsWithKeyframe: isSyncSample(segmentStart)
                )
            )
        }

        return segments
    }
}

// MARK: - Private Helpers

extension SampleLocator {

    /// Resolve which chunk a sample belongs to and its position
    /// within that chunk.
    ///
    /// - Parameter sampleIndex: 0-based sample index.
    /// - Returns: (0-based chunk index, position within chunk).
    private func resolveChunk(
        forSample sampleIndex: Int
    ) -> (chunkIndex: Int, sampleInChunk: Int) {
        let entries = sampleTable.sampleToChunk
        guard !entries.isEmpty else { return (0, 0) }

        var samplesSoFar = 0
        let chunkCount = sampleTable.chunkOffsets.count

        for entryIdx in 0..<entries.count {
            let entry = entries[entryIdx]
            // firstChunk is 1-based
            let firstChunk = Int(entry.firstChunk) - 1
            let samplesPerChunk = Int(entry.samplesPerChunk)

            // Determine how many chunks use this pattern
            let nextFirst: Int
            if entryIdx + 1 < entries.count {
                nextFirst = Int(entries[entryIdx + 1].firstChunk) - 1
            } else {
                nextFirst = chunkCount
            }

            let chunksInRange = nextFirst - firstChunk
            let samplesInRange = chunksInRange * samplesPerChunk

            if sampleIndex < samplesSoFar + samplesInRange {
                let localSample = sampleIndex - samplesSoFar
                let chunkOffset = localSample / samplesPerChunk
                let sampleInChunk = localSample % samplesPerChunk
                return (firstChunk + chunkOffset, sampleInChunk)
            }
            samplesSoFar += samplesInRange
        }

        return (chunkCount - 1, 0)
    }
}
