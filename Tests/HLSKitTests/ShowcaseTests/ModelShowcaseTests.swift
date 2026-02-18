// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Resolution Tests

@Suite("Resolution Model")
struct ResolutionTests {

    @Test("Resolution preset p480 is 854x480")
    func p480Preset() {
        let resolution = Resolution.p480
        #expect(resolution.width == 854)
        #expect(resolution.height == 480)
    }

    @Test("Resolution preset p720 is 1280x720")
    func p720Preset() {
        let resolution = Resolution.p720
        #expect(resolution.width == 1280)
        #expect(resolution.height == 720)
    }

    @Test("Resolution preset p1080 is 1920x1080")
    func p1080Preset() {
        let resolution = Resolution.p1080
        #expect(resolution.width == 1920)
        #expect(resolution.height == 1080)
    }

    @Test("Resolution preset p1440 is 2560x1440")
    func p1440Preset() {
        let resolution = Resolution.p1440
        #expect(resolution.width == 2560)
        #expect(resolution.height == 1440)
    }

    @Test("Resolution preset p2160 is 3840x2160")
    func p2160Preset() {
        let resolution = Resolution.p2160
        #expect(resolution.width == 3840)
        #expect(resolution.height == 2160)
    }

    @Test("Resolution custom dimensions")
    func customResolution() {
        let resolution = Resolution(width: 640, height: 360)
        #expect(resolution.width == 640)
        #expect(resolution.height == 360)
    }

    @Test("Resolution description format")
    func descriptionFormat() {
        let resolution = Resolution.p1080
        #expect(resolution.description == "1920x1080")
    }

    @Test("Resolution equality")
    func equality() {
        let a = Resolution(width: 1920, height: 1080)
        let b = Resolution.p1080
        #expect(a == b)
    }

    @Test("Resolution hashing")
    func hashing() {
        let a = Resolution.p720
        let b = Resolution(width: 1280, height: 720)
        #expect(a.hashValue == b.hashValue)
    }
}

// MARK: - HLSVersion Tests

@Suite("HLSVersion Enum")
struct HLSVersionTests {

    @Test("All HLS versions have correct raw values")
    func rawValues() {
        #expect(HLSVersion.v1.rawValue == 1)
        #expect(HLSVersion.v2.rawValue == 2)
        #expect(HLSVersion.v3.rawValue == 3)
        #expect(HLSVersion.v4.rawValue == 4)
        #expect(HLSVersion.v5.rawValue == 5)
        #expect(HLSVersion.v6.rawValue == 6)
        #expect(HLSVersion.v7.rawValue == 7)
        #expect(HLSVersion.v8.rawValue == 8)
        #expect(HLSVersion.v9.rawValue == 9)
        #expect(HLSVersion.v10.rawValue == 10)
    }

    @Test("HLSVersion count is 10")
    func allCases() {
        #expect(HLSVersion.allCases.count == 10)
    }

    @Test("HLSVersion is comparable")
    func comparable() {
        #expect(HLSVersion.v3 < HLSVersion.v7)
        #expect(HLSVersion.v7 > HLSVersion.v3)
        #expect(HLSVersion.v5 >= HLSVersion.v5)
    }
}

// MARK: - PlaylistType Tests

@Suite("PlaylistType Enum")
struct PlaylistTypeTests {

    @Test("VOD raw value")
    func vodRawValue() {
        #expect(PlaylistType.vod.rawValue == "VOD")
    }

    @Test("EVENT raw value")
    func eventRawValue() {
        #expect(PlaylistType.event.rawValue == "EVENT")
    }

    @Test("PlaylistType has 2 cases")
    func allCases() {
        #expect(PlaylistType.allCases.count == 2)
    }
}

// MARK: - MediaType Tests

@Suite("MediaType Enum")
struct MediaTypeTests {

    @Test("All media types have correct raw values")
    func rawValues() {
        #expect(MediaType.audio.rawValue == "AUDIO")
        #expect(MediaType.video.rawValue == "VIDEO")
        #expect(MediaType.subtitles.rawValue == "SUBTITLES")
        #expect(MediaType.closedCaptions.rawValue == "CLOSED-CAPTIONS")
    }

