// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("DeltaUpdateGenerator", .timeLimit(.minutes(1)))
struct DeltaUpdateGeneratorTests {

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

    private func makeSegments(
        count: Int, duration: TimeInterval = 2.0
    ) -> [LiveSegment] {
        (0..<count).map { makeSegment(index: $0, duration: duration) }
    }

    private func makePartials(
        segmentIndex: Int, count: Int = 3
    ) -> [LLPartialSegment] {
        (0..<count).map { partIdx in
            LLPartialSegment(
                duration: 0.33334,
                uri: "seg\(segmentIndex).\(partIdx).mp4",
                isIndependent: partIdx == 0,
                segmentIndex: segmentIndex,
                partialIndex: partIdx
            )
        }
    }

    private func makeContext(
        segments: [LiveSegment],
        partials: [Int: [LLPartialSegment]] = [:],
        currentPartials: [LLPartialSegment] = [],
        preloadHint: PreloadHint? = nil,
        serverControl: ServerControlConfig? = nil,
        mediaSequence: Int = 0,
        discontinuitySequence: Int = 0,
        skipDateRanges: Bool = false
    ) -> DeltaUpdateGenerator.DeltaContext {
        let sc =
            serverControl
            ?? .standard(
                targetDuration: 2.0, partTargetDuration: 0.33334
            )
        return DeltaUpdateGenerator.DeltaContext(
            segments: segments,
            partials: partials,
            currentPartials: currentPartials,
            preloadHint: preloadHint,
            serverControl: sc,
            configuration: LLHLSConfiguration(
                segmentTargetDuration: 2.0
            ),
            mediaSequence: mediaSequence,
            discontinuitySequence: discontinuitySequence,
            skipDateRanges: skipDateRanges
        )
    }

    // MARK: - Skippable Count

