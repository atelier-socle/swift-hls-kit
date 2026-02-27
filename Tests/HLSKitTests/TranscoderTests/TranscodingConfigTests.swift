// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("TranscodingConfig")
struct TranscodingConfigTests {

    // MARK: - Default Values

    @Test("Default config values")
    func defaultValues() {
        let config = TranscodingConfig()
        #expect(config.videoCodec == .h264)
        #expect(config.audioCodec == .aac)
        #expect(
            config.containerFormat == .fragmentedMP4
        )
        #expect(config.segmentDuration == 6.0)
        #expect(config.generatePlaylist)
        #expect(config.playlistType == .vod)
        #expect(config.includeAudio)
        #expect(config.audioPassthrough)
        #expect(config.hardwareAcceleration)
        #expect(config.preferFastPath)
        #expect(!config.twoPass)
        #expect(config.metadata.isEmpty)
    }

    // MARK: - Custom Values

    @Test("Custom config values")
    func customValues() {
        let config = TranscodingConfig(
            videoCodec: .h265,
            audioCodec: .heAAC,
            containerFormat: .mpegTS,
            segmentDuration: 4.0,
            generatePlaylist: false,
            playlistType: .event,
            includeAudio: false,
            audioPassthrough: false,
            hardwareAcceleration: false,
            preferFastPath: false,
            twoPass: true,
            metadata: ["title": "Test"]
        )
        #expect(config.videoCodec == .h265)
        #expect(config.audioCodec == .heAAC)
        #expect(config.containerFormat == .mpegTS)
        #expect(config.segmentDuration == 4.0)
        #expect(!config.generatePlaylist)
        #expect(config.playlistType == .event)
        #expect(!config.includeAudio)
        #expect(!config.audioPassthrough)
        #expect(!config.hardwareAcceleration)
        #expect(!config.preferFastPath)
        #expect(config.twoPass)
        #expect(config.metadata["title"] == "Test")
    }

    // MARK: - Hashable

    @Test("Hashable conformance")
    func hashable() {
        let c1 = TranscodingConfig()
        let c2 = TranscodingConfig()
        #expect(c1 == c2)
        #expect(c1.hashValue == c2.hashValue)
    }

    @Test("Different configs are not equal")
    func notEqual() {
        let c1 = TranscodingConfig(videoCodec: .h264)
        let c2 = TranscodingConfig(videoCodec: .h265)
        #expect(c1 != c2)
    }

    // MARK: - OutputVideoCodec

    @Test("OutputVideoCodec: all cases")
    func outputVideoCodecCases() {
        let cases = OutputVideoCodec.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.h264))
        #expect(cases.contains(.h265))
        #expect(cases.contains(.vp9))
        #expect(cases.contains(.av1))
    }

    @Test("OutputVideoCodec raw values")
    func outputVideoCodecRawValues() {
        #expect(OutputVideoCodec.h264.rawValue == "h264")
        #expect(OutputVideoCodec.h265.rawValue == "h265")
    }

    // MARK: - OutputAudioCodec

    @Test("OutputAudioCodec: all cases")
    func outputAudioCodecCases() {
        let cases = OutputAudioCodec.allCases
        #expect(cases.count == 5)
        #expect(cases.contains(.aac))
        #expect(cases.contains(.heAAC))
        #expect(cases.contains(.heAACv2))
        #expect(cases.contains(.flac))
        #expect(cases.contains(.opus))
    }

    @Test("OutputAudioCodec raw values")
    func outputAudioCodecRawValues() {
        #expect(OutputAudioCodec.aac.rawValue == "aac")
        #expect(OutputAudioCodec.heAAC.rawValue == "heAAC")
    }
}
