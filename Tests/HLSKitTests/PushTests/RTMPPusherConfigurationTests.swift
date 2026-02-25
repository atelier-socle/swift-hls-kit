// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("RTMPPusherConfiguration", .timeLimit(.minutes(1)))
struct RTMPPusherConfigurationTests {

    @Test("Twitch preset has correct URL")
    func twitchPreset() {
        let config = RTMPPusherConfiguration.twitch(
            streamKey: "live_abc123"
        )
        #expect(config.serverURL == "rtmp://live.twitch.tv/app")
        #expect(config.streamKey == "live_abc123")
        #expect(
            config.fullURL
                == "rtmp://live.twitch.tv/app/live_abc123"
        )
    }

    @Test("YouTube preset has correct URL")
    func youtubePreset() {
        let config = RTMPPusherConfiguration.youtube(
            streamKey: "yt-key-456"
        )
        #expect(
            config.serverURL
                == "rtmp://a.rtmp.youtube.com/live2"
        )
        #expect(config.streamKey == "yt-key-456")
    }

    @Test("Facebook preset has correct URL")
    func facebookPreset() {
        let config = RTMPPusherConfiguration.facebook(
            streamKey: "fb-key-789"
        )
        #expect(
            config.serverURL.contains("facebook.com")
        )
        #expect(config.streamKey == "fb-key-789")
    }

    @Test("Custom configuration")
    func customConfig() {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://my.server.com/live",
            streamKey: "my-key"
        )
        #expect(config.serverURL == "rtmp://my.server.com/live")
        #expect(config.streamKey == "my-key")
    }

    @Test("fullURL concatenation with trailing slash")
    func fullURLTrailingSlash() {
        let config = RTMPPusherConfiguration(
            serverURL: "rtmp://server.com/app/",
            streamKey: "key123"
        )
        #expect(
            config.fullURL == "rtmp://server.com/app/key123"
        )
    }

    @Test("sendMetadata defaults to true")
    func sendMetadataDefault() {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        #expect(config.sendMetadata)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = RTMPPusherConfiguration.twitch(
            streamKey: "key1"
        )
        let b = RTMPPusherConfiguration.twitch(
            streamKey: "key1"
        )
        let c = RTMPPusherConfiguration.twitch(
            streamKey: "key2"
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Application name override")
    func applicationNameOverride() {
        let config = RTMPPusherConfiguration(
            serverURL: "rtmp://server.com/app",
            streamKey: "key",
            applicationName: "custom-app"
        )
        #expect(config.applicationName == "custom-app")
    }
}
