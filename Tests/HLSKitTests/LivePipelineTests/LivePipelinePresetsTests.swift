// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipelinePresets", .timeLimit(.minutes(1)))
struct LivePipelinePresetsTests {

    // MARK: - podcastLive

    @Test("podcastLive validates successfully")
    func podcastLiveValidates() {
        #expect(LivePipelineConfiguration.podcastLive.validate() == nil)
    }

    @Test("podcastLive: audio-only, -16 LUFS, mpegts, sliding(5)")
    func podcastLiveValues() {
        let c = LivePipelineConfiguration.podcastLive
        #expect(c.audioBitrate == 128_000)
        #expect(c.videoEnabled == false)
        #expect(c.containerFormat == .mpegts)
        #expect(c.playlistType == .slidingWindow(windowSize: 5))
        #expect(c.targetLoudness == -16.0)
        #expect(c.enableProgramDateTime == true)
    }

    // MARK: - webradio

    @Test("webradio validates successfully")
    func webradioValidates() {
        #expect(LivePipelineConfiguration.webradio.validate() == nil)
    }

    @Test("webradio: 256kbps, fmp4, LL-HLS enabled, sliding(8)")
    func webradioValues() {
        let c = LivePipelineConfiguration.webradio
        #expect(c.audioBitrate == 256_000)
        #expect(c.videoEnabled == false)
        #expect(c.containerFormat == .fmp4)
        #expect(c.playlistType == .slidingWindow(windowSize: 8))
        #expect(c.lowLatency?.partTargetDuration == 1.0)
        #expect(c.segmentDuration == 4.0)
        #expect(c.targetLoudness == nil)
    }

    // MARK: - djMix

    @Test("djMix validates successfully")
    func djMixValidates() {
        #expect(LivePipelineConfiguration.djMix.validate() == nil)
    }

    @Test("djMix: 320kbps, event playlist, recording enabled")
    func djMixValues() {
        let c = LivePipelineConfiguration.djMix
        #expect(c.audioBitrate == 320_000)
        #expect(c.videoEnabled == false)
        #expect(c.containerFormat == .fmp4)
        #expect(c.playlistType == .event)
        #expect(c.enableRecording == true)
        #expect(c.recordingDirectory != nil)
        #expect(c.targetLoudness == nil)
    }

    // MARK: - lowBandwidth

    @Test("lowBandwidth validates successfully")
    func lowBandwidthValidates() {
        #expect(LivePipelineConfiguration.lowBandwidth.validate() == nil)
    }

    @Test("lowBandwidth: 48kbps, mono, 22050 Hz, 10s segments")
    func lowBandwidthValues() {
        let c = LivePipelineConfiguration.lowBandwidth
        #expect(c.audioBitrate == 48_000)
        #expect(c.audioSampleRate == 22_050)
        #expect(c.audioChannels == 1)
        #expect(c.videoEnabled == false)
        #expect(c.segmentDuration == 10.0)
        #expect(c.containerFormat == .mpegts)
        #expect(c.playlistType == .slidingWindow(windowSize: 3))
    }

    // MARK: - videoLive

    @Test("videoLive validates successfully")
    func videoLiveValidates() {
        #expect(LivePipelineConfiguration.videoLive.validate() == nil)
    }

    @Test("videoLive: video enabled, 1080p, LL-HLS 0.5s parts")
    func videoLiveValues() {
        let c = LivePipelineConfiguration.videoLive
        #expect(c.videoEnabled == true)
        #expect(c.videoWidth == 1920)
        #expect(c.videoHeight == 1080)
        #expect(c.videoBitrate == 4_000_000)
        #expect(c.videoFrameRate == 30.0)
        #expect(c.lowLatency?.partTargetDuration == 0.5)
        #expect(c.containerFormat == .fmp4)
    }

    // MARK: - lowLatencyVideo

    @Test("lowLatencyVideo validates successfully")
    func lowLatencyVideoValidates() {
        #expect(LivePipelineConfiguration.lowLatencyVideo.validate() == nil)
    }

    @Test("lowLatencyVideo: 720p, 0.33s parts, all LL-HLS features")
    func lowLatencyVideoValues() {
        let c = LivePipelineConfiguration.lowLatencyVideo
        #expect(c.videoEnabled == true)
        #expect(c.videoWidth == 1280)
        #expect(c.videoHeight == 720)
        #expect(c.videoBitrate == 2_000_000)
        #expect(c.segmentDuration == 4.0)
        #expect(c.lowLatency?.partTargetDuration == 0.33)
        #expect(c.lowLatency?.enablePreloadHints == true)
        #expect(c.lowLatency?.enableDeltaUpdates == true)
        #expect(c.lowLatency?.enableBlockingReload == true)
    }

    // MARK: - videoSimulcast

    @Test("videoSimulcast validates successfully")
    func videoSimulcastValidates() {
        #expect(LivePipelineConfiguration.videoSimulcast.validate() == nil)
    }

