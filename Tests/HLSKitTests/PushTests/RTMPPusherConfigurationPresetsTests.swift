// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("RTMPPusherConfiguration — Platform Presets")
struct RTMPPusherConfigurationPresetsTests {

    // MARK: - New Presets (0.4.0)

    @Test("Instagram preset has correct URL and key")
    func instagramPreset() {
        let config = RTMPPusherConfiguration.instagram(
            streamKey: "ig_key_123"
        )
        #expect(
            config.serverURL
                == "rtmps://live-upload.instagram.com:443/rtmp/"
        )
        #expect(config.streamKey == "ig_key_123")
        #expect(
            config.fullURL
                == "rtmps://live-upload.instagram.com:443/rtmp/ig_key_123"
        )
    }

    @Test("TikTok preset has correct URL and key")
    func tiktokPreset() {
        let config = RTMPPusherConfiguration.tiktok(
            streamKey: "tt_stream_key"
        )
        #expect(
            config.serverURL == "rtmps://push.tiktok.com/rtmp/"
        )
        #expect(config.streamKey == "tt_stream_key")
        #expect(
            config.fullURL
                == "rtmps://push.tiktok.com/rtmp/tt_stream_key"
        )
    }

    @Test("Twitter preset has correct URL and key")
    func twitterPreset() {
        let config = RTMPPusherConfiguration.twitter(
            streamKey: "x_key_456"
        )
        #expect(
            config.serverURL
                == "rtmps://prod-rtmp-publish.periscope.tv:443/"
        )
        #expect(config.streamKey == "x_key_456")
        #expect(
            config.fullURL
                == "rtmps://prod-rtmp-publish.periscope.tv:443/x_key_456"
        )
    }

    @Test("Rumble preset has correct URL and key")
    func rumblePreset() {
        let config = RTMPPusherConfiguration.rumble(
            streamKey: "rmbl_key"
        )
        #expect(
            config.serverURL == "rtmp://publish.rumble.com/live/"
        )
        #expect(config.streamKey == "rmbl_key")
        #expect(
            config.fullURL
                == "rtmp://publish.rumble.com/live/rmbl_key"
        )
    }

    @Test("Kick preset has correct URL and key")
    func kickPreset() {
        let config = RTMPPusherConfiguration.kick(
            streamKey: "kick_stream"
        )
        #expect(
            config.serverURL
                == "rtmp://fa723fc1b171.global-contribute.live-video.net/app/"
        )
        #expect(config.streamKey == "kick_stream")
        #expect(
            config.fullURL
                == "rtmp://fa723fc1b171.global-contribute.live-video.net/app/kick_stream"
        )
    }

    @Test("All new presets use default retry policy")
    func newPresetsDefaultRetryPolicy() {
        let presets = [
            RTMPPusherConfiguration.instagram(streamKey: "k"),
            RTMPPusherConfiguration.tiktok(streamKey: "k"),
            RTMPPusherConfiguration.twitter(streamKey: "k"),
            RTMPPusherConfiguration.rumble(streamKey: "k"),
            RTMPPusherConfiguration.kick(streamKey: "k")
        ]
        for preset in presets {
            #expect(preset.retryPolicy == .default)
            #expect(preset.sendMetadata)
        }
    }

    // MARK: - Existing Presets (0.3.0 — Unchanged)

    @Test("Existing Twitch preset unchanged")
    func twitchPresetUnchanged() {
        let config = RTMPPusherConfiguration.twitch(
            streamKey: "live_abc"
        )
        #expect(
            config.serverURL == "rtmps://live.twitch.tv/app"
        )
        #expect(config.streamKey == "live_abc")
        #expect(config.retryPolicy == .aggressive)
        #expect(
            config.fullURL
                == "rtmps://live.twitch.tv/app/live_abc"
        )
    }

    @Test("Existing YouTube preset unchanged")
    func youtubePresetUnchanged() {
        let config = RTMPPusherConfiguration.youtube(
            streamKey: "yt_key"
        )
        #expect(
            config.serverURL
                == "rtmps://a.rtmp.youtube.com/live2"
        )
        #expect(config.streamKey == "yt_key")
        #expect(config.retryPolicy == .default)
    }

    @Test("Existing Facebook preset unchanged")
    func facebookPresetUnchanged() {
        let config = RTMPPusherConfiguration.facebook(
            streamKey: "fb_key"
        )
        #expect(
            config.serverURL
                == "rtmps://live-api-s.facebook.com:443/rtmp"
        )
        #expect(config.streamKey == "fb_key")
    }

    @Test("Existing custom preset unchanged")
    func customPresetUnchanged() {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://my.server.com/live",
            streamKey: "my_key"
        )
        #expect(
            config.serverURL == "rtmp://my.server.com/live"
        )
        #expect(config.streamKey == "my_key")
        #expect(config.retryPolicy == .default)
    }
}
