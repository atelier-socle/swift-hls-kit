// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipelineConfiguration", .timeLimit(.minutes(1)))
struct LivePipelineConfigurationTests {

    // MARK: - Defaults

    @Test("Default configuration has sensible values")
    func defaultValues() {
        let config = LivePipelineConfiguration()
        #expect(config.audioBitrate == 128_000)
        #expect(config.audioSampleRate == 48_000)
        #expect(config.audioChannels == 2)
        #expect(config.videoEnabled == false)
        #expect(config.videoBitrate == 2_000_000)
        #expect(config.videoWidth == 1920)
        #expect(config.videoHeight == 1080)
        #expect(config.videoFrameRate == 30.0)
        #expect(config.segmentDuration == 6.0)
        #expect(config.containerFormat == .fmp4)
        #expect(config.enableDVR == false)
        #expect(config.dvrWindowDuration == 7200)
        #expect(config.lowLatency == nil)
        #expect(config.destinations.isEmpty)
        #expect(config.enableRecording == false)
        #expect(config.recordingDirectory == nil)
        #expect(config.enableProgramDateTime == true)
        #expect(config.programDateTimeInterval == 6.0)
        #expect(config.targetLoudness == nil)
    }

    @Test("Default configuration validates OK")
    func defaultValidates() {
        let config = LivePipelineConfiguration()
        #expect(config.validate() == nil)
    }

    // MARK: - SegmentContainerFormat

    @Test("SegmentContainerFormat all cases")
    func containerFormatCases() {
        let all = SegmentContainerFormat.allCases
        #expect(all.count == 3)
        #expect(SegmentContainerFormat.fmp4.rawValue == "fmp4")
        #expect(SegmentContainerFormat.mpegts.rawValue == "mpegts")
        #expect(SegmentContainerFormat.cmaf.rawValue == "cmaf")
    }

    // MARK: - PlaylistTypeConfig

    @Test("PlaylistTypeConfig sliding window")
    func playlistSlidingWindow() {
        let config = PlaylistTypeConfig.slidingWindow(windowSize: 10)
        #expect(config == .slidingWindow(windowSize: 10))
        #expect(config != .slidingWindow(windowSize: 5))
    }

    @Test("PlaylistTypeConfig event")
    func playlistEvent() {
        let config = PlaylistTypeConfig.event
        #expect(config == .event)
        #expect(config != .slidingWindow(windowSize: 5))
    }

    // MARK: - LowLatencyConfig

    @Test("LowLatencyConfig defaults")
    func lowLatencyDefaults() {
        let ll = LowLatencyConfig()
        #expect(ll.partTargetDuration == 0.5)
        #expect(ll.enablePreloadHints == true)
        #expect(ll.enableDeltaUpdates == true)
        #expect(ll.enableBlockingReload == true)
    }

    // MARK: - PushDestinationConfig

    @Test("PushDestinationConfig HTTP with headers")
    func pushHTTP() {
        let dest = PushDestinationConfig.http(
            url: "https://cdn.example.com", headers: ["Authorization": "Bearer token"]
        )
        #expect(dest == .http(url: "https://cdn.example.com", headers: ["Authorization": "Bearer token"]))
    }

    @Test("PushDestinationConfig local")
    func pushLocal() {
        let dest = PushDestinationConfig.local(directory: "/tmp/hls")
        #expect(dest == .local(directory: "/tmp/hls"))
    }

    // MARK: - Validation Errors

    @Test("Validate: segmentDuration <= 0 → error")
    func validateSegmentDuration() {
        var config = LivePipelineConfiguration()
        config.segmentDuration = 0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("segmentDuration") == true)
    }

    @Test("Validate: audioBitrate <= 0 → error")
    func validateAudioBitrate() {
        var config = LivePipelineConfiguration()
        config.audioBitrate = 0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("audioBitrate") == true)
    }

    @Test("Validate: videoEnabled + videoBitrate=0 → error")
    func validateVideoBitrate() {
        var config = LivePipelineConfiguration()
        config.videoEnabled = true
        config.videoBitrate = 0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("videoBitrate") == true)
    }

    @Test("Validate: videoEnabled + width=0 → error")
    func validateVideoWidth() {
        var config = LivePipelineConfiguration()
        config.videoEnabled = true
        config.videoWidth = 0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("videoWidth") == true)
    }

    @Test("Validate: audioSampleRate <= 0 → error")
    func validateAudioSampleRate() {
        var config = LivePipelineConfiguration()
        config.audioSampleRate = 0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("audioSampleRate") == true)
    }

    @Test("Validate: audioChannels <= 0 → error")
    func validateAudioChannels() {
        var config = LivePipelineConfiguration()
        config.audioChannels = 0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("audioChannels") == true)
    }

    @Test("Validate: videoEnabled + height=0 → error")
    func validateVideoHeight() {
        var config = LivePipelineConfiguration()
        config.videoEnabled = true
        config.videoHeight = 0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("videoHeight") == true)
    }

    @Test("Validate: videoEnabled + frameRate=0 → error")
    func validateVideoFrameRate() {
        var config = LivePipelineConfiguration()
        config.videoEnabled = true
        config.videoFrameRate = 0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("videoFrameRate") == true)
    }

    @Test("Validate: HTTP destination with empty URL → error")
    func validateEmptyHTTPURL() {
        var config = LivePipelineConfiguration()
        config.destinations = [.http(url: "")]
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("HTTP") == true)
    }

    @Test("Validate: local destination with empty directory → error")
    func validateEmptyLocalDirectory() {
        var config = LivePipelineConfiguration()
        config.destinations = [.local(directory: "")]
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("Local") == true)
    }

    @Test("Validate: enableRecording + nil directory → error")
    func validateRecordingDirectory() {
        var config = LivePipelineConfiguration()
        config.enableRecording = true
        config.recordingDirectory = nil
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("recordingDirectory") == true)
    }

    @Test("Validate: enableDVR + event playlist → error")
    func validateDVREvent() {
        var config = LivePipelineConfiguration()
        config.enableDVR = true
        config.playlistType = .event
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("DVR") == true)
    }

    @Test("Validate: lowLatency partTarget >= segmentDuration → error")
    func validateLowLatencyPartDuration() {
        var config = LivePipelineConfiguration()
        config.lowLatency = LowLatencyConfig(partTargetDuration: 6.0)
        config.segmentDuration = 6.0
        #expect(config.validate() != nil)
        #expect(config.validate()?.contains("partTargetDuration") == true)
    }

    @Test("Validate: valid complete config → nil")
    func validateCompleteConfig() {
        var config = LivePipelineConfiguration()
        config.videoEnabled = true
        config.enableRecording = true
        config.recordingDirectory = "/tmp/rec"
        config.enableDVR = true
        config.lowLatency = LowLatencyConfig(partTargetDuration: 0.5)
        config.destinations = [.http(url: "https://cdn.example.com")]
        #expect(config.validate() == nil)
    }

    // MARK: - Equatable

    @Test("Same configs are equal")
    func sameConfigEqual() {
        let config1 = LivePipelineConfiguration()
        let config2 = LivePipelineConfiguration()
        #expect(config1 == config2)
    }

    @Test("Different configs are not equal")
    func differentConfigNotEqual() {
        var config1 = LivePipelineConfiguration()
        var config2 = LivePipelineConfiguration()
        config2.audioBitrate = 256_000
        #expect(config1 != config2)

        config1.segmentDuration = 4.0
        #expect(config1 != config2)
    }
}
