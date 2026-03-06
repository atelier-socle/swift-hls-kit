// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - RTMP Preset Completeness

@Suite("RTMP Presets — Completeness")
struct RTMPPresetCompletenessTests {

    @Test("Twitch preset uses rtmps://")
    func twitchUsesRTMPS() {
        let config = RTMPPusherConfiguration.twitch(
            streamKey: "live_test"
        )
        #expect(
            config.serverURL == "rtmps://live.twitch.tv/app"
        )
        #expect(
            config.fullURL
                == "rtmps://live.twitch.tv/app/live_test"
        )
    }

    @Test("YouTube preset uses rtmps://")
    func youtubeUsesRTMPS() {
        let config = RTMPPusherConfiguration.youtube(
            streamKey: "yt_key"
        )
        #expect(
            config.serverURL
                == "rtmps://a.rtmp.youtube.com/live2"
        )
    }

    @Test("All RTMP presets have correct URLs")
    func allPresetsCorrectURLs() {
        #expect(
            RTMPPusherConfiguration.twitch(streamKey: "k")
                .serverURL == "rtmps://live.twitch.tv/app"
        )
        #expect(
            RTMPPusherConfiguration.youtube(streamKey: "k")
                .serverURL
                == "rtmps://a.rtmp.youtube.com/live2"
        )
        #expect(
            RTMPPusherConfiguration.facebook(streamKey: "k")
                .serverURL
                == "rtmps://live-api-s.facebook.com:443/rtmp"
        )
        #expect(
            RTMPPusherConfiguration.instagram(streamKey: "k")
                .serverURL
                == "rtmps://live-upload.instagram.com:443/rtmp/"
        )
        #expect(
            RTMPPusherConfiguration.tiktok(streamKey: "k")
                .serverURL
                == "rtmps://push.tiktok.com/rtmp/"
        )
        #expect(
            RTMPPusherConfiguration.twitter(streamKey: "k")
                .serverURL
                == "rtmps://prod-rtmp-publish.periscope.tv:443/"
        )
        #expect(
            RTMPPusherConfiguration.rumble(streamKey: "k")
                .serverURL
                == "rtmp://publish.rumble.com/live/"
        )
        #expect(
            RTMPPusherConfiguration.kick(streamKey: "k")
                .serverURL
                == "rtmp://fa723fc1b171.global-contribute.live-video.net/app/"
        )
        #expect(
            RTMPPusherConfiguration.linkedin(streamKey: "k")
                .serverURL
                == "rtmps://livein.linkedin.com:443/live/"
        )
        #expect(
            RTMPPusherConfiguration.trovo(streamKey: "k")
                .serverURL
                == "rtmp://livepush.trovo.live/live/"
        )
    }

    @Test("LinkedIn preset has correct configuration")
    func linkedinPreset() {
        let config = RTMPPusherConfiguration.linkedin(
            streamKey: "li_key"
        )
        #expect(
            config.serverURL
                == "rtmps://livein.linkedin.com:443/live/"
        )
        #expect(config.streamKey == "li_key")
        #expect(
            config.fullURL
                == "rtmps://livein.linkedin.com:443/live/li_key"
        )
        #expect(config.retryPolicy == .default)
    }

    @Test("Trovo preset has correct configuration")
    func trovoPreset() {
        let config = RTMPPusherConfiguration.trovo(
            streamKey: "trovo_key"
        )
        #expect(
            config.serverURL
                == "rtmp://livepush.trovo.live/live/"
        )
        #expect(config.streamKey == "trovo_key")
        #expect(
            config.fullURL
                == "rtmp://livepush.trovo.live/live/trovo_key"
        )
    }
}

// MARK: - SRT ARQ + Bonding

@Suite("SRT ARQ & Bonding — Completeness")
struct SRTARQBondingTests {

    @Test("SRTARQMode raw values match SRTKit")
    func arqModeRawValues() {
        #expect(SRTARQMode.always.rawValue == "always")
        #expect(SRTARQMode.onreq.rawValue == "onreq")
        #expect(SRTARQMode.never.rawValue == "never")
    }

