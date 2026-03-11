// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - RTMP Transport v2 Showcase

@Suite("RTMP Transport v2 Showcase — Platform Presets & Metadata")
struct RTMPTransportV2ShowcaseTests {

    // MARK: - Major Platform Presets

    @Test("Twitch preset uses rtmps://live.twitch.tv/app")
    func twitchPreset() {
        let config = RTMPPusherConfiguration.twitch(streamKey: "live_abc123")

        #expect(config.serverURL.contains("rtmps://live.twitch.tv"))
        #expect(config.serverURL == "rtmps://live.twitch.tv/app")
        #expect(config.streamKey == "live_abc123")
        #expect(config.retryPolicy == .aggressive)
    }

    @Test("YouTube preset uses rtmps://a.rtmp.youtube.com/live2")
    func youtubePreset() {
        let config = RTMPPusherConfiguration.youtube(streamKey: "yt-key-456")

        #expect(config.serverURL == "rtmps://a.rtmp.youtube.com/live2")
        #expect(config.streamKey == "yt-key-456")
        #expect(config.retryPolicy == .default)
    }

    @Test("Facebook preset uses rtmps://live-api-s.facebook.com")
    func facebookPreset() {
        let config = RTMPPusherConfiguration.facebook(streamKey: "fb-key-789")

        #expect(config.serverURL.contains("facebook.com"))
        #expect(config.serverURL == "rtmps://live-api-s.facebook.com:443/rtmp")
        #expect(config.streamKey == "fb-key-789")
    }

    // MARK: - Extended Platform Presets (0.5.0)

    @Test("All v2 platform presets have correct ingest URLs")
    func allV2PlatformPresets() {
        let instagram = RTMPPusherConfiguration.instagram(streamKey: "ig-key")
        #expect(instagram.serverURL == "rtmps://live-upload.instagram.com:443/rtmp/")
        #expect(instagram.streamKey == "ig-key")

        let tiktok = RTMPPusherConfiguration.tiktok(streamKey: "tt-key")
        #expect(tiktok.serverURL == "rtmps://push.tiktok.com/rtmp/")
        #expect(tiktok.streamKey == "tt-key")

        let twitter = RTMPPusherConfiguration.twitter(streamKey: "tw-key")
        #expect(twitter.serverURL.contains("periscope.tv"))
        #expect(twitter.streamKey == "tw-key")

        let rumble = RTMPPusherConfiguration.rumble(streamKey: "rm-key")
        #expect(rumble.serverURL == "rtmp://publish.rumble.com/live/")
        #expect(rumble.streamKey == "rm-key")

        let kick = RTMPPusherConfiguration.kick(streamKey: "kk-key")
        #expect(kick.serverURL.contains("global-contribute.live-video.net"))
        #expect(kick.streamKey == "kk-key")

        let linkedin = RTMPPusherConfiguration.linkedin(streamKey: "li-key")
        #expect(linkedin.serverURL == "rtmps://livein.linkedin.com:443/live/")
        #expect(linkedin.streamKey == "li-key")

        let trovo = RTMPPusherConfiguration.trovo(streamKey: "tv-key")
        #expect(trovo.serverURL == "rtmp://livepush.trovo.live/live/")
        #expect(trovo.streamKey == "tv-key")
    }

    // MARK: - Full URL Composition

    @Test("fullURL combines serverURL and streamKey with separator")
    func fullURLComposition() {
        // Server URL without trailing slash
        let config1 = RTMPPusherConfiguration(
            serverURL: "rtmp://example.com/live",
            streamKey: "stream123"
        )
        #expect(config1.fullURL == "rtmp://example.com/live/stream123")

        // Server URL with trailing slash
        let config2 = RTMPPusherConfiguration(
            serverURL: "rtmp://example.com/live/",
            streamKey: "stream456"
        )
        #expect(config2.fullURL == "rtmp://example.com/live/stream456")

        // Twitch full URL
        let twitch = RTMPPusherConfiguration.twitch(streamKey: "live_abc")
        #expect(twitch.fullURL == "rtmps://live.twitch.tv/app/live_abc")
    }

    // MARK: - Server Capabilities

    @Test("RTMPServerCapabilities with Enhanced RTMP and codecs")
    func serverCapabilities() {
        let caps = RTMPServerCapabilities(
            supportsEnhancedRTMP: true,
            serverVersion: "nginx-rtmp/1.2.3",
            supportedCodecs: ["hvc1", "av01", "avc1"]
        )

        #expect(caps.supportsEnhancedRTMP == true)
        #expect(caps.serverVersion == "nginx-rtmp/1.2.3")
        #expect(caps.supportedCodecs.count == 3)
        #expect(caps.supportedCodecs.contains("hvc1"))
        #expect(caps.supportedCodecs.contains("av01"))
        #expect(caps.supportedCodecs.contains("avc1"))

        // Legacy server without Enhanced RTMP
        let legacy = RTMPServerCapabilities(
            supportsEnhancedRTMP: false,
            serverVersion: nil,
            supportedCodecs: []
        )
        #expect(legacy.supportsEnhancedRTMP == false)
        #expect(legacy.serverVersion == nil)
        #expect(legacy.supportedCodecs.isEmpty)
    }

    // MARK: - FLV Tag Types

    @Test("FLVTagType raw values match FLV specification")
    func flvTagTypeRawValues() {
        #expect(FLVTagType.audio.rawValue == 8)
        #expect(FLVTagType.video.rawValue == 9)
        #expect(FLVTagType.scriptData.rawValue == 18)

        // Verify round-trip from raw value
        #expect(FLVTagType(rawValue: 8) == .audio)
        #expect(FLVTagType(rawValue: 9) == .video)
        #expect(FLVTagType(rawValue: 18) == .scriptData)
        #expect(FLVTagType(rawValue: 99) == nil)
    }

    // MARK: - Metadata Configuration

    @Test("RTMP configuration with metadata and application name")
    func metadataAndApplicationName() {
        let config = RTMPPusherConfiguration(
            serverURL: "rtmp://broadcast.example.com/show",
            streamKey: "key-001",
            retryPolicy: .conservative,
            sendMetadata: true,
            applicationName: "live-broadcast"
        )

        #expect(config.sendMetadata == true)
        #expect(config.applicationName == "live-broadcast")
        #expect(config.retryPolicy == .conservative)
        #expect(config.serverURL == "rtmp://broadcast.example.com/show")

        // Default: sendMetadata is true, applicationName is nil
        let defaults = RTMPPusherConfiguration(
            serverURL: "rtmp://host/app",
            streamKey: "key"
        )
        #expect(defaults.sendMetadata == true)
        #expect(defaults.applicationName == nil)
        #expect(defaults.retryPolicy == .default)
    }
}
