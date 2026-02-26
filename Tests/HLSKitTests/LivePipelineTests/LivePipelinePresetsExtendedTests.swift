// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipelinePresets Extended", .timeLimit(.minutes(1)))
struct LivePipelinePresetsExtendedTests {

    // MARK: - video4K

    @Test("video4K validates successfully")
    func video4KValidates() {
        #expect(LivePipelineConfiguration.video4K.validate() == nil)
    }

    @Test("video4K: 3840×2160, 15 Mbps, LL-HLS 0.5s")
    func video4KValues() {
        let c = LivePipelineConfiguration.video4K
        #expect(c.videoEnabled == true)
        #expect(c.videoWidth == 3840)
        #expect(c.videoHeight == 2160)
        #expect(c.videoBitrate == 15_000_000)
        #expect(c.audioBitrate == 192_000)
        #expect(c.lowLatency?.partTargetDuration == 0.5)
    }

    // MARK: - video4KLowLatency

    @Test("video4KLowLatency validates successfully")
    func video4KLowLatencyValidates() {
        #expect(LivePipelineConfiguration.video4KLowLatency.validate() == nil)
    }

    @Test("video4KLowLatency: 4K, 0.33s parts, all LL-HLS")
    func video4KLowLatencyValues() {
        let c = LivePipelineConfiguration.video4KLowLatency
        #expect(c.videoWidth == 3840)
        #expect(c.videoHeight == 2160)
        #expect(c.segmentDuration == 4.0)
        #expect(c.lowLatency?.partTargetDuration == 0.33)
        #expect(c.lowLatency?.enablePreloadHints == true)
        #expect(c.lowLatency?.enableDeltaUpdates == true)
        #expect(c.lowLatency?.enableBlockingReload == true)
    }

    // MARK: - podcastVideo

    @Test("podcastVideo validates successfully")
    func podcastVideoValidates() {
        #expect(LivePipelineConfiguration.podcastVideo.validate() == nil)
    }

    @Test("podcastVideo: 720p, -16 LUFS, recording")
    func podcastVideoValues() {
        let c = LivePipelineConfiguration.podcastVideo
        #expect(c.videoEnabled == true)
        #expect(c.videoWidth == 1280)
        #expect(c.videoHeight == 720)
        #expect(c.videoBitrate == 1_500_000)
        #expect(c.targetLoudness == -16.0)
        #expect(c.enableRecording == true)
    }

    // MARK: - videoLiveWithDVR

    @Test("videoLiveWithDVR validates successfully")
    func videoLiveWithDVRValidates() {
        #expect(LivePipelineConfiguration.videoLiveWithDVR.validate() == nil)
    }

    @Test("videoLiveWithDVR: 1080p, DVR 4h, LL-HLS, recording")
    func videoLiveWithDVRValues() {
        let c = LivePipelineConfiguration.videoLiveWithDVR
        #expect(c.videoEnabled == true)
        #expect(c.videoWidth == 1920)
        #expect(c.enableDVR == true)
        #expect(c.dvrWindowDuration == 14400)
        #expect(c.lowLatency?.partTargetDuration == 0.5)
        #expect(c.enableRecording == true)
    }

    // MARK: - djMixWithDVR

    @Test("djMixWithDVR validates successfully")
    func djMixWithDVRValidates() {
        #expect(LivePipelineConfiguration.djMixWithDVR.validate() == nil)
    }

    @Test("djMixWithDVR: 320kbps, DVR 6h, recording")
    func djMixWithDVRValues() {
        let c = LivePipelineConfiguration.djMixWithDVR
        #expect(c.audioBitrate == 320_000)
        #expect(c.videoEnabled == false)
        #expect(c.enableDVR == true)
        #expect(c.dvrWindowDuration == 21600)
        #expect(c.enableRecording == true)
        #expect(c.playlistType == .slidingWindow(windowSize: 10))
    }

    // MARK: - conferenceStream

    @Test("conferenceStream validates successfully")
    func conferenceStreamValidates() {
        #expect(LivePipelineConfiguration.conferenceStream.validate() == nil)
    }

    @Test("conferenceStream: 720p@15fps, event, recording")
    func conferenceStreamValues() {
        let c = LivePipelineConfiguration.conferenceStream
        #expect(c.videoEnabled == true)
        #expect(c.videoFrameRate == 15.0)
        #expect(c.videoBitrate == 1_000_000)
        #expect(c.audioBitrate == 96_000)
        #expect(c.playlistType == .event)
        #expect(c.enableRecording == true)
    }

    // MARK: - All 16 Presets Cross-Check

    @Test("All 16 presets validate successfully")
    func all16PresetsValidate() {
        let presets: [LivePipelineConfiguration] = [
            .podcastLive, .webradio, .djMix, .lowBandwidth,
            .videoLive, .lowLatencyVideo, .videoSimulcast,
            .applePodcastLive, .broadcast, .eventRecording,
            .video4K, .video4KLowLatency, .podcastVideo,
            .videoLiveWithDVR, .djMixWithDVR, .conferenceStream
        ]
        for preset in presets {
            #expect(preset.validate() == nil)
        }
    }

    @Test("No two of 16 presets are identical")
    func no16PresetsIdentical() {
        let presets: [LivePipelineConfiguration] = [
            .podcastLive, .webradio, .djMix, .lowBandwidth,
            .videoLive, .lowLatencyVideo, .videoSimulcast,
            .applePodcastLive, .broadcast, .eventRecording,
            .video4K, .video4KLowLatency, .podcastVideo,
            .videoLiveWithDVR, .djMixWithDVR, .conferenceStream
        ]
        for i in 0..<presets.count {
            for j in (i + 1)..<presets.count {
                #expect(presets[i] != presets[j])
            }
        }
    }

    @Test("DVR extended presets use sliding window")
    func dvrExtendedPresetsSlidingWindow() {
        let withDVR: [LivePipelineConfiguration] = [
            .videoLiveWithDVR, .djMixWithDVR
        ]
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
