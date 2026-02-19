// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - HLSEngine Segmentation (API surface — tiny data only)

@Suite("HLSEngine Showcase — Segmentation")
struct HLSEngineSegmentationShowcase {

    /// Minimal synthetic MP4 (< 1s, 3 samples)
    private func tinyMP4() -> Data {
        MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 3,
            keyframeInterval: 1,
            sampleDelta: 3000,
            timescale: 90000
        )
    }

    @Test("HLSEngine — segment MP4 data to fMP4 HLS")
    func segmentFMP4() throws {
        let engine = HLSEngine()
        let config = SegmentationConfig(containerFormat: .fragmentedMP4)
        let result = try engine.segment(data: tinyMP4(), config: config)

        #expect(result.segmentCount > 0)
        #expect(result.hasInitSegment == true)
        #expect(result.playlist != nil)
    }

    @Test("HLSEngine — segment with byte-range config")
    func segmentByteRange() throws {
        let engine = HLSEngine()
        let config = SegmentationConfig(outputMode: .byteRange)
        let result = try engine.segment(data: tinyMP4(), config: config)

        #expect(result.segmentCount > 0)
    }
}

// MARK: - HLSEngine Encryption (API surface — tiny data)

@Suite("HLSEngine Showcase — Encryption")
struct HLSEngineEncryptionShowcase {

    @Test("HLSEngine — encrypt existing segments")
    func encryptSegments() throws {
        let engine = HLSEngine()
        let tinyMP4 = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 3,
            keyframeInterval: 1,
            sampleDelta: 3000,
            timescale: 90000
        )
        let segResult = try engine.segment(data: tinyMP4)

        let key = try KeyManager().generateKey()
        let keyURL = try #require(URL(string: "https://example.com/key"))
        let config = EncryptionConfig(
            method: .aes128,
            keyURL: keyURL,
            key: key
        )
        let encResult = try engine.encrypt(
            segments: segResult, config: config
        )
        #expect(encResult.segmentCount == segResult.segmentCount)
        #expect(encResult.playlist?.contains("AES-128") == true)
    }
}

// MARK: - HLSEngine Transcoding (API surface only)

@Suite("HLSEngine Showcase — Transcoding")
struct HLSEngineTranscodingShowcase {

    @Test("HLSEngine — isTranscoderAvailable property")
    func transcoderAvailability() {
        let engine = HLSEngine()
        let available = engine.isTranscoderAvailable
        _ = available
    }
}

// MARK: - HLSEngine Manifest Operations

@Suite("HLSEngine Showcase — Manifest Operations")
struct HLSEngineManifestShowcase {

    @Test("HLSEngine — regenerate manifest (parse → generate)")
    func regenerate() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg.ts
            #EXT-X-ENDLIST
            """
        let engine = HLSEngine()
        let output = try engine.regenerate(m3u8)
        #expect(output.contains("#EXTM3U"))
        #expect(output.contains("#EXTINF"))
        #expect(output.contains("seg.ts"))
    }

    @Test("HLSEngine — validate manifest from Manifest enum")
    func validateManifest() throws {
        let engine = HLSEngine()
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg.ts
            #EXT-X-ENDLIST
            """
        let manifest = try engine.parse(m3u8)
        let report = engine.validate(manifest)
        #expect(report.isValid == true)
    }

    @Test("HLSEngine — validate media playlist directly")
    func validateMedia() {
        let engine = HLSEngine()
        let playlist = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [Segment(duration: 5.0, uri: "seg.ts")]
        )
        let report = engine.validate(playlist)
        #expect(report.isValid == true)
    }
}

// MARK: - HLSEngine File Info

@Suite("HLSEngine Showcase — File Info")
struct HLSEngineInfoShowcase {

    @Test("HLSEngine — inspect MP4 data (tracks, codec, duration)")
    func inspectMP4() throws {
        let mp4Data = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 3,
            keyframeInterval: 1,
            sampleDelta: 3000,
            timescale: 90000
        )
        let boxes = try MP4BoxReader().readBoxes(from: mp4Data)
        let fileInfo = try MP4InfoParser().parseFileInfo(from: boxes)

        #expect(fileInfo.timescale > 0)
        #expect(fileInfo.tracks.isEmpty == false)
        #expect(fileInfo.durationSeconds > 0)
    }

    @Test("HLSEngine — inspect M3U8 manifest (type, segments)")
    func inspectManifest() throws {
        let engine = HLSEngine()
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-VERSION:3
            #EXTINF:6.0,
            seg0.ts
            #EXTINF:4.5,
            seg1.ts
            #EXT-X-ENDLIST
            """
        let manifest = try engine.parse(m3u8)
        guard case .media(let playlist) = manifest else {
            Issue.record("Expected .media")
            return
        }
        #expect(playlist.segments.count == 2)
        #expect(playlist.targetDuration == 6)
    }
}
