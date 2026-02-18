// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Master Playlist Generation

@Suite("ManifestGenerator — Master Playlist")
struct ManifestGeneratorMasterTests {

    let generator = ManifestGenerator()

    @Test("Minimal master — one variant")
    func minimalMaster() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "480p/playlist.m3u8"
                )
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(output.hasPrefix("#EXTM3U\n"))
        #expect(output.contains("BANDWIDTH=800000"))
        #expect(output.contains("480p/playlist.m3u8"))
        #expect(output.hasSuffix("\n"))
    }

    @Test("Master with renditions and variants")
    func masterWithRenditions() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 2_800_000,
                    resolution: .p720,
                    uri: "720p/playlist.m3u8",
                    codecs: "avc1.4d401f,mp4a.40.2",
                    audio: "audio-aac"
                )
            ],
            renditions: [
                Rendition(
                    type: .audio, groupId: "audio-aac",
                    name: "English",
                    uri: "audio/en/playlist.m3u8",
                    language: "en",
                    isDefault: true, autoselect: true
                )
            ],
            independentSegments: true
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
        #expect(output.contains("#EXT-X-MEDIA:"))
        #expect(output.contains("TYPE=AUDIO"))
        #expect(output.contains("#EXT-X-STREAM-INF:"))
        #expect(output.contains("720p/playlist.m3u8"))
    }

    @Test("Master with I-frame variants")
    func masterWithIFrames() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000, uri: "480p/playlist.m3u8"
                )
            ],
            iFrameVariants: [
                IFrameVariant(
                    bandwidth: 200_000,
                    uri: "480p/iframe.m3u8",
                    codecs: "avc1.4d401e",
                    resolution: Resolution(width: 640, height: 480)
                )
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("#EXT-X-I-FRAME-STREAM-INF:"))
        #expect(output.contains("URI=\"480p/iframe.m3u8\""))
    }

    @Test("Master with session data and steering")
    func masterWithSessionData() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000, uri: "480p/playlist.m3u8"
                )
            ],
            sessionData: [
                SessionData(
                    dataId: "com.example.title",
                    value: "My Great Show", language: "en"
                )
            ],
            contentSteering: ContentSteering(
                serverUri: "https://example.com/steering",
                pathwayId: "CDN-A"
            )
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("#EXT-X-SESSION-DATA:"))
        #expect(output.contains("#EXT-X-CONTENT-STEERING:"))
    }

    @Test("Master with START and DEFINE")
    func masterWithStartAndDefine() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000, uri: "480p/playlist.m3u8"
                )
            ],
            independentSegments: false,
            startOffset: StartOffset(timeOffset: 10.5),
            definitions: [
                VariableDefinition(
                    name: "base-url",
                    value: "https://cdn.example.com"
                )
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("#EXT-X-START:"))
        #expect(output.contains("#EXT-X-DEFINE:"))
    }
}

// MARK: - Media Playlist Generation

@Suite("ManifestGenerator — Media Playlist")
struct ManifestGeneratorMediaTests {

    let generator = ManifestGenerator()

