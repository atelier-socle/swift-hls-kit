// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Apple Master Playlist Rules

@Suite("AppleHLSRules — Master Playlist")
struct AppleHLSMasterTests {

    @Test("Missing CODECS — warning")
    func missingCodecs() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-2.1-codecs"
            })
    }

    @Test("With CODECS — no codecs warning")
    func withCodecs() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "v.m3u8",
                    codecs: "avc1.4d401f"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let codecResults = results.filter {
            $0.ruleId == "APPLE-2.1-codecs"
        }
        #expect(codecResults.isEmpty)
    }

    @Test("Missing FRAME-RATE for video — warning")
    func missingFrameRate() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p720,
                    uri: "v.m3u8",
                    codecs: "avc1.4d401f"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-2.1-frame-rate"
            })
    }

    @Test("With FRAME-RATE — no warning")
    func withFrameRate() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p720,
                    uri: "v.m3u8",
                    codecs: "avc1.4d401f",
                    frameRate: 30.0
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let frResults = results.filter {
            $0.ruleId == "APPLE-2.1-frame-rate"
        }
        #expect(frResults.isEmpty)
    }

    @Test("No I-frame playlists — info")
    func noIFrames() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-2.2-iframe"
            })
    }

    @Test("With I-frame playlists — no info")
    func withIFrames() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ],
            iFrameVariants: [
                IFrameVariant(
                    bandwidth: 200_000, uri: "iframe.m3u8"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let iframeResults = results.filter {
            $0.ruleId == "APPLE-2.2-iframe"
        }
        #expect(iframeResults.isEmpty)
    }

    @Test("Audio rendition missing LANGUAGE — warning")
    func audioMissingLanguage() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "v.m3u8",
                    audio: "audio"
                )
            ],
            renditions: [
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "Default", uri: "audio.m3u8"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-2.3-audio-group"
            })
    }

    @Test("Audio rendition with LANGUAGE — no warning")
    func audioWithLanguage() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "v.m3u8",
                    audio: "audio"
                )
            ],
            renditions: [
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "English", uri: "audio.m3u8",
                    language: "en"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let langResults = results.filter {
            $0.ruleId == "APPLE-2.3-audio-group"
        }
        #expect(langResults.isEmpty)
    }

    @Test("Insufficient resolution ladder — info")
    func insufficientLadder() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480.m3u8"
                ),
                Variant(
                    bandwidth: 1_500_000,
                    resolution: .p480,
                    uri: "480b.m3u8"
                ),
                Variant(
                    bandwidth: 2_800_000,
                    resolution: .p480,
                    uri: "480c.m3u8"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-2.4-resolution-ladder"
            })
    }

    @Test("Good resolution ladder — no info")
    func goodLadder() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480.m3u8"
                ),
                Variant(
                    bandwidth: 2_800_000,
                    resolution: .p720,
                    uri: "720.m3u8"
                ),
                Variant(
                    bandwidth: 5_000_000,
                    resolution: .p1080,
                    uri: "1080.m3u8"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let ladderResults = results.filter {
            $0.ruleId == "APPLE-2.4-resolution-ladder"
        }
        #expect(ladderResults.isEmpty)
    }

    @Test("Variants not in bandwidth order — info")
    func outOfOrder() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 5_000_000,
                    resolution: .p1080,
                    uri: "1080.m3u8"
                ),
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480.m3u8"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-2.5-bandwidth-order"
            })
    }

    @Test("Variants in bandwidth order — no info")
    func inOrder() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480.m3u8"
                ),
                Variant(
                    bandwidth: 5_000_000,
                    resolution: .p1080,
                    uri: "1080.m3u8"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let orderResults = results.filter {
            $0.ruleId == "APPLE-2.5-bandwidth-order"
        }
        #expect(orderResults.isEmpty)
    }

    @Test("4K without HDCP — info")
    func noHDCP4K() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 15_000_000,
                    resolution: Resolution(width: 3840, height: 2160),
                    uri: "4k.m3u8"
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-2.6-hdcp"
            })
    }

    @Test("4K with HDCP — no info")
    func withHDCP4K() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 15_000_000,
                    resolution: Resolution(width: 3840, height: 2160),
                    uri: "4k.m3u8",
                    hdcpLevel: .type1
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let hdcpResults = results.filter {
            $0.ruleId == "APPLE-2.6-hdcp"
        }
        #expect(hdcpResults.isEmpty)
    }
}

// MARK: - Apple Media Playlist Rules

@Suite("AppleHLSRules — Media Playlist")
struct AppleHLSMediaTests {

    @Test("Non-standard segment durations — info")
    func nonStandardDurations() {
        let playlist = MediaPlaylist(
            targetDuration: 2,
            segments: [
                Segment(duration: 2.0, uri: "seg.ts")
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-3.1-segment-duration"
            })
    }

    @Test("Standard segment durations — no info")
    func standardDurations() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.006, uri: "seg.ts"),
                Segment(duration: 5.839, uri: "seg2.ts")
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let durationResults = results.filter {
            $0.ruleId == "APPLE-3.1-segment-duration"
        }
        #expect(durationResults.isEmpty)
    }

    @Test("Non-standard target duration — info")
    func nonStandardTarget() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-3.2-target-duration"
            })
    }

    @Test("LL-HLS high target duration — info")
    func llhlsHighTarget() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ],
            partTargetDuration: 1.0
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-3.2-target-duration"
            })
    }

    @Test("Missing INDEPENDENT-SEGMENTS — warning")
    func missingIndependent() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-3.5-independent"
            })
    }

    @Test("With INDEPENDENT-SEGMENTS — no warning")
    func withIndependent() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ],
            independentSegments: true
        )
        let results = AppleHLSRules.validate(playlist)
        let indResults = results.filter {
            $0.ruleId == "APPLE-3.5-independent"
        }
        #expect(indResults.isEmpty)
    }

    @Test("No fMP4 (no MAP tags) — info")
    func noFMP4() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "APPLE-3.4-fmp4"
            })
    }

    @Test("With fMP4 (MAP tags) — no info")
    func withFMP4() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0, uri: "seg.mp4",
                    map: MapTag(uri: "init.mp4")
                )
            ]
        )
        let results = AppleHLSRules.validate(playlist)
        let fmp4Results = results.filter {
            $0.ruleId == "APPLE-3.4-fmp4"
        }
        #expect(fmp4Results.isEmpty)
    }
}
