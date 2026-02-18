// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Audio Alignment

extension SampleLocator {

    /// Find audio samples that cover the same time span as a video
    /// segment.
    ///
    /// Converts the video segment's DTS range to this track's
    /// timescale, then finds the nearest audio samples.
    ///
    /// - Parameters:
    ///   - videoSegment: The video segment to align with.
    ///   - videoTimescale: The video track's timescale.
    /// - Returns: A `SegmentInfo` for the corresponding audio range.
    public func alignedAudioSegment(
        for videoSegment: SegmentInfo,
        videoTimescale: UInt32
    ) -> SegmentInfo {
        guard videoTimescale > 0, timescale > 0 else {
            return SegmentInfo(
                firstSample: 0, sampleCount: 0,
                duration: 0, startDTS: 0, startPTS: 0,
                startsWithKeyframe: true
            )
        }
        let totalSamples = sampleTable.sampleCount
        guard totalSamples > 0 else {
            return SegmentInfo(
                firstSample: 0, sampleCount: 0,
                duration: 0, startDTS: 0, startPTS: 0,
                startsWithKeyframe: true
            )
        }
        // Convert video start/end DTS to audio timescale
        let videoStartDTS = videoSegment.startDTS
        let videoEndDTS =
            videoStartDTS
            + UInt64(
                Double(videoSegment.duration) * Double(videoTimescale)
            )
        let audioStartDTS =
            videoStartDTS * UInt64(timescale)
            / UInt64(videoTimescale)
        let audioEndDTS =
            videoEndDTS * UInt64(timescale)
            / UInt64(videoTimescale)
        // Find first audio sample at or after audioStartDTS
        let firstSample = findSampleAtOrAfter(dts: audioStartDTS)
        // Find last audio sample before audioEndDTS
        let lastSample = findSampleBefore(dts: audioEndDTS)
        let first = min(firstSample, totalSamples - 1)
        let last = min(max(lastSample, first), totalSamples - 1)
        let count = last - first + 1
        let startDTS = decodingTime(forSample: first)
        let startPTS = presentationTime(forSample: first)
        let duration: Double
        if timescale > 0, count > 0 {
            let endSample = first + count - 1
            let endDTS =
                decodingTime(forSample: endSample)
                + UInt64(sampleDuration(forSample: endSample))
            duration = Double(endDTS - startDTS) / Double(timescale)
        } else {
            duration = 0
        }
        return SegmentInfo(
            firstSample: first,
            sampleCount: count,
            duration: duration,
            startDTS: startDTS,
            startPTS: startPTS,
            startsWithKeyframe: true
        )
    }

    /// Find the first sample whose DTS is >= the target.
    func findSampleAtOrAfter(dts target: UInt64) -> Int {
        let total = sampleTable.sampleCount
        for i in 0..<total where decodingTime(forSample: i) >= target {
            return i
        }
        return total
    }

    /// Find the last sample whose DTS is < the target.
    func findSampleBefore(dts target: UInt64) -> Int {
        let total = sampleTable.sampleCount
        var last = 0
        for i in 0..<total {
            if decodingTime(forSample: i) < target {
                last = i
            } else {
                break
            }
        }
        return last
    }
}
