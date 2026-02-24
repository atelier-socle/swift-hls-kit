// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EXT-X-GAP")
struct GapTests {

    // MARK: - Segment Property

    @Test("Segment: isGap property exists")
    func segmentGapProperty() {
        let segment = Segment(
            duration: 6.0,
            uri: "segment001.ts",
            isGap: true
        )
        #expect(segment.isGap == true)
    }

    @Test("Segment: isGap defaults to false")
    func segmentGapDefaultFalse() {
        let segment = Segment(
            duration: 6.0,
            uri: "segment001.ts"
        )
        #expect(segment.isGap == false)
    }

    // MARK: - Parsing

    @Test("ManifestParser: parses EXT-X-GAP tag")
    func parseGapTag() throws {
        let manifest = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            segment001.ts
            #EXT-X-GAP
            #EXTINF:6.0,
            segment002.ts
            #EXTINF:6.0,
            segment003.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let result = try parser.parse(manifest)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(playlist.segments.count == 3)
        #expect(playlist.segments[0].isGap == false)
        #expect(playlist.segments[1].isGap == true)
        #expect(playlist.segments[2].isGap == false)
    }

    @Test("ManifestParser: multiple gaps")
    func parseMultipleGaps() throws {
        let manifest = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-TARGETDURATION:6
            #EXT-X-GAP
            #EXTINF:6.0,
            gap1.ts
            #EXTINF:6.0,
            normal.ts
            #EXT-X-GAP
            #EXTINF:6.0,
            gap2.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let result = try parser.parse(manifest)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(playlist.segments[0].isGap == true)
        #expect(playlist.segments[1].isGap == false)
        #expect(playlist.segments[2].isGap == true)
    }

    // MARK: - Generation

    @Test("ManifestGenerator: writes EXT-X-GAP for gap segments")
    func generateGapTag() {
        let segments = [
            Segment(duration: 6.0, uri: "segment001.ts", isGap: false),
            Segment(duration: 6.0, uri: "segment002.ts", isGap: true),
            Segment(duration: 6.0, uri: "segment003.ts", isGap: false)
        ]
        let playlist = MediaPlaylist(
            version: .v6,
            targetDuration: 6,
            segments: segments
        )
        let generator = ManifestGenerator()
        let output = generator.generateMedia(playlist)

        #expect(output.contains("#EXT-X-GAP"))
    }

    @Test("ManifestGenerator: omits EXT-X-GAP for non-gap segments")
    func generateWithoutGap() {
        let segments = [
            Segment(duration: 6.0, uri: "segment001.ts", isGap: false),
            Segment(duration: 6.0, uri: "segment002.ts", isGap: false)
        ]
        let playlist = MediaPlaylist(
            version: .v6,
            targetDuration: 6,
            segments: segments
        )
        let generator = ManifestGenerator()
        let output = generator.generateMedia(playlist)

        #expect(!output.contains("#EXT-X-GAP"))
    }

    // MARK: - Round-Trip

    @Test("Gap tag round-trip: parse → generate → parse")
    func gapRoundTrip() throws {
        let original = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            segment001.ts
            #EXT-X-GAP
            #EXTINF:6.0,
            segment002.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let generator = ManifestGenerator()

        let result1 = try parser.parse(original)
        guard case .media(let playlist1) = result1 else {
            Issue.record("Expected media playlist")
            return
        }
        let generated = generator.generateMedia(playlist1)
        let result2 = try parser.parse(generated)
        guard case .media(let playlist2) = result2 else {
            Issue.record("Expected media playlist after round-trip")
            return
        }

        #expect(playlist1.segments[0].isGap == playlist2.segments[0].isGap)
        #expect(playlist1.segments[1].isGap == playlist2.segments[1].isGap)
    }

    // MARK: - Validation

    @Test("HLSValidator: gap segments in VOD playlist")
    func validateGapInVOD() {
        let segments = [
            Segment(duration: 6.0, uri: "segment001.ts", isGap: true)
        ]
        let playlist = MediaPlaylist(
            version: .v6,
            targetDuration: 6,
            segments: segments
        )
        let validator = HLSValidator()
        let report = validator.validate(playlist)
        // Gap in VOD is valid per spec
        #expect(report.isValid)
    }
}
