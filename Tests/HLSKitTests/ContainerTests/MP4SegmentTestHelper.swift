// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Shared helpers for segment writer tests.
enum MP4SegmentTestHelper {

    /// Find a top-level box by type in serialized data.
    static func findBox(
        type: String, in data: Data
    ) throws -> (offset: Int, size: Int)? {
        var reader = BinaryReader(data: data)
        while reader.hasRemaining {
            let offset = reader.position
            let size = try reader.readUInt32()
            let boxType = try reader.readFourCC()
            if boxType == type {
                return (offset: offset, size: Int(size))
            }
            guard size >= 8 else { return nil }
            try reader.seek(to: offset + Int(size))
        }
        return nil
    }

    /// Find a child box inside a parent box range.
    static func findChildBox(
        type: String, in data: Data,
        parentOffset: Int, parentSize: Int
    ) throws -> (offset: Int, size: Int)? {
        let headerSize = 8
        let childStart = parentOffset + headerSize
        let childEnd = parentOffset + parentSize
        guard childEnd <= data.count else { return nil }
        let childData = data[childStart..<childEnd]
        var reader = BinaryReader(data: Data(childData))
        while reader.hasRemaining {
            let localOffset = reader.position
            let size = try reader.readUInt32()
            let boxType = try reader.readFourCC()
            if boxType == type {
                return (
                    offset: childStart + localOffset,
                    size: Int(size)
                )
            }
            guard size >= 8 else { return nil }
            try reader.seek(to: localOffset + Int(size))
        }
        return nil
    }

    /// Find mdat box and return offset to its payload.
    static func mdatPayloadOffset(in data: Data) -> Int {
        var reader = BinaryReader(data: data)
        while reader.hasRemaining {
            let offset = reader.position
            guard let size = try? reader.readUInt32(),
                let boxType = try? reader.readFourCC()
            else { break }
            if boxType == "mdat" {
                return offset + 8
            }
            guard size >= 8 else { break }
            try? reader.seek(to: offset + Int(size))
        }
        return 0
    }

    /// Build a standard AV analysis pair from avMP4WithData.
    static func makeAVAnalyses(
        sourceData: Data
    ) -> (video: MP4TrackAnalysis, audio: MP4TrackAnalysis) {
        let mdatOffset = mdatPayloadOffset(in: sourceData)
        let video = makeVideoAnalysis(mdatOffset: mdatOffset)
        let audio = makeAudioAnalysis(
            mdatOffset: mdatOffset + 90 * 100
        )
        return (video, audio)
    }

    private static func makeVideoAnalysis(
        mdatOffset: Int
    ) -> MP4TrackAnalysis {
        let info = TrackInfo(
            trackId: 1,
            mediaType: .video,
            timescale: 90000,
            duration: UInt64(90) * 3000,
            codec: "avc1",
            dimensions: VideoDimensions(width: 1920, height: 1080),
            language: "und",
            sampleDescriptionData: Data(),
            hasSyncSamples: true
        )
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 90, sampleDelta: 3000
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 90,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [UInt32](repeating: 100, count: 90),
            uniformSampleSize: 0,
            chunkOffsets: [UInt64(mdatOffset)],
            syncSamples: [1, 31, 61]
        )
        return MP4TrackAnalysis(info: info, sampleTable: table)
    }

    private static func makeAudioAnalysis(
        mdatOffset: Int
    ) -> MP4TrackAnalysis {
        let info = TrackInfo(
            trackId: 2,
            mediaType: .audio,
            timescale: 44100,
            duration: UInt64(430) * 1024,
            codec: "mp4a",
            dimensions: nil,
            language: "und",
            sampleDescriptionData: Data(),
            hasSyncSamples: false
        )
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 430, sampleDelta: 1024
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 430,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [],
            uniformSampleSize: 50,
            chunkOffsets: [UInt64(mdatOffset)],
            syncSamples: nil
        )
        return MP4TrackAnalysis(info: info, sampleTable: table)
    }
}