    @Test("MediaType has 4 cases")
    func allCases() {
        #expect(MediaType.allCases.count == 4)
    }
}

// MARK: - EncryptionMethod Tests

@Suite("EncryptionMethod Enum")
struct EncryptionMethodTests {

    @Test("All encryption methods have correct raw values")
    func rawValues() {
        #expect(EncryptionMethod.none.rawValue == "NONE")
        #expect(EncryptionMethod.aes128.rawValue == "AES-128")
        #expect(EncryptionMethod.sampleAES.rawValue == "SAMPLE-AES")
        #expect(EncryptionMethod.sampleAESCTR.rawValue == "SAMPLE-AES-CTR")
    }

    @Test("EncryptionMethod has 4 cases")
    func allCases() {
        #expect(EncryptionMethod.allCases.count == 4)
    }
}

// MARK: - HLSTag Tests

@Suite("HLSTag Enum")
struct HLSTagTests {

    @Test("HLSTag covers all RFC 8216 tags")
    func allCasesCount() {
        // 2 basic + 9 segment + 12 media playlist + 6 master + 3 universal = 32
        #expect(HLSTag.allCases.count == 32)
    }

    @Test("Basic tag raw values")
    func basicTags() {
        #expect(HLSTag.extm3u.rawValue == "EXTM3U")
        #expect(HLSTag.extXVersion.rawValue == "EXT-X-VERSION")
    }

    @Test("Media segment tag raw values")
    func mediaSegmentTags() {
        #expect(HLSTag.extinf.rawValue == "EXTINF")
        #expect(HLSTag.extXByterange.rawValue == "EXT-X-BYTERANGE")
        #expect(HLSTag.extXDiscontinuity.rawValue == "EXT-X-DISCONTINUITY")
        #expect(HLSTag.extXKey.rawValue == "EXT-X-KEY")
        #expect(HLSTag.extXMap.rawValue == "EXT-X-MAP")
        #expect(HLSTag.extXProgramDateTime.rawValue == "EXT-X-PROGRAM-DATE-TIME")
        #expect(HLSTag.extXGap.rawValue == "EXT-X-GAP")
        #expect(HLSTag.extXBitrate.rawValue == "EXT-X-BITRATE")
        #expect(HLSTag.extXDaterange.rawValue == "EXT-X-DATERANGE")
    }

    @Test("Master playlist tag raw values")
    func masterPlaylistTags() {
        #expect(HLSTag.extXMedia.rawValue == "EXT-X-MEDIA")
        #expect(HLSTag.extXStreamInf.rawValue == "EXT-X-STREAM-INF")
        #expect(HLSTag.extXIFrameStreamInf.rawValue == "EXT-X-I-FRAME-STREAM-INF")
        #expect(HLSTag.extXSessionData.rawValue == "EXT-X-SESSION-DATA")
        #expect(HLSTag.extXSessionKey.rawValue == "EXT-X-SESSION-KEY")
        #expect(HLSTag.extXContentSteering.rawValue == "EXT-X-CONTENT-STEERING")
    }
}

// MARK: - Segment Tests

@Suite("Segment Model")
struct SegmentTests {

    @Test("Segment with all fields")
    func fullSegment() {
        let segment = Segment(
            duration: 6.006,
            uri: "segment001.ts",
            title: "Intro",
            byteRange: ByteRange(length: 1024, offset: 0),
            key: EncryptionKey(method: .aes128, uri: "key.bin"),
            map: MapTag(uri: "init.mp4"),
            discontinuity: true,
            isGap: false,
            bitrate: 800_000
        )

        #expect(segment.duration == 6.006)
        #expect(segment.uri == "segment001.ts")
        #expect(segment.title == "Intro")
        #expect(segment.byteRange?.length == 1024)
        #expect(segment.byteRange?.offset == 0)
        #expect(segment.key?.method == .aes128)
        #expect(segment.map?.uri == "init.mp4")
        #expect(segment.discontinuity == true)
        #expect(segment.isGap == false)
        #expect(segment.bitrate == 800_000)
    }

