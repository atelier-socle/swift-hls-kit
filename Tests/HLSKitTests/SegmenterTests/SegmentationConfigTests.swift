// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("SegmentationConfig")
struct SegmentationConfigTests {

    // MARK: - Defaults

    @Test("default config values")
    func defaults() {
        let config = SegmentationConfig()
        #expect(config.targetSegmentDuration == 6.0)
        #expect(config.outputMode == .separateFiles)
        #expect(config.segmentNamePattern == "segment_%d.m4s")
        #expect(config.initSegmentName == "init.mp4")
        #expect(config.playlistName == "playlist.m3u8")
        #expect(config.includeAudio == true)
        #expect(config.generatePlaylist == true)
        #expect(config.playlistType == .vod)
        #expect(config.hlsVersion == 7)
    }

    // MARK: - Custom Values

    @Test("custom config values")
    func customValues() {
        let config = SegmentationConfig(
            targetSegmentDuration: 10.0,
            outputMode: .byteRange,
            segmentNamePattern: "seg_%d.m4s",
            initSegmentName: "header.mp4",
            playlistName: "index.m3u8",
            includeAudio: false,
            generatePlaylist: false,
            playlistType: .event,
            hlsVersion: 9
        )
        #expect(config.targetSegmentDuration == 10.0)
        #expect(config.outputMode == .byteRange)
        #expect(config.segmentNamePattern == "seg_%d.m4s")
        #expect(config.initSegmentName == "header.mp4")
        #expect(config.playlistName == "index.m3u8")
        #expect(config.includeAudio == false)
        #expect(config.generatePlaylist == false)
        #expect(config.playlistType == .event)
        #expect(config.hlsVersion == 9)
    }

    // MARK: - OutputMode

    @Test("OutputMode raw values")
    func outputModeRawValues() {
        #expect(
            SegmentationConfig.OutputMode.separateFiles.rawValue
                == "separateFiles"
        )
        #expect(
            SegmentationConfig.OutputMode.byteRange.rawValue
                == "byteRange"
        )
    }

    @Test("OutputMode cases are distinct")
    func outputModeCases() {
        let separate = SegmentationConfig.OutputMode.separateFiles
        let byteRange = SegmentationConfig.OutputMode.byteRange
        #expect(separate != byteRange)
    }

    // MARK: - Hashable

    @Test("Hashable — equal configs hash equally")
    func hashableEqual() {
        let a = SegmentationConfig()
        let b = SegmentationConfig()
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Hashable — different configs are not equal")
    func hashableDifferent() {
        let a = SegmentationConfig()
        var b = SegmentationConfig()
        b.targetSegmentDuration = 10.0
        #expect(a != b)
    }

    // MARK: - Mutability

    @Test("config is mutable")
    func mutable() {
        var config = SegmentationConfig()
        config.targetSegmentDuration = 2.0
        config.outputMode = .byteRange
        config.includeAudio = false
        #expect(config.targetSegmentDuration == 2.0)
        #expect(config.outputMode == .byteRange)
        #expect(config.includeAudio == false)
    }
}