    @Test("videoSimulcast: 1080p, no LL-HLS, no recording")
    func videoSimulcastValues() {
        let c = LivePipelineConfiguration.videoSimulcast
        #expect(c.videoEnabled == true)
        #expect(c.videoWidth == 1920)
        #expect(c.videoHeight == 1080)
        #expect(c.videoBitrate == 4_000_000)
        #expect(c.lowLatency == nil)
        #expect(c.enableRecording == false)
    }

    // MARK: - applePodcastLive

    @Test("applePodcastLive validates successfully")
    func applePodcastLiveValidates() {
        #expect(LivePipelineConfiguration.applePodcastLive.validate() == nil)
    }

    @Test("applePodcastLive: fmp4, -16 LUFS, sliding(6)")
    func applePodcastLiveValues() {
        let c = LivePipelineConfiguration.applePodcastLive
        #expect(c.containerFormat == .fmp4)
        #expect(c.targetLoudness == -16.0)
        #expect(c.playlistType == .slidingWindow(windowSize: 6))
        #expect(c.videoEnabled == false)
        #expect(c.enableProgramDateTime == true)
    }

    // MARK: - broadcast

    @Test("broadcast validates successfully")
    func broadcastValidates() {
        #expect(LivePipelineConfiguration.broadcast.validate() == nil)
    }

    @Test("broadcast: -23 LUFS, DVR 2h, recording")
    func broadcastValues() {
        let c = LivePipelineConfiguration.broadcast
        #expect(c.audioBitrate == 192_000)
        #expect(c.targetLoudness == -23.0)
        #expect(c.enableDVR == true)
        #expect(c.dvrWindowDuration == 7200)
        #expect(c.enableRecording == true)
        #expect(c.recordingDirectory != nil)
        #expect(c.playlistType == .slidingWindow(windowSize: 6))
    }

    // MARK: - eventRecording

    @Test("eventRecording validates successfully")
    func eventRecordingValidates() {
        #expect(LivePipelineConfiguration.eventRecording.validate() == nil)
    }

    @Test("eventRecording: event playlist, recording, no loudness")
    func eventRecordingValues() {
        let c = LivePipelineConfiguration.eventRecording
        #expect(c.playlistType == .event)
        #expect(c.enableRecording == true)
        #expect(c.recordingDirectory != nil)
        #expect(c.targetLoudness == nil)
        #expect(c.containerFormat == .fmp4)
        #expect(c.enableProgramDateTime == true)
    }

    // MARK: - Cross-Preset Tests

    @Test("All presets validate successfully")
    func allPresetsValidate() {
        let presets: [LivePipelineConfiguration] = [
            .podcastLive, .webradio, .djMix, .lowBandwidth,
            .videoLive, .lowLatencyVideo, .videoSimulcast,
            .applePodcastLive, .broadcast, .eventRecording
        ]
        for preset in presets {
            #expect(preset.validate() == nil)
        }
    }

    @Test("No two presets are identical")
    func noIdenticalPresets() {
        let presets: [LivePipelineConfiguration] = [
            .podcastLive, .webradio, .djMix, .lowBandwidth,
            .videoLive, .lowLatencyVideo, .videoSimulcast,
            .applePodcastLive, .broadcast, .eventRecording
        ]
        for i in 0..<presets.count {
            for j in (i + 1)..<presets.count {
                #expect(presets[i] != presets[j])
            }
        }
    }

    @Test("Audio-only presets have videoEnabled = false")
    func audioOnlyPresetsNoVideo() {
        let audioOnly: [LivePipelineConfiguration] = [
            .podcastLive, .webradio, .djMix, .lowBandwidth,
            .applePodcastLive, .broadcast, .eventRecording
        ]
        for preset in audioOnly {
            #expect(preset.videoEnabled == false)
        }
    }

    @Test("Video presets have videoEnabled = true")
    func videoPresetsHaveVideo() {
        let video: [LivePipelineConfiguration] = [
            .videoLive, .lowLatencyVideo, .videoSimulcast
        ]
        for preset in video {
            #expect(preset.videoEnabled == true)
        }
    }

    @Test("All LL-HLS presets have partTargetDuration < segmentDuration")
    func llhlsPartDurationValid() throws {
        let withLL: [LivePipelineConfiguration] = [
            .webradio, .videoLive, .lowLatencyVideo
        ]
        for preset in withLL {
            let ll = try #require(preset.lowLatency)
            #expect(ll.partTargetDuration < preset.segmentDuration)
        }
    }

    @Test("All recording presets have enableRecording = true")
    func recordingPresetsEnabled() {
        let withRecording: [LivePipelineConfiguration] = [
            .djMix, .broadcast, .eventRecording
        ]
        for preset in withRecording {
            #expect(preset.enableRecording == true)
            #expect(preset.recordingDirectory != nil)
        }
    }

    @Test("DVR presets use sliding window")
    func dvrPresetsSlidingWindow() {
        let withDVR: [LivePipelineConfiguration] = [.broadcast]
        for preset in withDVR {
            #expect(preset.enableDVR == true)
            if case .slidingWindow = preset.playlistType {
                // OK
            } else {
                Issue.record("DVR preset must use sliding window")
            }
        }
    }
}