    @Test("Segment with minimal fields")
    func minimalSegment() {
        let segment = Segment(duration: 10.0, uri: "seg.ts")
        #expect(segment.duration == 10.0)
        #expect(segment.uri == "seg.ts")
        #expect(segment.title == nil)
        #expect(segment.byteRange == nil)
        #expect(segment.key == nil)
        #expect(segment.map == nil)
        #expect(segment.discontinuity == false)
        #expect(segment.isGap == false)
        #expect(segment.bitrate == nil)
    }
}

// MARK: - Variant Tests

@Suite("Variant Model")
struct VariantTests {

    @Test("Variant with all fields")
    func fullVariant() {
        let variant = Variant(
            bandwidth: 2_800_000,
            resolution: .p720,
            uri: "720p/playlist.m3u8",
            averageBandwidth: 2_500_000,
            codecs: "avc1.4d401f,mp4a.40.2",
            frameRate: 30.0,
            hdcpLevel: HDCPLevel.none,
            audio: "audio-group",
            video: "video-group",
            subtitles: "subs",
            closedCaptions: .groupId("cc")
        )

        #expect(variant.bandwidth == 2_800_000)
        #expect(variant.resolution == .p720)
        #expect(variant.uri == "720p/playlist.m3u8")
        #expect(variant.averageBandwidth == 2_500_000)
        #expect(variant.codecs == "avc1.4d401f,mp4a.40.2")
        #expect(variant.frameRate == 30.0)
        #expect(variant.hdcpLevel == HDCPLevel.none)
        #expect(variant.audio == "audio-group")
    }

    @Test("Variant with minimal fields")
    func minimalVariant() {
        let variant = Variant(bandwidth: 800_000, uri: "480p/playlist.m3u8")
        #expect(variant.bandwidth == 800_000)
        #expect(variant.uri == "480p/playlist.m3u8")
        #expect(variant.resolution == nil)
        #expect(variant.codecs == nil)
    }
}

// MARK: - Rendition Tests

@Suite("Rendition Model")
struct RenditionTests {

    @Test("Audio rendition with all fields")
    func audioRendition() {
        let rendition = Rendition(
            type: .audio,
            groupId: "audio-en",
            name: "English",
            uri: "audio/en/playlist.m3u8",
            language: "en",
            isDefault: true,
            autoselect: true,
            channels: "2"
        )

        #expect(rendition.type == .audio)
        #expect(rendition.groupId == "audio-en")
        #expect(rendition.name == "English")
        #expect(rendition.language == "en")
        #expect(rendition.isDefault == true)
        #expect(rendition.autoselect == true)
        #expect(rendition.channels == "2")
    }
}

// MARK: - MasterPlaylist Tests

@Suite("MasterPlaylist Model")
struct MasterPlaylistTests {

    @Test("MasterPlaylist with variants")
    func masterWithVariants() {
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(bandwidth: 800_000, resolution: .p480, uri: "480p/playlist.m3u8"),
                Variant(bandwidth: 2_800_000, resolution: .p720, uri: "720p/playlist.m3u8"),
                Variant(bandwidth: 5_000_000, resolution: .p1080, uri: "1080p/playlist.m3u8")
            ],
            independentSegments: true
        )

        #expect(playlist.version == .v7)
        #expect(playlist.variants.count == 3)
        #expect(playlist.independentSegments == true)
    }

    @Test("Empty master playlist")
    func emptyMaster() {
        let playlist = MasterPlaylist()
        #expect(playlist.variants.isEmpty)
        #expect(playlist.renditions.isEmpty)
        #expect(playlist.sessionData.isEmpty)
        #expect(playlist.version == nil)
    }
}

// MARK: - MediaPlaylist Tests

@Suite("MediaPlaylist Model")
struct MediaPlaylistTests {

