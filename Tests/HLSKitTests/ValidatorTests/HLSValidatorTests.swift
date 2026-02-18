// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HLSValidator — Integration")
struct HLSValidatorIntegrationTests {

    let validator = HLSValidator()

    // MARK: - Rule Set Dispatch

    @Test("RFC-only rule set — no Apple findings")
    func rfcOnlyRuleSet() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ]
        )
        let report = validator.validate(
            playlist, ruleSet: .rfc8216
        )
        #expect(report.ruleSet == .rfc8216)
        let appleResults = report.results.filter {
            $0.ruleSet == .appleHLS
        }
        #expect(appleResults.isEmpty)
    }

    @Test("Apple-only rule set — no RFC findings")
    func appleOnlyRuleSet() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ]
        )
        let report = validator.validate(
            playlist, ruleSet: .appleHLS
        )
        #expect(report.ruleSet == .appleHLS)
        let rfcResults = report.results.filter {
            $0.ruleSet == .rfc8216
        }
        #expect(rfcResults.isEmpty)
    }

    @Test("All rule set — both RFC and Apple findings")
    func allRuleSet() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ]
        )
        let report = validator.validate(playlist, ruleSet: .all)
        #expect(report.ruleSet == .all)
        #expect(report.results.contains { $0.ruleSet == .rfc8216 })
        #expect(report.results.contains { $0.ruleSet == .appleHLS })
    }

    @Test("Default rule set is .all")
    func defaultRuleSet() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ]
        )
        let report = validator.validate(playlist)
        #expect(report.ruleSet == .all)
    }

    // MARK: - Manifest Type Dispatch

    @Test("Validate master via Manifest enum")
    func validateManifestMaster() {
        let manifest = Manifest.master(
            MasterPlaylist(
                variants: [
                    Variant(
                        bandwidth: 800_000,
                        resolution: .p480,
                        uri: "v.m3u8",
                        codecs: "avc1.4d401f",
                        frameRate: 30.0
                    )
                ]
            ))
        let report = validator.validate(manifest)
        let errors = report.errors
        #expect(errors.isEmpty)
    }

    @Test("Validate media via Manifest enum")
    func validateManifestMedia() {
        let manifest = Manifest.media(
            MediaPlaylist(
                targetDuration: 10,
                playlistType: .vod,
                hasEndList: true,
                segments: [
                    Segment(
                        duration: 9.009, uri: "seg.ts",
                        map: MapTag(uri: "init.mp4")
                    )
                ],
                independentSegments: true
            ))
        let report = validator.validate(manifest)
        let errors = report.errors
        #expect(errors.isEmpty)
    }

    // MARK: - validateString

    @Test("validateString — valid M3U8")
    func validateStringValid() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:10
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:9.009,
            segment001.ts
            #EXT-X-ENDLIST
            """
        let report = try validator.validateString(m3u8)
        let errors = report.errors
        #expect(errors.isEmpty)
    }

    @Test("validateString — invalid M3U8 throws")
    func validateStringInvalid() {
        #expect(throws: ParserError.self) {
            try validator.validateString("not a manifest")
        }
    }

    @Test("validateString with rule set")
    func validateStringWithRuleSet() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXTINF:9.009,
            segment001.ts
            """
        let report = try validator.validateString(
            m3u8, ruleSet: .rfc8216
        )
        #expect(report.ruleSet == .rfc8216)
    }

    // MARK: - Multiple Errors Collected

    @Test("Multiple errors collected — not fail-fast")
    func multipleErrors() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: -1.0, uri: ""),
                Segment(duration: 7.5, uri: "seg.ts")
            ]
        )
        let report = validator.validate(
            playlist, ruleSet: .rfc8216
        )
        #expect(report.errors.count >= 3)
    }

    // MARK: - Valid Playlists

    @Test("Valid master — isValid true, 0 errors")
    func validMaster() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480.m3u8",
                    codecs: "avc1.4d401f",
                    frameRate: 30.0
                ),
                Variant(
                    bandwidth: 2_800_000,
                    resolution: .p720,
                    uri: "720.m3u8",
                    codecs: "avc1.4d401f",
                    frameRate: 30.0
                ),
                Variant(
                    bandwidth: 5_000_000,
                    resolution: .p1080,
                    uri: "1080.m3u8",
                    codecs: "avc1.640028",
                    frameRate: 30.0
                )
            ],
            iFrameVariants: [
                IFrameVariant(
                    bandwidth: 200_000, uri: "iframe.m3u8"
                )
            ],
            renditions: [
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "English", uri: "en.m3u8",
                    language: "en", isDefault: true
                )
            ]
        )
        let report = validator.validate(playlist)
        #expect(report.errors.isEmpty)
    }

    @Test("Valid VOD media — isValid true, 0 errors")
    func validMedia() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            playlistType: .vod,
            hasEndList: true,
            segments: [
                Segment(
                    duration: 6.006, uri: "seg1.mp4",
                    map: MapTag(uri: "init.mp4")
                ),
                Segment(
                    duration: 5.839, uri: "seg2.mp4",
                    map: MapTag(uri: "init.mp4")
                )
            ],
            independentSegments: true
        )
        let report = validator.validate(playlist)
        #expect(report.errors.isEmpty)
    }
}
