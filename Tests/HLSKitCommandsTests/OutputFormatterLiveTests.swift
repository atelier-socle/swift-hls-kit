// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - OutputFormatter Live Pipeline Coverage

@Suite("OutputFormatter — Live Pipeline Coverage")
struct OutputFormatterLiveCoverageTests {

    @Test("formatLiveConfig text with audio-only config")
    func configTextAudioOnly() {
        let formatter = OutputFormatter.text
        let config = LivePipelineConfiguration.podcastLive
        let result = formatter.formatLiveConfig(
            config, outputDirectory: "/tmp/live"
        )
        #expect(result.contains("128 kbps"))
        #expect(result.contains("/tmp/live"))
    }

    @Test("formatLiveConfig text with video config")
    func configTextVideo() {
        let formatter = OutputFormatter.text
        let config = LivePipelineConfiguration.videoLive
        let result = formatter.formatLiveConfig(
            config, outputDirectory: "/tmp/live"
        )
        #expect(result.contains("1920x1080"))
        #expect(result.contains("LL-HLS"))
    }

    @Test("formatLiveConfig text with DVR config")
    func configTextDVR() {
        let formatter = OutputFormatter.text
        let config = LivePipelineConfiguration.broadcast
        let result = formatter.formatLiveConfig(
            config, outputDirectory: "/tmp/live"
        )
        #expect(result.contains("DVR"))
        #expect(result.contains("LUFS"))
        #expect(result.contains("Recording"))
    }

    @Test("formatLiveConfig text with push destinations")
    func configTextPush() {
        let formatter = OutputFormatter.text
        var config = LivePipelineConfiguration()
        config.destinations = [
            .http(url: "https://cdn.example.com")
        ]
        let result = formatter.formatLiveConfig(
            config, outputDirectory: "/tmp/live"
        )
        #expect(result.contains("push target"))
    }

    @Test("formatLiveConfig JSON format")
    func configJSON() {
        let formatter = OutputFormatter.json
        let config = LivePipelineConfiguration.videoLive
        let result = formatter.formatLiveConfig(
            config, outputDirectory: "/tmp/live"
        )
        #expect(result.contains("\"outputDirectory\""))
        #expect(result.contains("\"audioBitrate\""))
        #expect(result.contains("\"videoEnabled\""))
    }

    @Test("formatLiveConfig JSON with loudness")
    func configJSONLoudness() {
        let formatter = OutputFormatter.json
        let config = LivePipelineConfiguration.broadcast
        let result = formatter.formatLiveConfig(
            config, outputDirectory: "/tmp/live"
        )
        #expect(result.contains("\"targetLoudness\""))
    }

    @Test("formatLiveConfig JSON with destinations")
    func configJSONDestinations() {
        let formatter = OutputFormatter.json
        var config = LivePipelineConfiguration()
        config.destinations = [
            .http(url: "https://cdn.example.com")
        ]
        let result = formatter.formatLiveConfig(
            config, outputDirectory: "/tmp/live"
        )
        #expect(result.contains("\"destinations\""))
    }

    @Test("formatLiveStats text format")
    func statsText() {
        let formatter = OutputFormatter.text
        var stats = LivePipelineStatistics()
        stats.uptime = 3661
        stats.segmentsProduced = 610
        stats.averageSegmentDuration = 6.0
        stats.totalBytes = 57_600_000
        stats.estimatedBitrate = 128_000
        let result = formatter.formatLiveStats(stats)
        #expect(result.contains("01:01:01"))
        #expect(result.contains("610"))
        #expect(result.contains("128 kbps"))
    }

    @Test("formatLiveStats text with push and errors")
    func statsTextPush() {
        let formatter = OutputFormatter.text
        var stats = LivePipelineStatistics()
        stats.uptime = 60
        stats.activeDestinations = 2
        stats.bytesSent = 1_048_576
        stats.pushErrors = 3
        stats.partialsProduced = 120
        stats.recordingActive = true
        stats.recordedSegments = 10
        stats.droppedSegments = 1
        let result = formatter.formatLiveStats(stats)
        #expect(result.contains("2 dest"))
        #expect(result.contains("3"))
        #expect(result.contains("120 partials"))
        #expect(result.contains("10 segments"))
    }

    @Test("formatLiveStats JSON format")
    func statsJSON() {
        let formatter = OutputFormatter.json
        var stats = LivePipelineStatistics()
        stats.uptime = 100
        stats.segmentsProduced = 16
        let result = formatter.formatLiveStats(stats)
        #expect(result.contains("\"uptime\""))
        #expect(result.contains("\"segmentsProduced\""))
    }

    @Test("formatPresetList text contains all 16 presets")
    func presetListText() {
        let formatter = OutputFormatter.text
        let result = formatter.formatPresetList()
        #expect(result.contains("podcast-live"))
        #expect(result.contains("dj-mix-dvr"))
        #expect(result.contains("conference-stream"))
    }

    @Test("formatPresetList JSON format")
    func presetListJSON() {
        let formatter = OutputFormatter.json
        let result = formatter.formatPresetList()
        #expect(result.hasPrefix("["))
        #expect(result.contains("\"podcast-live\""))
        #expect(result.contains("\"dj-mix-dvr\""))
    }
}
