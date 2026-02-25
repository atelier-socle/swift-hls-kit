// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Delta Update Edge Cases", .timeLimit(.minutes(1)))
struct DeltaUpdateEdgeCaseTests {

    // MARK: - Helpers

    private func makeSegment(
        index: Int, duration: TimeInterval
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(),
            duration: duration,
            timestamp: .zero,
            isIndependent: true,
            filename: "seg\(index).m4s",
            frameCount: 0,
            codecs: []
        )
    }

    private func makeContext(
        segments: [LiveSegment],
        currentPartials: [LLPartialSegment] = [],
        mediaSequence: Int = 0,
        discontinuitySequence: Int = 0
    ) -> DeltaUpdateGenerator.DeltaContext {
        DeltaUpdateGenerator.DeltaContext(
            segments: segments,
            partials: [:],
            currentPartials: currentPartials,
            preloadHint: nil,
            serverControl: .standard(
                targetDuration: 2.0, partTargetDuration: 0.33334
            ),
            configuration: LLHLSConfiguration(
                segmentTargetDuration: 2.0
            ),
            mediaSequence: mediaSequence,
            discontinuitySequence: discontinuitySequence
        )
    }

    // MARK: - Edge Cases

    @Test("All segments within skip window (nothing skipped)")
    func allWithinSkipWindow() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 100.0)
        let segments = (0..<5).map {
            makeSegment(index: $0, duration: 2.0)
        }
        let count = gen.skippableSegmentCount(
            segments: segments, targetDuration: 2.0
        )
        #expect(count == 0)

        let ctx = makeContext(segments: segments)
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(!delta.contains("#EXT-X-SKIP:"))
        #expect(delta.contains("seg0.m4s"))
    }

    @Test("Exactly at skip boundary")
    func exactlyAtBoundary() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 8.0)
        let segments = (0..<5).map {
            makeSegment(index: $0, duration: 2.0)
        }
        let count = gen.skippableSegmentCount(
            segments: segments, targetDuration: 2.0
        )
        #expect(count == 1)
    }

    @Test("Very large canSkipUntil (minimal segments kept)")
    func veryLargeSkipUntil() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 2.0)
        let segments = (0..<10).map {
            makeSegment(index: $0, duration: 2.0)
        }
        let count = gen.skippableSegmentCount(
            segments: segments, targetDuration: 2.0
        )
        #expect(count == 9)
    }

    @Test("Delta with 0 partials (no partial tags)")
    func deltaNoPartials() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 4.0)
        let segments = (0..<5).map {
            makeSegment(index: $0, duration: 2.0)
        }
        let ctx = makeContext(segments: segments)
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(!delta.contains("#EXT-X-PART:"))
        #expect(delta.contains("#EXTINF:"))
    }

    @Test("Segments with varying durations")
    func varyingDurations() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 5.0)
        let segments = [
            makeSegment(index: 0, duration: 1.0),
            makeSegment(index: 1, duration: 2.0),
            makeSegment(index: 2, duration: 3.0),
            makeSegment(index: 3, duration: 4.0),
            makeSegment(index: 4, duration: 1.0)
        ]
        let count = gen.skippableSegmentCount(
            segments: segments, targetDuration: 4.0
        )
        #expect(count == 3)
    }

    @Test("Delta with discontinuity sequence > 0")
    func deltaWithDiscontinuitySequence() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 4.0)
        let segments = (0..<5).map {
            makeSegment(index: $0, duration: 2.0)
        }
        let ctx = makeContext(
            segments: segments,
            mediaSequence: 5,
            discontinuitySequence: 2
        )
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(delta.contains("#EXT-X-MEDIA-SEQUENCE:5"))
        #expect(delta.contains("#EXT-X-DISCONTINUITY-SEQUENCE:2"))
    }

    @Test("Delta with current partials")
    func deltaWithCurrentPartials() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 4.0)
        let segments = (0..<5).map {
            makeSegment(index: $0, duration: 2.0)
        }
        let currentPartials = [
            LLPartialSegment(
                duration: 0.33,
                uri: "seg5.0.mp4",
                isIndependent: true,
                segmentIndex: 5,
                partialIndex: 0
            )
        ]
        let ctx = makeContext(
            segments: segments,
            currentPartials: currentPartials
        )
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(delta.contains("seg5.0.mp4"))
    }
}
