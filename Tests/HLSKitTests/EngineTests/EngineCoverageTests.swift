// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HLSEngine — Coverage")
struct EngineCoverageTests {

    private let engine = HLSEngine()

    // MARK: - generate(_ manifest:)

    @Test("generate(Manifest) delegates to generator for media manifest")
    func generateManifestMedia() {
        let media = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [Segment(duration: 6.0, uri: "seg0.ts")]
        )
        let output = engine.generate(Manifest.media(media))
        #expect(output.contains("#EXTM3U"))
        #expect(output.contains("#EXT-X-TARGETDURATION:6"))
        #expect(output.contains("seg0.ts"))
    }

    @Test("generate(Manifest) delegates to generator for master manifest")
    func generateManifestMaster() {
        let master = MasterPlaylist(
            variants: [Variant(bandwidth: 800_000, uri: "low.m3u8")]
        )
        let output = engine.generate(Manifest.master(master))
        #expect(output.contains("#EXTM3U"))
        #expect(output.contains("BANDWIDTH=800000"))
        #expect(output.contains("low.m3u8"))
    }

    // MARK: - validate(_ manifest:, ruleSet:)

    @Test("validate(Manifest) returns a report")
    func validateManifest() {
        let media = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [Segment(duration: 6.0, uri: "seg0.ts")]
        )
        let report = engine.validate(
            Manifest.media(media),
            ruleSet: .rfc8216
        )
        #expect(report.ruleSet == .rfc8216)
    }

    @Test("validate(Manifest) with default ruleSet uses .all")
    func validateManifestDefaultRuleSet() {
        let master = MasterPlaylist(
            variants: [Variant(bandwidth: 1_000_000, uri: "v.m3u8")]
        )
        let report = engine.validate(Manifest.master(master))
        #expect(report.ruleSet == .all)
    }

    // MARK: - validate(_ playlist: MediaPlaylist, ruleSet:)

    @Test("validate(MediaPlaylist) returns a report")
    func validateMediaPlaylist() {
        let media = MediaPlaylist(
            targetDuration: 10,
            hasEndList: true,
            segments: [Segment(duration: 9.5, uri: "seg.ts")]
        )
        let report = engine.validate(media, ruleSet: .appleHLS)
        #expect(report.ruleSet == .appleHLS)
    }

    @Test("validate(MediaPlaylist) with default ruleSet uses .all")
    func validateMediaPlaylistDefaultRuleSet() {
        let media = MediaPlaylist(
            targetDuration: 10,
            hasEndList: true,
            segments: [Segment(duration: 9.5, uri: "seg.ts")]
        )
        let report = engine.validate(media)
        #expect(report.ruleSet == .all)
    }

    // MARK: - validateString(_:, ruleSet:)

    @Test("validateString parses and validates an M3U8 string")
    func validateStringBasic() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg0.ts
            #EXT-X-ENDLIST
            """
        let report = try engine.validateString(m3u8, ruleSet: .rfc8216)
        #expect(report.ruleSet == .rfc8216)
    }

    @Test("validateString with default ruleSet uses .all")
    func validateStringDefaultRuleSet() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg0.ts
            #EXT-X-ENDLIST
            """
        let report = try engine.validateString(m3u8)
        #expect(report.ruleSet == .all)
    }

    @Test("validateString throws ParserError for invalid input")
    func validateStringThrowsOnInvalid() {
        #expect(throws: ParserError.self) {
            try engine.validateString("")
        }
    }
}