    @Test("SRTARQMode CaseIterable with 3 cases")
    func arqModeCaseIterable() {
        #expect(SRTARQMode.allCases.count == 3)
    }

    @Test("SRTBondingMode raw values match SRTKit")
    func bondingModeRawValues() {
        #expect(SRTBondingMode.broadcast.rawValue == "broadcast")
        #expect(
            SRTBondingMode.mainBackup.rawValue == "mainBackup"
        )
        #expect(
            SRTBondingMode.balancing.rawValue == "balancing"
        )
    }

    @Test("SRTBondingMode CaseIterable with 3 cases")
    func bondingModeCaseIterable() {
        #expect(SRTBondingMode.allCases.count == 3)
    }

    @Test("SRTOptions with ARQ mode configured")
    func optionsWithARQMode() {
        let opts = SRTOptions(arqMode: .onreq)
        #expect(opts.arqMode == .onreq)
        #expect(opts.bondingMode == nil)
    }

    @Test("SRTOptions with bonding mode configured")
    func optionsWithBondingMode() {
        let opts = SRTOptions(bondingMode: .mainBackup)
        #expect(opts.bondingMode == .mainBackup)
        #expect(opts.arqMode == .always)
    }

    @Test("SRTOptions.default has correct ARQ and bonding defaults")
    func optionsDefaultARQBonding() {
        let opts = SRTOptions.default
        #expect(opts.arqMode == .always)
        #expect(opts.bondingMode == nil)
    }

    @Test("SRTOptions with FEC + ARQ combined")
    func optionsFECAndARQ() {
        let opts = SRTOptions(
            fecConfiguration: .smpte2022,
            arqMode: .never
        )
        #expect(opts.fecConfiguration == .smpte2022)
        #expect(opts.arqMode == .never)
    }
}

// MARK: - Icecast Auth + Preset

@Suite("Icecast Auth & Preset — Completeness")
struct IcecastAuthPresetCompletenessTests {

    @Test("IcecastAuthMode has all 6 cases")
    func authModeAllCases() {
        #expect(IcecastAuthMode.allCases.count == 6)
        #expect(IcecastAuthMode.basic.rawValue == "basic")
        #expect(IcecastAuthMode.digest.rawValue == "digest")
        #expect(IcecastAuthMode.bearer.rawValue == "bearer")
        #expect(
            IcecastAuthMode.queryToken.rawValue == "queryToken"
        )
        #expect(
            IcecastAuthMode.shoutcast.rawValue == "shoutcast"
        )
        #expect(
            IcecastAuthMode.shoutcastV2.rawValue == "shoutcastV2"
        )
    }

    @Test("IcecastCredentials with queryToken auth")
    func credentialsQueryToken() {
        let creds = IcecastCredentials(
            password: "token_value",
            authenticationMode: .queryToken
        )
        #expect(creds.authenticationMode == .queryToken)
    }

    @Test("IcecastCredentials with shoutcast auth")
    func credentialsShoutcast() {
        let creds = IcecastCredentials(
            password: "sc_pass",
            authenticationMode: .shoutcast
        )
        #expect(creds.authenticationMode == .shoutcast)
    }

    @Test("Broadcastify preset has correct configuration")
    func broadcastifyPreset() {
        let config = IcecastPusherConfiguration.broadcastify(
            host: "broadcast.example.com",
            token: "my_bearer_token"
        )
        #expect(
            config.serverURL == "http://broadcast.example.com:80"
        )
        #expect(config.mountpoint == "/stream.mp3")
        #expect(config.credentials.password == "my_bearer_token")
        #expect(
            config.credentials.authenticationMode == .bearer
        )
        #expect(config.contentType == .mp3)
        #expect(config.serverPreset == .broadcastify)
    }

    @Test("IcecastServerPreset has all 7 cases")
    func serverPresetAllCases() {
        #expect(IcecastServerPreset.allCases.count == 7)
        #expect(
            IcecastServerPreset.broadcastify.rawValue
                == "broadcastify"
        )
    }
}
