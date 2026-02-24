// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("LiveEncoder Protocol & Configuration", .timeLimit(.minutes(1)))
struct LiveEncoderProtocolTests {

    // MARK: - Configuration Presets

    @Test("podcastAudio preset: AAC-LC, 64kbps, 44.1kHz, mono")
    func podcastAudioPreset() {
        let config = LiveEncoderConfiguration.podcastAudio
        #expect(config.audioCodec == .aac)
        #expect(config.bitrate == 64_000)
        #expect(config.sampleRate == 44_100)
        #expect(config.channels == 1)
        #expect(config.aacProfile == .lc)
        #expect(!config.passthrough)
        #expect(config.videoCodec == nil)
    }

    @Test("musicAudio preset: AAC-LC, 256kbps, 48kHz, stereo")
    func musicAudioPreset() {
        let config = LiveEncoderConfiguration.musicAudio
        #expect(config.audioCodec == .aac)
        #expect(config.bitrate == 256_000)
        #expect(config.sampleRate == 48_000)
        #expect(config.channels == 2)
        #expect(config.aacProfile == .lc)
        #expect(!config.passthrough)
    }

    @Test("lowBandwidthAudio preset: HE-AAC v2, 32kbps, 44.1kHz, stereo")
    func lowBandwidthAudioPreset() {
        let config = LiveEncoderConfiguration.lowBandwidthAudio
        #expect(config.audioCodec == .aac)
        #expect(config.bitrate == 32_000)
        #expect(config.sampleRate == 44_100)
        #expect(config.channels == 2)
        #expect(config.aacProfile == .heV2)
        #expect(!config.passthrough)
    }

    @Test("hiResPassthrough preset: ALAC, passthrough, 96kHz")
    func hiResPassthroughPreset() {
        let config = LiveEncoderConfiguration.hiResPassthrough
        #expect(config.audioCodec == .alac)
        #expect(config.bitrate == 0)
        #expect(config.sampleRate == 96_000)
        #expect(config.channels == 2)
        #expect(config.passthrough)
        #expect(config.aacProfile == nil)
    }

    // MARK: - Configuration Custom Init

    @Test("Custom configuration with video codec")
    func customConfigWithVideo() {
        let config = LiveEncoderConfiguration(
            audioCodec: .aac,
            videoCodec: .h264,
            bitrate: 128_000,
            sampleRate: 48_000,
            channels: 2,
            aacProfile: .lc
        )
        #expect(config.videoCodec == .h264)
        #expect(config.audioCodec == .aac)
        #expect(config.bitrate == 128_000)
    }

    @Test("Custom configuration defaults")
    func customConfigDefaults() {
        let config = LiveEncoderConfiguration(
            audioCodec: .opus,
            bitrate: 96_000,
            sampleRate: 48_000,
            channels: 2
        )
        #expect(config.videoCodec == nil)
        #expect(config.aacProfile == nil)
        #expect(!config.passthrough)
    }

    // MARK: - Equatable

    @Test("Configuration Equatable: identical configs are equal")
    func configEquatableIdentical() {
        let config1 = LiveEncoderConfiguration.podcastAudio
        let config2 = LiveEncoderConfiguration.podcastAudio
        #expect(config1 == config2)
    }

    @Test("Configuration Equatable: different configs are not equal")
    func configEquatableDifferent() {
        let podcast = LiveEncoderConfiguration.podcastAudio
        let music = LiveEncoderConfiguration.musicAudio
        #expect(podcast != music)
    }

    // MARK: - Hashable

    @Test("Configuration Hashable: set deduplication")
    func configHashable() {
        var set = Set<LiveEncoderConfiguration>()
        set.insert(.podcastAudio)
        set.insert(.podcastAudio)
        set.insert(.musicAudio)
        #expect(set.count == 2)
    }

    // MARK: - Sendable

    @Test("Configuration is Sendable across tasks")
    func configSendable() async {
        let config = LiveEncoderConfiguration.podcastAudio
        await Task {
            #expect(config.audioCodec == .aac)
        }.value
    }

    // MARK: - LiveEncoderError

    @Test("LiveEncoderError: notConfigured")
    func errorNotConfigured() {
        let error = LiveEncoderError.notConfigured
        #expect(error == .notConfigured)
    }

    @Test("LiveEncoderError: unsupportedConfiguration with reason")
    func errorUnsupportedConfiguration() {
        let error = LiveEncoderError.unsupportedConfiguration("test reason")
        #expect(error == .unsupportedConfiguration("test reason"))
        #expect(error != .unsupportedConfiguration("different"))
    }

    @Test("LiveEncoderError: encodingFailed")
    func errorEncodingFailed() {
        let error = LiveEncoderError.encodingFailed("buffer overflow")
        #expect(error == .encodingFailed("buffer overflow"))
    }

    @Test("LiveEncoderError: formatMismatch")
    func errorFormatMismatch() {
        let error = LiveEncoderError.formatMismatch("wrong sample rate")
        #expect(error == .formatMismatch("wrong sample rate"))
    }

    @Test("LiveEncoderError: tornDown")
    func errorTornDown() {
        let error = LiveEncoderError.tornDown
        #expect(error == .tornDown)
    }

    @Test("LiveEncoderError: ffmpegNotAvailable")
    func errorFFmpegNotAvailable() {
        let error = LiveEncoderError.ffmpegNotAvailable
        #expect(error == .ffmpegNotAvailable)
    }

    @Test("LiveEncoderError: ffmpegProcessError")
    func errorFFmpegProcessError() {
        let error = LiveEncoderError.ffmpegProcessError("exit code 1")
        #expect(error == .ffmpegProcessError("exit code 1"))
    }

    @Test("LiveEncoderError: different variants are not equal")
    func errorDifferentVariants() {
        #expect(LiveEncoderError.notConfigured != .tornDown)
        #expect(LiveEncoderError.ffmpegNotAvailable != .notConfigured)
        #expect(
            LiveEncoderError.encodingFailed("a")
                != .formatMismatch("a")
        )
    }
}
