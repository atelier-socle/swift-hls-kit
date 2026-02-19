// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Validation

@Suite("Manifest Showcase — Validation")
struct ManifestValidationShowcase {

    @Test("Validate valid media playlist — no issues")
    func validateValidMedia() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [
                Segment(duration: 5.5, uri: "seg0.ts"),
                Segment(duration: 6.0, uri: "seg1.ts")
            ]
        )
        let report = HLSValidator().validate(playlist)
        #expect(report.isValid == true)
        #expect(report.errors.isEmpty)
    }

    @Test("Validate segment duration exceeds target — error")
    func segmentExceedsTarget() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [Segment(duration: 8.0, uri: "long.ts")]
        )
        let report = HLSValidator().validate(playlist)
        #expect(report.isValid == false)
        #expect(report.errors.count >= 1)
    }

    @Test("Validate missing CODECS — warning detected")
    func missingCodecs() {
        let playlist = MasterPlaylist(
            variants: [Variant(bandwidth: 1_000_000, uri: "video.m3u8")]
        )
        let report = HLSValidator().validate(playlist)
        #expect(report.warnings.count >= 1)
    }

    @Test("Validation report — error, warning, info severity levels")
    func severityLevels() {
        let results = [
            ValidationResult(severity: .error, message: "Missing tag", field: "header"),
            ValidationResult(severity: .warning, message: "Recommend version", field: "version"),
            ValidationResult(severity: .info, message: "Info note", field: "general")
        ]
        let report = ValidationReport(results: results)
        #expect(report.isValid == false)
        #expect(report.errors.count == 1)
        #expect(report.warnings.count == 1)
        #expect(report.infos.count == 1)
    }

    @Test("Validate string — parse + validate in one call")
    func validateString() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg.ts
            #EXT-X-ENDLIST
            """
        let report = try HLSValidator().validateString(m3u8)
        #expect(report.isValid == true)
    }
}

// MARK: - Round-trip

@Suite("Manifest Showcase — Round-trip")
struct ManifestRoundTripShowcase {

    @Test("Parse → generate → parse — master playlist preserves variants")
    func roundTripMaster() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
            360p.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
            720p.m3u8
            """
        let parser = ManifestParser()
        let generator = ManifestGenerator()

        let manifest1 = try parser.parse(m3u8)
        let output = generator.generate(manifest1)
        let manifest2 = try parser.parse(output)

        guard case .master(let p1) = manifest1,
            case .master(let p2) = manifest2
        else {
            Issue.record("Expected .master")
            return
        }
        #expect(p1.variants.count == p2.variants.count)
        #expect(p1.variants[0].bandwidth == p2.variants[0].bandwidth)
        #expect(p1.variants[1].bandwidth == p2.variants[1].bandwidth)
    }

    @Test("Parse → generate → parse — media playlist preserves segments")
    func roundTripMedia() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:6.006,
            segment000.ts
            #EXTINF:5.839,
            segment001.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let generator = ManifestGenerator()

        let manifest1 = try parser.parse(m3u8)
        let output = generator.generate(manifest1)
        let manifest2 = try parser.parse(output)

        guard case .media(let p1) = manifest1,
            case .media(let p2) = manifest2
        else {
            Issue.record("Expected .media")
            return
        }
        #expect(p1.segments.count == p2.segments.count)
        #expect(p1.segments[0].duration == p2.segments[0].duration)
        #expect(p1.segments[0].uri == p2.segments[0].uri)
        #expect(p1.playlistType == p2.playlistType)
    }

    @Test("Parse → modify (add variant) → generate — modification preserved")
    func modifyAndGenerate() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p.m3u8
            """
        let parser = ManifestParser()
        guard case .master(var playlist) = try parser.parse(m3u8) else {
            Issue.record("Expected .master")
            return
        }

        playlist.variants.append(
            Variant(bandwidth: 2_800_000, resolution: .p720, uri: "720p.m3u8")
        )

        let output = ManifestGenerator().generateMaster(playlist)
        #expect(output.contains("480p.m3u8"))
        #expect(output.contains("720p.m3u8"))
        #expect(output.contains("BANDWIDTH=2800000"))
    }
}
