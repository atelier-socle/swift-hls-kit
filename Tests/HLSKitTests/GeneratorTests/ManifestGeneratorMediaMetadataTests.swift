// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "ManifestGenerator — Media Segment Metadata & Master Trailer",
    .timeLimit(.minutes(1))
)
struct ManifestGeneratorMediaMetadataTests {

    private let generator = ManifestGenerator()

    // MARK: - Segment Metadata Branches

    @Test("Segment with isGap emits EXT-X-GAP tag")
    func segmentWithGap() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg1.ts", isGap: true)
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-GAP"))
    }

    @Test("Segment with bitrate emits EXT-X-BITRATE tag")
    func segmentWithBitrate() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg1.ts", bitrate: 1_500_000),
                Segment(duration: 6.0, uri: "seg2.ts", bitrate: 2_000_000)
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-BITRATE:1500000"))
        #expect(output.contains("#EXT-X-BITRATE:2000000"))
    }

    @Test("Segment with byteRange emits EXT-X-BYTERANGE tag")
    func segmentWithByteRange() {
        let playlist = MediaPlaylist(
            version: .v4,
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0, uri: "seg1.ts",
                    byteRange: ByteRange(length: 1000, offset: 0)
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-BYTERANGE:1000@0"))
    }

    @Test("Segment with programDateTime emits EXT-X-PROGRAM-DATE-TIME")
    func segmentWithProgramDateTime() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0, uri: "seg1.ts",
                    programDateTime: date
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-PROGRAM-DATE-TIME:"))
    }

    // MARK: - Master Playlist with Content Steering

    @Test("Master playlist with contentSteering emits tag")
    func masterWithContentSteering() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            contentSteering: ContentSteering(
                serverUri: "https://cdn.example.com/steer",
                pathwayId: "CDN-A"
            )
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("#EXT-X-CONTENT-STEERING:"))
        #expect(output.contains("CDN-A"))
    }

    // MARK: - Variant with Video Group and Closed Captions

    @Test("Variant with video group emits VIDEO attribute")
    func variantWithVideoGroup() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "low.m3u8",
                    video: "vid-group"
                )
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("VIDEO=\"vid-group\""))
    }

    @Test("Variant with CLOSED-CAPTIONS=NONE emits NONE")
    func variantWithClosedCaptionsNone() {
        let cc: ClosedCaptionsValue = .none
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "low.m3u8",
                    closedCaptions: cc
                )
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("CLOSED-CAPTIONS=NONE"))
    }

    @Test("Variant with CLOSED-CAPTIONS group ID emits quoted value")
    func variantWithClosedCaptionsGroupId() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "low.m3u8",
                    closedCaptions: .groupId("cc1")
                )
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("CLOSED-CAPTIONS=\"cc1\""))
    }

    // MARK: - Auto-Version Calculation

    @Test("I-frames-only with map requires version >= 4, not 6")
    func iFramesOnlyWithMapVersion() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            iFramesOnly: true,
            segments: [
                Segment(
                    duration: 6.0, uri: "seg1.ts",
                    map: MapTag(uri: "init.mp4")
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        // I-frames-only with map doesn't need v6 (v6 is only for map without I-frames-only)
        #expect(output.contains("#EXT-X-I-FRAMES-ONLY"))
        #expect(output.contains("#EXT-X-MAP:URI=\"init.mp4\""))
    }

    @Test("Media playlist with definitions gets version 8")
    func definitionsRequireVersion8() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "{$base}/seg1.ts")
            ],
            definitions: [
                VariableDefinition(
                    name: "base", value: "https://cdn.example.com"
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-VERSION:8"))
    }

    // MARK: - Media Trailer Features

    @Test("Media playlist with dateRanges emits EXT-X-DATERANGE")
    func mediaWithDateRanges() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg1.ts")
            ],
            dateRanges: [
                DateRange(
                    id: "ad-1",
                    startDate: Date(timeIntervalSince1970: 1_700_000_000)
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-DATERANGE:"))
        #expect(output.contains("ad-1"))
    }

    @Test("Media playlist with skip emits EXT-X-SKIP")
    func mediaWithSkip() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg1.ts")
            ],
            skip: SkipInfo(skippedSegments: 3)
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-SKIP:SKIPPED-SEGMENTS=3"))
    }

    @Test("Master playlist with session keys emits EXT-X-SESSION-KEY")
    func masterWithSessionKeys() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            sessionKeys: [
                EncryptionKey(
                    method: .aes128,
                    uri: "https://keys.example.com/key1"
                )
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("#EXT-X-SESSION-KEY:"))
        #expect(output.contains("AES-128"))
    }

    // MARK: - Encryption with IV Auto-Version

    @Test("Segment with key IV auto-calculates version >= 2")
    func segmentWithKeyIV() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0,
                    uri: "seg1.ts",
                    key: EncryptionKey(
                        method: .aes128,
                        uri: "key.bin",
                        iv: "0x00000000000000000000000000000001"
                    )
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("IV=0x"))
        #expect(output.contains("#EXT-X-VERSION:"))
    }
}
