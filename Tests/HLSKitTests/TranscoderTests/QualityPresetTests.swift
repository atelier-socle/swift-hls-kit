// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("QualityPreset")
struct QualityPresetTests {

    // MARK: - Built-in Preset Values

    @Test("p360: resolution 640x360, 800k, baseline")
    func p360Values() {
        let p = QualityPreset.p360
        #expect(p.name == "360p")
        #expect(p.resolution == Resolution(width: 640, height: 360))
        #expect(p.videoBitrate == 800_000)
        #expect(p.maxVideoBitrate == 1_200_000)
        #expect(p.audioBitrate == 64_000)
        #expect(p.videoProfile == .baseline)
        #expect(p.videoLevel == "3.0")
    }

    @Test("p480: resolution 854x480, 1.4M, main")
    func p480Values() {
        let p = QualityPreset.p480
        #expect(p.resolution == .p480)
        #expect(p.videoBitrate == 1_400_000)
        #expect(p.videoProfile == .main)
        #expect(p.videoLevel == "3.1")
    }

    @Test("p720: resolution 1280x720, 2.8M, high")
    func p720Values() {
        let p = QualityPreset.p720
        #expect(p.resolution == .p720)
        #expect(p.videoBitrate == 2_800_000)
        #expect(p.maxVideoBitrate == 4_200_000)
        #expect(p.audioBitrate == 128_000)
        #expect(p.videoProfile == .high)
        #expect(p.videoLevel == "3.1")
    }

    @Test("p1080: resolution 1920x1080, 5M, high")
    func p1080Values() {
        let p = QualityPreset.p1080
        #expect(p.resolution == .p1080)
        #expect(p.videoBitrate == 5_000_000)
        #expect(p.maxVideoBitrate == 7_500_000)
        #expect(p.videoProfile == .high)
        #expect(p.videoLevel == "4.0")
    }

    @Test("p2160: resolution 3840x2160, 14M")
    func p2160Values() {
        let p = QualityPreset.p2160
        #expect(p.resolution == .p2160)
        #expect(p.videoBitrate == 14_000_000)
        #expect(p.maxVideoBitrate == 21_000_000)
        #expect(p.audioBitrate == 192_000)
        #expect(p.videoLevel == "5.1")
    }

    @Test("audioOnly: no resolution, no video bitrate")
    func audioOnlyValues() {
        let p = QualityPreset.audioOnly
        #expect(p.resolution == nil)
        #expect(p.videoBitrate == nil)
        #expect(p.audioBitrate == 128_000)
        #expect(p.videoProfile == nil)
    }

    // MARK: - Computed Properties