    @Test("MediaPlaylist with segments")
    func mediaWithSegments() {
        let playlist = MediaPlaylist(
            version: .v3,
            targetDuration: 10,
            playlistType: .vod,
            hasEndList: true,
            segments: [
                Segment(duration: 9.009, uri: "segment001.ts"),
                Segment(duration: 9.009, uri: "segment002.ts"),
                Segment(duration: 3.003, uri: "segment003.ts")
            ]
        )

        #expect(playlist.version == .v3)
        #expect(playlist.targetDuration == 10)
        #expect(playlist.playlistType == .vod)
        #expect(playlist.hasEndList == true)
        #expect(playlist.segments.count == 3)
    }

    @Test("Default media playlist values")
    func defaultValues() {
        let playlist = MediaPlaylist()
        #expect(playlist.targetDuration == 10)
        #expect(playlist.mediaSequence == 0)
        #expect(playlist.discontinuitySequence == 0)
        #expect(playlist.playlistType == nil)
        #expect(playlist.hasEndList == false)
        #expect(playlist.segments.isEmpty)
    }
}

// MARK: - DateRange Tests

@Suite("DateRange Model")
struct DateRangeTests {

    @Test("DateRange with all fields")
    func fullDateRange() {
        let now = Date()
        let dateRange = DateRange(
            id: "ad-break-1",
            startDate: now,
            classAttribute: "com.example.ad",
            duration: 30.0,
            plannedDuration: 30.0,
            clientAttributes: ["X-COM-EXAMPLE-AD-ID": "12345"]
        )

        #expect(dateRange.id == "ad-break-1")
        #expect(dateRange.startDate == now)
        #expect(dateRange.classAttribute == "com.example.ad")
        #expect(dateRange.duration == 30.0)
        #expect(dateRange.clientAttributes["X-COM-EXAMPLE-AD-ID"] == "12345")
    }
}

// MARK: - SessionData Tests

@Suite("SessionData Model")
struct SessionDataTests {

    @Test("SessionData with inline value")
    func inlineValue() {
        let data = SessionData(
            dataId: "com.example.title",
            value: "My Podcast",
            language: "en"
        )

        #expect(data.dataId == "com.example.title")
        #expect(data.value == "My Podcast")
        #expect(data.uri == nil)
        #expect(data.language == "en")
    }

    @Test("SessionData with URI")
    func uriValue() {
        let data = SessionData(
            dataId: "com.example.metadata",
            uri: "metadata.json"
        )

        #expect(data.value == nil)
        #expect(data.uri == "metadata.json")
    }
}

// MARK: - ContentSteering Tests

@Suite("ContentSteering Model")
struct ContentSteeringTests {

    @Test("ContentSteering with pathway")
    func withPathway() {
        let steering = ContentSteering(
            serverUri: "https://cdn.example.com/steering",
            pathwayId: "CDN-A"
        )

        #expect(steering.serverUri == "https://cdn.example.com/steering")
        #expect(steering.pathwayId == "CDN-A")
    }
}

// MARK: - HDCPLevel Tests

@Suite("HDCPLevel Enum")
struct HDCPLevelTests {

    @Test("All HDCP levels have correct raw values")
    func rawValues() {
        #expect(HDCPLevel.type0.rawValue == "TYPE-0")
        #expect(HDCPLevel.type1.rawValue == "TYPE-1")
        #expect(HDCPLevel.none.rawValue == "NONE")
    }

    @Test("HDCPLevel has 3 cases")
    func allCases() {
        #expect(HDCPLevel.allCases.count == 3)
    }
}

// MARK: - ClosedCaptionsValue Tests

@Suite("ClosedCaptionsValue Enum")
struct ClosedCaptionsValueTests {

    @Test("ClosedCaptionsValue group ID")
    func groupId() {
        let value = ClosedCaptionsValue.groupId("cc")
        if case .groupId(let id) = value {
            #expect(id == "cc")
        } else {
            Issue.record("Expected groupId case")
        }
    }

    @Test("ClosedCaptionsValue none")
    func noneCase() {
        let value = ClosedCaptionsValue.none
        if case .none = value {
            // Pass
        } else {
            Issue.record("Expected none case")
        }
    }
}
