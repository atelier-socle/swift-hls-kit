// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("IFramePlaylistGenerator", .timeLimit(.minutes(1)))
struct IFramePlaylistGeneratorTests {

    // MARK: - Empty

    @Test("Empty generator produces valid I-Frames-Only playlist")
    func emptyGenerator() {
        let gen = IFramePlaylistGenerator()
        let playlist = gen.generate()
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-I-FRAMES-ONLY"))
        #expect(playlist.contains("#EXT-X-ENDLIST"))
    }

    // MARK: - Single Keyframe

    @Test("Single keyframe produces EXTINF + BYTERANGE")
    func singleKeyframe() {
        var gen = IFramePlaylistGenerator()
        gen.addKeyframe(
            segmentURI: "seg0.ts", byteOffset: 0, byteLength: 18432, duration: 6.006
        )
        let playlist = gen.generate()
        #expect(playlist.contains("#EXTINF:6.006,"))
        #expect(playlist.contains("#EXT-X-BYTERANGE:18432@0"))
        #expect(playlist.contains("seg0.ts"))
    }

    // MARK: - Multiple Keyframes

    @Test("Multiple keyframes all in order with correct byte ranges")
    func multipleKeyframes() {
        var gen = IFramePlaylistGenerator()
        gen.addKeyframe(segmentURI: "seg0.ts", byteOffset: 0, byteLength: 1000, duration: 6.0)
        gen.addKeyframe(segmentURI: "seg1.ts", byteOffset: 0, byteLength: 2000, duration: 6.0)
        gen.addKeyframe(segmentURI: "seg2.ts", byteOffset: 0, byteLength: 1500, duration: 6.0)
        let playlist = gen.generate()
        #expect(playlist.contains("seg0.ts"))
        #expect(playlist.contains("seg1.ts"))
        #expect(playlist.contains("seg2.ts"))
        #expect(playlist.contains("#EXT-X-BYTERANGE:1000@0"))
        #expect(playlist.contains("#EXT-X-BYTERANGE:2000@0"))
    }

    // MARK: - Target Duration

    @Test("targetDuration is ceil of max keyframe duration")
    func targetDurationCeil() {
        var gen = IFramePlaylistGenerator()
        gen.addKeyframe(segmentURI: "s0.ts", byteOffset: 0, byteLength: 100, duration: 5.5)
        gen.addKeyframe(segmentURI: "s1.ts", byteOffset: 0, byteLength: 100, duration: 6.8)
        #expect(gen.calculateTargetDuration() == 7)
    }

    // MARK: - Tags

    @Test("EXT-X-I-FRAMES-ONLY tag present")
    func iFramesOnlyTag() {
        let gen = IFramePlaylistGenerator()
        #expect(gen.generate().contains("#EXT-X-I-FRAMES-ONLY"))
    }

    @Test("EXT-X-ENDLIST present")
    func endListTag() {
        let gen = IFramePlaylistGenerator()
        #expect(gen.generate().contains("#EXT-X-ENDLIST"))
    }

    @Test("Version tag matches configuration")
    func versionTag() {
        var gen = IFramePlaylistGenerator(configuration: .init(version: 4))
        gen.addKeyframe(segmentURI: "s.ts", byteOffset: 0, byteLength: 100, duration: 6.0)
        #expect(gen.generate().contains("#EXT-X-VERSION:4"))
    }

    // MARK: - Configuration

    @Test("Configuration.standard preset")
    func standardConfig() {
        let config = IFramePlaylistGenerator.Configuration.standard
        #expect(config.version == 7)
        #expect(!config.includeDateTime)
        #expect(config.initSegmentURI == nil)
    }

    @Test("Configuration.fmp4 includes EXT-X-MAP")
    func fmp4Config() {
        var gen = IFramePlaylistGenerator(configuration: .fmp4)
        gen.addKeyframe(segmentURI: "s.m4s", byteOffset: 0, byteLength: 100, duration: 6.0)
        let playlist = gen.generate()
        #expect(playlist.contains("#EXT-X-MAP:URI=\"init.mp4\""))
    }