    @Test("totalBandwidth = video + audio")
    func totalBandwidth() {
        #expect(QualityPreset.p720.totalBandwidth == 2_928_000)
        #expect(
            QualityPreset.audioOnly.totalBandwidth == 128_000
        )
    }

    @Test("isAudioOnly: true for audioOnly, false for others")
    func isAudioOnly() {
        #expect(QualityPreset.audioOnly.isAudioOnly)
        #expect(!QualityPreset.p720.isAudioOnly)
        #expect(!QualityPreset.p360.isAudioOnly)
    }

    // MARK: - Ladders

    @Test("standardLadder has 4 presets in order")
    func standardLadder() {
        let ladder = QualityPreset.standardLadder
        #expect(ladder.count == 4)
        #expect(ladder[0].name == "360p")
        #expect(ladder[1].name == "480p")
        #expect(ladder[2].name == "720p")
        #expect(ladder[3].name == "1080p")
    }

    @Test("fullLadder has 5 presets including 2160p")
    func fullLadder() {
        let ladder = QualityPreset.fullLadder
        #expect(ladder.count == 5)
        #expect(ladder[4].name == "2160p")
    }

    // MARK: - Custom Preset

    @Test("Custom preset creation")
    func customPreset() {
        let custom = QualityPreset(
            name: "mobile-low",
            resolution: Resolution(width: 426, height: 240),
            videoBitrate: 400_000,
            audioBitrate: 64_000,
            videoProfile: .baseline,
            videoLevel: "3.0",
            frameRate: 24.0
        )
        #expect(custom.name == "mobile-low")
        #expect(custom.resolution?.width == 426)
        #expect(custom.videoBitrate == 400_000)
        #expect(custom.frameRate == 24.0)
        #expect(custom.keyFrameInterval == 2.0)
    }

    // MARK: - Codable

    @Test("Codable round-trip")
    func codableRoundTrip() throws {
        let original = QualityPreset.p720
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            QualityPreset.self, from: data
        )
        #expect(decoded == original)
    }

    // MARK: - Hashable

    @Test("Hashable conformance")
    func hashable() {
        let set: Set<QualityPreset> = [.p720, .p1080, .p720]
        #expect(set.count == 2)
    }

    // MARK: - Codec Strings

    @Test("codecsString for H.264")
    func codecsStringH264() {
        let codecs = QualityPreset.p720.codecsString(
            videoCodec: .h264
        )
        #expect(codecs.contains("avc1."))
        #expect(codecs.contains("mp4a.40.2"))
    }

    @Test("codecsString for H.265")
    func codecsStringH265() {
        let codecs = QualityPreset.p1080.codecsString(
            videoCodec: .h265
        )
        #expect(codecs.contains("hvc1."))
        #expect(codecs.contains("mp4a.40.2"))
    }

    @Test("codecsString for audio-only")
    func codecsStringAudioOnly() {
        let codecs = QualityPreset.audioOnly.codecsString()
        #expect(!codecs.contains("avc1."))
        #expect(codecs == "mp4a.40.2")
    }

    @Test("codecsString baseline profile")
    func codecsStringBaseline() {
        let codecs = QualityPreset.p360.codecsString(
            videoCodec: .h264
        )
        #expect(codecs.hasPrefix("avc1.42"))
    }

    @Test("codecsString main profile")
    func codecsStringMain() {
        let codecs = QualityPreset.p480.codecsString(
            videoCodec: .h264
        )
        #expect(codecs.hasPrefix("avc1.4D"))
    }

    @Test("codecsString high profile")
    func codecsStringHigh() {
        let codecs = QualityPreset.p720.codecsString(
            videoCodec: .h264
        )
        #expect(codecs.hasPrefix("avc1.64"))
    }

    @Test("codecsString for VP9")
    func codecsStringVP9() {
        let codecs = QualityPreset.p720.codecsString(
            videoCodec: .vp9
        )
        #expect(codecs.hasPrefix("vp09."))
        #expect(codecs.contains("mp4a.40.2"))
    }

    @Test("codecsString for AV1")
    func codecsStringAV1() {
        let codecs = QualityPreset.p720.codecsString(
            videoCodec: .av1
        )
        #expect(codecs.hasPrefix("av01."))
        #expect(codecs.contains("mp4a.40.2"))
    }

    @Test("codecsString HEVC profile falls back to high hex")
    func codecsStringHEVCProfile() {
        let preset = QualityPreset(
            name: "hevc-test",
            resolution: .p720,
            videoBitrate: 2_800_000,
            videoProfile: .mainHEVC,
            videoLevel: "4.0"
        )
        let codecs = preset.codecsString(videoCodec: .h264)
        #expect(codecs.hasPrefix("avc1.64"))
    }

    @Test("codecsString main10 HEVC profile falls back to high hex")
    func codecsStringMain10HEVCProfile() {
        let preset = QualityPreset(
            name: "hevc10-test",
            resolution: .p720,
            videoBitrate: 2_800_000,
            videoProfile: .main10HEVC,
            videoLevel: "4.0"
        )
        let codecs = preset.codecsString(videoCodec: .h264)
        #expect(codecs.hasPrefix("avc1.64"))
    }

    @Test("codecsString nil videoLevel uses default 1E")
    func codecsStringNilLevel() {
        let preset = QualityPreset(
            name: "no-level",
            resolution: .p720,
            videoBitrate: 2_800_000,
            videoProfile: .high,
            videoLevel: nil
        )
        let codecs = preset.codecsString(videoCodec: .h264)
        #expect(codecs.hasPrefix("avc1.64001E"))
    }

    @Test("codecsString nil videoProfile uses high hex")
    func codecsStringNilProfile() {
        let preset = QualityPreset(
            name: "no-profile",
            resolution: .p720,
            videoBitrate: 2_800_000,
            videoProfile: nil,
            videoLevel: "3.1"
        )
        let codecs = preset.codecsString(videoCodec: .h264)
        #expect(codecs.hasPrefix("avc1.64"))
    }

    // MARK: - Resolution

    @Test("Resolution description format")
    func resolutionDescription() {
        let r = Resolution(width: 1920, height: 1080)
        #expect(r.description == "1920x1080")
    }

    @Test("Resolution.p360 preset")
    func resolutionP360() {
        #expect(Resolution.p360.width == 640)
        #expect(Resolution.p360.height == 360)
    }
}