    @Test("skippableSegmentCount with enough segments to skip")
    func skippableWithEnoughSegments() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 12.0)
        let segments = makeSegments(count: 10, duration: 2.0)
        let count = gen.skippableSegmentCount(
            segments: segments, targetDuration: 2.0
        )
        #expect(count == 4)
    }

    @Test("skippableSegmentCount when all recent (0 skippable)")
    func skippableAllRecent() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 100.0)
        let segments = makeSegments(count: 5, duration: 2.0)
        let count = gen.skippableSegmentCount(
            segments: segments, targetDuration: 2.0
        )
        #expect(count == 0)
    }

    @Test("skippableSegmentCount with single segment")
    func skippableSingleSegment() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 1.0)
        let segments = makeSegments(count: 1, duration: 2.0)
        let count = gen.skippableSegmentCount(
            segments: segments, targetDuration: 2.0
        )
        #expect(count == 0)
    }

    @Test("skippableSegmentCount with empty segments")
    func skippableEmpty() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 12.0)
        let count = gen.skippableSegmentCount(
            segments: [], targetDuration: 2.0
        )
        #expect(count == 0)
    }

    // MARK: - Skip Tag

    @Test("renderSkipTag basic output")
    func renderSkipTagBasic() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 12.0)
        let tag = gen.renderSkipTag(skippedCount: 5)
        #expect(tag == "#EXT-X-SKIP:SKIPPED-SEGMENTS=5")
    }

    @Test("renderSkipTag with date ranges")
    func renderSkipTagDateRanges() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 12.0)
        let tag = gen.renderSkipTag(
            skippedCount: 3,
            recentlyRemovedDateRanges: ["id1", "id2"]
        )
        #expect(tag.contains("SKIPPED-SEGMENTS=3"))
        #expect(tag.contains("RECENTLY-REMOVED-DATERANGES=\"id1\tid2\""))
    }

    @Test("renderSkipTag with empty date ranges omits attribute")
    func renderSkipTagEmptyDateRanges() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 12.0)
        let tag = gen.renderSkipTag(
            skippedCount: 3,
            recentlyRemovedDateRanges: []
        )
        #expect(!tag.contains("RECENTLY-REMOVED-DATERANGES"))
    }

    // MARK: - Delta Playlist

    @Test("generateDeltaPlaylist with skipped segments")
    func deltaWithSkipped() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 6.0)
        let segments = makeSegments(count: 8, duration: 2.0)
        var partials = [Int: [LLPartialSegment]]()
        for seg in segments {
            partials[seg.index] = makePartials(
                segmentIndex: seg.index
            )
        }
        let sc = ServerControlConfig.withDeltaUpdates(
            targetDuration: 2.0, partTargetDuration: 0.33334
        )
        let ctx = makeContext(
            segments: segments, partials: partials,
            serverControl: sc
        )
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(delta.contains("#EXTM3U"))
        #expect(delta.contains("#EXT-X-SKIP:SKIPPED-SEGMENTS="))
    }

    @Test("Delta playlist contains header")
    func deltaHeader() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 6.0)
        let segments = makeSegments(count: 8, duration: 2.0)
        let ctx = makeContext(segments: segments)
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(delta.contains("#EXT-X-VERSION:7"))
        #expect(delta.contains("#EXT-X-TARGETDURATION:"))
        #expect(delta.contains("#EXT-X-MEDIA-SEQUENCE:0"))
    }

    @Test("Delta playlist non-skipped segments have partials")
    func deltaNonSkippedPartials() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 4.0)
        let segments = makeSegments(count: 6, duration: 2.0)
        var partials = [Int: [LLPartialSegment]]()
        for seg in segments.suffix(3) {
            partials[seg.index] = makePartials(
                segmentIndex: seg.index
            )
        }
        let ctx = makeContext(
            segments: segments, partials: partials
        )
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(delta.contains("#EXT-X-PART:"))
        #expect(delta.contains("seg5.m4s"))
    }

    @Test("Delta playlist contains preload hint")
    func deltaPreloadHint() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 4.0)
        let segments = makeSegments(count: 5, duration: 2.0)
        let hint = PreloadHint(type: .part, uri: "seg5.0.mp4")
        let ctx = makeContext(
            segments: segments, preloadHint: hint
        )
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(delta.contains("#EXT-X-PRELOAD-HINT:"))
        #expect(delta.contains("seg5.0.mp4"))
    }

    @Test("Delta playlist contains SERVER-CONTROL")
    func deltaServerControl() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 6.0)
        let segments = makeSegments(count: 8, duration: 2.0)
        let sc = ServerControlConfig.withDeltaUpdates(
            targetDuration: 2.0, partTargetDuration: 0.33334
        )
        let ctx = makeContext(
            segments: segments, serverControl: sc
        )
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(delta.contains("#EXT-X-SERVER-CONTROL:"))
    }

    @Test("0 skippable returns full playlist without SKIP tag")
    func zeroSkippable() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 100.0)
        let segments = makeSegments(count: 3, duration: 2.0)
        let ctx = makeContext(segments: segments)
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(!delta.contains("#EXT-X-SKIP:"))
        #expect(delta.contains("seg0.m4s"))
        #expect(delta.contains("seg2.m4s"))
    }

    @Test("Delta with discontinuity in non-skipped region")
    func deltaWithDiscontinuity() {
        let gen = DeltaUpdateGenerator(canSkipUntil: 4.0)
        var segments = makeSegments(count: 6, duration: 2.0)
        segments[4] = LiveSegment(
            index: 4,
            data: Data(),
            duration: 2.0,
            timestamp: .zero,
            isIndependent: true,
            discontinuity: true,
            filename: "seg4.m4s",
            frameCount: 0,
            codecs: []
        )
        let ctx = makeContext(segments: segments)
        let delta = gen.generateDeltaPlaylist(context: ctx)
        #expect(delta.contains("#EXT-X-DISCONTINUITY"))
    }
}
