// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Master Playlist Rules

@Suite("RFC8216Rules — Master Playlist")
struct RFC8216MasterTests {

    @Test("Valid master — no errors")
    func validMaster() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480p/playlist.m3u8"
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        let errors = results.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("No variants — warning")
    func noVariants() {
        let playlist = MasterPlaylist()
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-general-variants"
            })
    }

    @Test("Zero bandwidth — error")
    func zeroBandwidth() {
        let playlist = MasterPlaylist(
            variants: [Variant(bandwidth: 0, uri: "test.m3u8")]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.2-bandwidth"
            })
    }

    @Test("Empty variant URI — error")
    func emptyVariantURI() {
        let playlist = MasterPlaylist(
            variants: [Variant(bandwidth: 1000, uri: "")]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.2-uri"
            })
    }

    @Test("Missing resolution — warning")
    func missingResolution() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "480p/playlist.m3u8"
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.2-resolution"
            })
    }

    @Test("Duplicate NAME in rendition group — error")
    func duplicateRenditionName() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8",
                    audio: "audio"
                )
            ],
            renditions: [
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "English", uri: "en1.m3u8"
                ),
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "English", uri: "en2.m3u8"
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.1-group-id"
            })
    }

    @Test("Multiple DEFAULT=YES in group — warning")
    func multipleDefaults() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8",
                    audio: "audio"
                )
            ],
            renditions: [
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "English", uri: "en.m3u8",
                    isDefault: true
                ),
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "French", uri: "fr.m3u8",
                    isDefault: true
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.1-default"
            })
    }

    @Test("Undefined AUDIO group reference — error")
    func undefinedAudioGroup() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8",
                    audio: "nonexistent"
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.2-audio-ref"
            })
    }

    @Test("Undefined SUBTITLES group reference — error")
    func undefinedSubtitleGroup() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8",
                    subtitles: "nonexistent"
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.2-subtitle-ref"
            })
    }

    @Test("Undefined CC group reference — error")
    func undefinedCCGroup() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8",
                    closedCaptions: .groupId("nonexistent")
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.2-cc-ref"
            })
    }

    @Test("CLOSED-CAPTIONS=NONE — no error")
    func ccNone() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8",
                    closedCaptions: nil
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        let ccErrors = results.filter {
            $0.ruleId == "RFC8216-4.3.4.2-cc-ref"
        }
        #expect(ccErrors.isEmpty)
    }

    @Test("SESSION-DATA both VALUE and URI — error")
    func sessionDataBothValueAndURI() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8"
                )
            ],
            sessionData: [
                SessionData(
                    dataId: "com.example",
                    value: "val",
                    uri: "data.json"
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.5-session-data-value"
            })
    }

    @Test("SESSION-DATA neither VALUE nor URI — error")
    func sessionDataMissing() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8"
                )
            ],
            sessionData: [
                SessionData(dataId: "com.example")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.5-session-data-value"
            })
    }

    @Test("SESSION-DATA duplicate LANGUAGE — error")
    func sessionDataDuplicateLanguage() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "v.m3u8"
                )
            ],
            sessionData: [
                SessionData(
                    dataId: "com.example",
                    value: "A",
                    language: "en"
                ),
                SessionData(
                    dataId: "com.example",
                    value: "B",
                    language: "en"
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.4.5-session-data-id"
            })
    }
}

// MARK: - Media Playlist Rules

@Suite("RFC8216Rules — Media Playlist")
struct RFC8216MediaTests {

    @Test("Valid media — no errors")
    func validMedia() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            playlistType: .vod,
            hasEndList: true,
            segments: [
                Segment(duration: 9.009, uri: "seg.ts")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        let errors = results.filter { $0.severity == .error }
        #expect(errors.isEmpty)
    }

    @Test("Zero target duration — error")
    func zeroTargetDuration() {
        let playlist = MediaPlaylist(
            targetDuration: 0,
            segments: [
                Segment(duration: 1.0, uri: "seg.ts")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.3.1-integer"
            })
    }

    @Test("Segment exceeds target duration — error")
    func segmentExceedsTarget() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 7.5, uri: "seg.ts")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.3.1-segment-duration"
            })
    }

    @Test("Segment within rounding — no error")
    func segmentWithinRounding() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.006, uri: "seg.ts")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        let durationErrors = results.filter {
            $0.ruleId == "RFC8216-4.3.3.1-segment-duration"
        }
        #expect(durationErrors.isEmpty)
    }

    @Test("Empty segments — warning")
    func emptySegments() {
        let playlist = MediaPlaylist(targetDuration: 10)
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-general-empty"
            })
    }

    @Test("Negative duration — error")
    func negativeDuration() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(duration: -1.0, uri: "seg.ts")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.2.1-extinf"
            })
    }

    @Test("Empty segment URI — error")
    func emptySegmentURI() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(duration: 9.0, uri: "")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.2.1-uri"
            })
    }

    @Test("VOD without ENDLIST — error")
    func vodNoEndList() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            playlistType: .vod,
            hasEndList: false,
            segments: [
                Segment(duration: 9.0, uri: "seg.ts")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.3.5-endlist-vod"
            })
    }

    @Test("KEY without URI — error")
    func keyMissingURI() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(
                    duration: 9.0, uri: "seg.ts",
                    key: EncryptionKey(method: .aes128)
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.2.4-key-uri"
            })
    }

    @Test("KEY IV version < 2 — error")
    func keyIVVersionTooLow() {
        let playlist = MediaPlaylist(
            version: .v1,
            targetDuration: 10,
            segments: [
                Segment(
                    duration: 9.0, uri: "seg.ts",
                    key: EncryptionKey(
                        method: .aes128,
                        uri: "key.bin",
                        iv: "0x01"
                    )
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.2.4-key-iv"
            })
    }

    @Test("BYTERANGE version < 4 — error")
    func byteRangeVersionTooLow() {
        let playlist = MediaPlaylist(
            version: .v3,
            targetDuration: 10,
            segments: [
                Segment(
                    duration: 9.0, uri: "seg.ts",
                    byteRange: ByteRange(length: 1024)
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.2.2-byterange-version"
            })
    }

    @Test("MAP version < 6 — error")
    func mapVersionTooLow() {
        let playlist = MediaPlaylist(
            version: .v5,
            targetDuration: 10,
            segments: [
                Segment(
                    duration: 9.0, uri: "seg.ts",
                    map: MapTag(uri: "init.mp4")
                )
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.3.2.5-map-version"
            })
    }

    @Test("Version mismatch — warning")
    func versionMismatch() {
        let playlist = MediaPlaylist(
            version: .v2,
            targetDuration: 10,
            segments: [
                Segment(duration: 9.009, uri: "seg.ts")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216-4.4.3-version-match"
            })
    }
}
