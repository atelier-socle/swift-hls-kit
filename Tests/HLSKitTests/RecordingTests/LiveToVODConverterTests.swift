// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LiveToVODConverter", .timeLimit(.minutes(1)))
struct LiveToVODConverterTests {

    private let converter = LiveToVODConverter()

    private func makeSegments(
        count: Int,
        duration: TimeInterval = 6.006,
        prefix: String = "seg"
    ) -> [SimultaneousRecorder.RecordedSegment] {
        (0..<count).map { i in
            SimultaneousRecorder.RecordedSegment(
                filename: "\(prefix)\(i).ts",
                duration: duration,
                isDiscontinuity: false,
                programDateTime: nil,
                byteSize: 1024
            )
        }
    }

    // MARK: - Basic Conversion

    @Test("Empty segments produces valid empty playlist with ENDLIST")
    func emptySegments() {
        let result = converter.convert(segments: [])
        #expect(result.contains("#EXTM3U"))
        #expect(result.contains("#EXT-X-ENDLIST"))
        #expect(result.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
    }

    @Test("Single segment produces valid VOD")
    func singleSegment() {
        let segments = makeSegments(count: 1)
        let result = converter.convert(segments: segments)
        #expect(result.contains("#EXTINF:6.006,"))
        #expect(result.contains("seg0.ts"))
        #expect(result.contains("#EXT-X-ENDLIST"))
    }

    @Test("Multiple segments all in order")
    func multipleSegments() {
        let segments = makeSegments(count: 5)
        let result = converter.convert(segments: segments)
        for i in 0..<5 {
            #expect(result.contains("seg\(i).ts"))
        }
    }

    // MARK: - Target Duration

    @Test("targetDuration is ceil of max segment duration")
    func targetDurationCeil() {
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "s0.ts", duration: 5.5,
                isDiscontinuity: false, programDateTime: nil, byteSize: 100
            ),
            SimultaneousRecorder.RecordedSegment(
                filename: "s1.ts", duration: 6.8,
                isDiscontinuity: false, programDateTime: nil, byteSize: 100
            )
        ]
        let target = converter.calculateTargetDuration(from: segments)
        #expect(target == 7)
    }

    // MARK: - Total Duration

    @Test("totalDuration is sum of all durations")
    func totalDurationSum() {
        let segments = makeSegments(count: 3, duration: 6.0)
        let total = converter.calculateTotalDuration(from: segments)
        #expect(abs(total - 18.0) < 0.001)
    }

    // MARK: - Renumber Segments

    @Test("renumberSegments true changes filenames")
    func renumberSegments() {
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "live42.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 100
            ),
            SimultaneousRecorder.RecordedSegment(
                filename: "live43.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 100
            )
        ]
        let result = converter.convert(
            segments: segments,
            options: .init(renumberSegments: true)
        )
        #expect(result.contains("seg0.ts"))
        #expect(result.contains("seg1.ts"))
        #expect(!result.contains("live42"))
    }

    @Test("renumberSegments false preserves original filenames")
    func preserveFilenames() {
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "live42.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 100
            )
        ]
        let result = converter.convert(
            segments: segments,
            options: .init(renumberSegments: false)
        )
        #expect(result.contains("live42.ts"))
    }

    // MARK: - Date-Time

    @Test("includeDateTime adds PROGRAM-DATE-TIME tags")
    func includeDateTimeTags() {
        let refDate = Date(timeIntervalSince1970: 1_740_000_000)
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "seg0.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: refDate, byteSize: 100
            )
        ]
        let result = converter.convert(
            segments: segments,
            options: .init(includeDateTime: true)
        )
        #expect(result.contains("#EXT-X-PROGRAM-DATE-TIME:"))
    }

    // MARK: - Discontinuities

    @Test("preserveDiscontinuities true keeps markers")
    func preserveDiscontinuities() {
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "seg0.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 100
            ),
            SimultaneousRecorder.RecordedSegment(
                filename: "seg1.ts", duration: 6.0,
                isDiscontinuity: true, programDateTime: nil, byteSize: 100
            )
        ]
        let result = converter.convert(
            segments: segments,
            options: .init(preserveDiscontinuities: true)
        )
        #expect(result.contains("#EXT-X-DISCONTINUITY"))
    }

    @Test("preserveDiscontinuities false removes markers")
    func removeDiscontinuities() {
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "seg0.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 100
            ),
            SimultaneousRecorder.RecordedSegment(
                filename: "seg1.ts", duration: 6.0,
                isDiscontinuity: true, programDateTime: nil, byteSize: 100
            )
        ]
        let result = converter.convert(
            segments: segments,
            options: .init(preserveDiscontinuities: false)
        )
        #expect(!result.contains("#EXT-X-DISCONTINUITY"))
    }

    // MARK: - Filename Template

    @Test("filenameTemplate replaces {index}")
    func filenameTemplate() {
        let segments = makeSegments(count: 2)
        let result = converter.convert(
            segments: segments,
            options: .init(filenameTemplate: "ep42-{index}.ts")
        )
        #expect(result.contains("ep42-0.ts"))
        #expect(result.contains("ep42-1.ts"))
    }

    // MARK: - Init Segment

    @Test("initSegmentFilename adds EXT-X-MAP tag")
    func initSegmentMap() {
        let segments = makeSegments(count: 1)
        let result = converter.convert(
            segments: segments,
            options: .init(initSegmentFilename: "init.mp4")
        )
        #expect(result.contains("#EXT-X-MAP:URI=\"init.mp4\""))
    }

    // MARK: - Presets

    @Test("Options.standard defaults")
    func standardOptions() {
        let opts = LiveToVODConverter.Options.standard
        #expect(!opts.renumberSegments)
        #expect(!opts.includeDateTime)
        #expect(opts.preserveDiscontinuities)
        #expect(opts.version == 7)
    }

    @Test("Options.podcast preset")
    func podcastOptions() {
        let opts = LiveToVODConverter.Options.podcast
        #expect(opts.renumberSegments)
        #expect(!opts.includeDateTime)
        #expect(!opts.preserveDiscontinuities)
    }

    @Test("Options.archive preset")
    func archiveOptions() {
        let opts = LiveToVODConverter.Options.archive
        #expect(!opts.renumberSegments)
        #expect(opts.includeDateTime)
        #expect(opts.preserveDiscontinuities)
    }
}
