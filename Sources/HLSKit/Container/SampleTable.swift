// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Parsed sample table data for a single track.
///
/// Contains all the information from stbl needed for segmentation:
/// timing, sizes, chunk mapping, and sync sample positions.
///
/// - SeeAlso: ISO 14496-12, Section 8.6
public struct SampleTable: Sendable, Hashable {

    /// Decoding time-to-sample entries (from stts).
    public let timeToSample: [TimeToSampleEntry]

    /// Composition time offsets (from ctts, nil if absent).
    public let compositionOffsets: [CompositionOffsetEntry]?

    /// Sample-to-chunk mapping (from stsc).
    public let sampleToChunk: [SampleToChunkEntry]

    /// Individual sample sizes in bytes (from stsz).
    /// If uniformSampleSize is set, this array is empty.
    public let sampleSizes: [UInt32]

    /// Uniform sample size (non-zero means all samples have this size).
    public let uniformSampleSize: UInt32

    /// Chunk byte offsets in the file (from stco or co64).
    public let chunkOffsets: [UInt64]

    /// Sync sample indices — 1-based (from stss).
    /// Nil means all samples are sync samples (typical for audio).
    public let syncSamples: [UInt32]?

    /// Total number of samples in this track.
    public var sampleCount: Int {
        if uniformSampleSize > 0 {
            return timeToSample.reduce(0) {
                $0 + Int($1.sampleCount)
            }
        }
        return sampleSizes.count
    }
}

// MARK: - Entry Types

/// stts entry: a run of samples with the same delta.
///
/// - SeeAlso: ISO 14496-12, Section 8.6.1.2
public struct TimeToSampleEntry: Sendable, Hashable {
    /// Number of consecutive samples with this delta.
    public let sampleCount: UInt32
    /// Duration of each sample in timescale units.
    public let sampleDelta: UInt32
}

/// ctts entry: a run of samples with the same composition offset.
///
/// - SeeAlso: ISO 14496-12, Section 8.6.1.3
public struct CompositionOffsetEntry: Sendable, Hashable {
    /// Number of consecutive samples with this offset.
    public let sampleCount: UInt32
    /// Composition offset in timescale units (can be negative in v1).
    public let sampleOffset: Int32
}

/// stsc entry: defines how samples are packed into chunks.
///
/// - SeeAlso: ISO 14496-12, Section 8.7.4
public struct SampleToChunkEntry: Sendable, Hashable {
    /// First chunk number using this pattern (1-based).
    public let firstChunk: UInt32
    /// Number of samples in each chunk using this pattern.
    public let samplesPerChunk: UInt32
    /// Sample description index (typically 1).
    public let sampleDescriptionIndex: UInt32
}

// MARK: - Segment Info

/// Describes a segment for HLS segmentation.
public struct SegmentInfo: Sendable, Hashable {
    /// 0-based index of the first sample in this segment.
    public let firstSample: Int

    /// Number of samples in this segment.
    public let sampleCount: Int

    /// Segment duration in seconds.
    public let duration: Double

    /// Decoding timestamp of the first sample (in timescale units).
    public let startDTS: UInt64

    /// Presentation timestamp of the first sample (in timescale units).
    public let startPTS: UInt64

    /// Whether the first sample is a keyframe.
    public let startsWithKeyframe: Bool
}