    // MARK: - Date-Time

    @Test("includeDateTime adds PROGRAM-DATE-TIME per keyframe")
    func includeDateTimeTags() {
        let refDate = Date(timeIntervalSince1970: 1_740_000_000)
        var gen = IFramePlaylistGenerator(configuration: .init(includeDateTime: true))
        gen.addKeyframe(
            segmentURI: "s.ts", byteOffset: 0, byteLength: 100,
            duration: 6.0, programDateTime: refDate
        )
        #expect(gen.generate().contains("#EXT-X-PROGRAM-DATE-TIME:"))
    }

    // MARK: - Discontinuity

    @Test("Discontinuity keyframe produces EXT-X-DISCONTINUITY")
    func discontinuityKeyframe() {
        var gen = IFramePlaylistGenerator()
        gen.addKeyframe(segmentURI: "s0.ts", byteOffset: 0, byteLength: 100, duration: 6.0)
        gen.addKeyframe(
            segmentURI: "s1.ts", byteOffset: 0, byteLength: 100,
            duration: 6.0, isDiscontinuity: true
        )
        #expect(gen.generate().contains("#EXT-X-DISCONTINUITY"))
    }

    // MARK: - From Recorded Segments

    @Test("addFromRecordedSegments creates synthetic keyframes")
    func fromRecordedSegments() {
        var gen = IFramePlaylistGenerator()
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "seg0.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 10000
            ),
            SimultaneousRecorder.RecordedSegment(
                filename: "seg1.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 20000
            )
        ]
        gen.addFromRecordedSegments(segments)
        #expect(gen.keyframeCount == 2)
        #expect(gen.keyframes[0].byteLength == 1000)
        #expect(gen.keyframes[1].byteLength == 2000)
    }

    @Test("keyframeRatio controls synthetic byte sizes")
    func keyframeRatio() {
        var gen = IFramePlaylistGenerator()
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "seg0.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 10000
            )
        ]
        gen.addFromRecordedSegments(segments, keyframeRatio: 0.2)
        #expect(gen.keyframes[0].byteLength == 2000)
    }

    // MARK: - Properties

    @Test("keyframeCount and totalByteSize correct")
    func propertiesCorrect() {
        var gen = IFramePlaylistGenerator()
        gen.addKeyframe(segmentURI: "s0.ts", byteOffset: 0, byteLength: 100, duration: 6.0)
        gen.addKeyframe(segmentURI: "s1.ts", byteOffset: 0, byteLength: 200, duration: 6.0)
        #expect(gen.keyframeCount == 2)
        #expect(gen.totalByteSize == 300)
    }

    @Test("reset clears all keyframes")
    func resetClears() {
        var gen = IFramePlaylistGenerator()
        gen.addKeyframe(segmentURI: "s.ts", byteOffset: 0, byteLength: 100, duration: 6.0)
        gen.reset()
        #expect(gen.keyframeCount == 0)
    }

    // MARK: - Round-Trip

    @Test("Round-trip: generate → parse → validates")
    func roundTrip() throws {
        var gen = IFramePlaylistGenerator()
        gen.addKeyframe(segmentURI: "seg0.ts", byteOffset: 0, byteLength: 1000, duration: 6.006)
        gen.addKeyframe(segmentURI: "seg1.ts", byteOffset: 0, byteLength: 2000, duration: 6.006)
        let playlist = gen.generate()
        let parser = ManifestParser()
        let manifest = try parser.parse(playlist)
        if case .media(let mp) = manifest {
            #expect(mp.iFramesOnly)
            #expect(mp.segments.count == 2)
            #expect(mp.hasEndList)
        } else {
            Issue.record("Expected media playlist")
        }
    }
}