    @Test("Minimal VOD playlist")
    func minimalVOD() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            playlistType: .vod,
            hasEndList: true,
            segments: [
                Segment(duration: 9.009, uri: "segment001.ts")
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.hasPrefix("#EXTM3U\n"))
        #expect(output.contains("#EXT-X-TARGETDURATION:10"))
        #expect(output.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        #expect(output.contains("#EXTINF:"))
        #expect(output.contains("segment001.ts"))
        #expect(output.contains("#EXT-X-ENDLIST"))
    }

    @Test("Media with encryption — KEY deduplication")
    func mediaWithEncryption() {
        let key = EncryptionKey(
            method: .aes128, uri: "https://example.com/key"
        )
        let playlist = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [
                Segment(duration: 6.006, uri: "seg0.ts", key: key),
                Segment(duration: 6.006, uri: "seg1.ts", key: key),
                Segment(duration: 6.006, uri: "seg2.ts", key: key)
            ]
        )
        let output = generator.generateMedia(playlist)
        let keyCount =
            output.components(
                separatedBy: "#EXT-X-KEY:"
            ).count - 1
        #expect(keyCount == 1)
    }

    @Test("Media with MAP — deduplication")
    func mediaWithMap() {
        let map = MapTag(uri: "init.mp4")
        let playlist = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [
                Segment(duration: 6.006, uri: "seg0.ts", map: map),
                Segment(duration: 6.006, uri: "seg1.ts", map: map)
            ]
        )
        let output = generator.generateMedia(playlist)
        let mapCount =
            output.components(
                separatedBy: "#EXT-X-MAP:"
            ).count - 1
        #expect(mapCount == 1)
    }

    @Test("Media with BITRATE changes — deduplication")
    func mediaWithBitrateChanges() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [
                Segment(
                    duration: 6.006, uri: "seg0.ts", bitrate: 1500
                ),
                Segment(
                    duration: 6.006, uri: "seg1.ts", bitrate: 1500
                ),
                Segment(
                    duration: 6.006, uri: "seg2.ts", bitrate: 2000
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        let bitrateCount =
            output.components(
                separatedBy: "#EXT-X-BITRATE:"
            ).count - 1
        #expect(bitrateCount == 2)
    }

    @Test("Media with discontinuity and gap")
    func mediaWithDiscontinuityAndGap() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [
                Segment(duration: 6.006, uri: "seg0.ts"),
                Segment(
                    duration: 6.006, uri: "seg1.ts",
                    discontinuity: true
                ),
                Segment(
                    duration: 6.006, uri: "seg2.ts", isGap: true
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-DISCONTINUITY"))
        #expect(output.contains("#EXT-X-GAP"))
    }

    @Test("Media with byte range segments")
    func mediaWithByteRange() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [
                Segment(
                    duration: 6.006, uri: "seg0.ts",
                    byteRange: ByteRange(length: 1024, offset: 0)
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-BYTERANGE:1024@0"))
    }

    @Test("Media with media sequence > 0")
    func mediaWithSequence() {
        let playlist = MediaPlaylist(
            targetDuration: 4, mediaSequence: 100,
            segments: [
                Segment(duration: 4.0, uri: "seg100.ts")
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-MEDIA-SEQUENCE:100"))
    }

    @Test("Output ends with newline")
    func outputEndsWithNewline() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(duration: 9.009, uri: "segment001.ts")
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.hasSuffix("\n"))
    }
}

// MARK: - LL-HLS Generation

@Suite("ManifestGenerator — LL-HLS")
struct ManifestGeneratorLLHLSTests {

    let generator = ManifestGenerator()

    @Test("LL-HLS live playlist")
    func llhlsLive() {
        let playlist = MediaPlaylist(
            targetDuration: 4, mediaSequence: 100,
            segments: [
                Segment(
                    duration: 4.0, uri: "segment100.mp4",
                    map: MapTag(uri: "init.mp4")
                ),
                Segment(
                    duration: 4.0, uri: "segment101.mp4",
                    map: MapTag(uri: "init.mp4")
                )
            ],
            partTargetDuration: 1.004,
            serverControl: ServerControl(
                canBlockReload: true, canSkipUntil: 24.0,
                partHoldBack: 3.012
            ),
            partialSegments: [
                PartialSegment(
                    uri: "segment102.0.mp4", duration: 1.001
                )
            ],
            preloadHints: [
                PreloadHint(type: .part, uri: "segment103.2.mp4")
            ],
            renditionReports: [
                RenditionReport(
                    uri: "../720p/playlist.m3u8",
                    lastMediaSequence: 103, lastPartIndex: 1
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-SERVER-CONTROL:"))
        #expect(output.contains("#EXT-X-PART-INF:"))
        #expect(output.contains("#EXT-X-PART:"))
        #expect(output.contains("#EXT-X-PRELOAD-HINT:"))
        #expect(output.contains("#EXT-X-RENDITION-REPORT:"))
    }
}

// MARK: - Version Auto-Calculation

@Suite("ManifestGenerator — Version Auto-Calc")
struct ManifestGeneratorVersionTests {

    let generator = ManifestGenerator()

    @Test("Decimal durations trigger v3")
    func decimalDurationsV3() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(duration: 9.009, uri: "seg.ts")
            ]
        )
        let version = generator.calculateMediaVersion(playlist)
        #expect(version >= .v3)
    }

    @Test("Byte-range triggers v4")
    func byteRangeV4() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(
                    duration: 10, uri: "seg.ts",
                    byteRange: ByteRange(length: 1024)
                )
            ]
        )
        let version = generator.calculateMediaVersion(playlist)
        #expect(version >= .v4)
    }

    @Test("MAP in non-I-frame playlist triggers v6")
    func mapV6() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(
                    duration: 10, uri: "seg.ts",
                    map: MapTag(uri: "init.mp4")
                )
            ]
        )
        let version = generator.calculateMediaVersion(playlist)
        #expect(version >= .v6)
    }

    @Test("LL-HLS features trigger v9")
    func llhlsV9() {
        let playlist = MediaPlaylist(
            targetDuration: 4,
            serverControl: ServerControl(canBlockReload: true),
            partialSegments: [
                PartialSegment(uri: "seg.mp4", duration: 1.0)
            ]
        )
        let version = generator.calculateMediaVersion(playlist)
        #expect(version >= .v9)
    }

    @Test("HDCP-LEVEL in master triggers v7")
    func hdcpV7() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 2_800_000,
                    uri: "720p/playlist.m3u8",
                    hdcpLevel: .type0
                )
            ]
        )
        let version = generator.calculateMasterVersion(playlist)
        #expect(version >= .v7)
    }

    @Test("Explicit version is preserved")
    func explicitVersion() {
        let playlist = MediaPlaylist(
            version: .v7, targetDuration: 10,
            segments: [
                Segment(duration: 10.0, uri: "seg.ts")
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-VERSION:7"))
    }
}
