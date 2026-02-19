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
