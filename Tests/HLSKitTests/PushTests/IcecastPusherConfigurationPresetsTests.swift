// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("IcecastPusherConfiguration — Server Presets")
struct IcecastPusherConfigurationPresetsTests {

    // MARK: - New Presets (0.6.0)

    @Test("AzuraCast preset has correct defaults")
    func azuracastPreset() {
        let config = IcecastPusherConfiguration.azuracast(
            host: "radio.example.com",
            password: "azura_pass"
        )
        #expect(config.serverURL == "http://radio.example.com:8000")
        #expect(config.mountpoint == "/radio.mp3")
        #expect(config.credentials.password == "azura_pass")
        #expect(config.credentials.username == "source")
        #expect(config.credentials.authenticationMode == .basic)
        #expect(config.contentType == .mp3)
        #expect(config.serverPreset == .azuracast)
    }

    @Test("AzuraCast preset with custom mountpoint")
    func azuracastCustomMount() {
        let config = IcecastPusherConfiguration.azuracast(
            host: "radio.example.com",
            mountpoint: "/custom.mp3",
            password: "pass"
        )
        #expect(config.mountpoint == "/custom.mp3")
    }

    @Test("LibreTime preset has correct defaults")
    func libretimePreset() {
        let config = IcecastPusherConfiguration.libretime(
            host: "libre.example.com",
            password: "libre_pass"
        )
        #expect(
            config.serverURL == "http://libre.example.com:8000"
        )
        #expect(config.mountpoint == "/main.mp3")
        #expect(config.credentials.password == "libre_pass")
        #expect(config.contentType == .mp3)
        #expect(config.serverPreset == .libretime)
    }

    @Test("ShoutcastDNAS preset has correct defaults")
    func shoutcastDNASPreset() {
        let config = IcecastPusherConfiguration.shoutcastDNAS(
            host: "shoutcast.example.com",
            password: "sc_pass"
        )
        #expect(
            config.serverURL
                == "http://shoutcast.example.com:8000"
        )
        #expect(config.mountpoint == "/")
        #expect(config.credentials.password == "sc_pass")
        #expect(config.contentType == .mp3)
        #expect(config.serverPreset == .shoutcastDNAS)
    }

    // MARK: - IcecastServerPreset Enum

    @Test("IcecastServerPreset has all 7 cases and CaseIterable")
    func serverPresetAllCases() {
        #expect(IcecastServerPreset.allCases.count == 7)
        #expect(
            IcecastServerPreset.azuracast.rawValue == "azuracast"
        )
        #expect(
            IcecastServerPreset.libretime.rawValue == "libretime"
        )
        #expect(IcecastServerPreset.radioCo.rawValue == "radioCo")
        #expect(
            IcecastServerPreset.centovaCast.rawValue
                == "centovaCast"
        )
        #expect(
            IcecastServerPreset.shoutcastDNAS.rawValue
                == "shoutcastDNAS"
        )
        #expect(
            IcecastServerPreset.icecastOfficial.rawValue
                == "icecastOfficial"
        )
    }

    @Test("All new presets have sensible retry policy")
    func newPresetsRetryPolicy() {
        let azura = IcecastPusherConfiguration.azuracast(
            host: "h", password: "p"
        )
        let libre = IcecastPusherConfiguration.libretime(
            host: "h", password: "p"
        )
        let shoutcast = IcecastPusherConfiguration.shoutcastDNAS(
            host: "h", password: "p"
        )
        #expect(azura.retryPolicy == .default)
        #expect(libre.retryPolicy == .default)
        #expect(shoutcast.retryPolicy == .default)
    }

    // MARK: - Existing Presets (0.3.0 — Unchanged)

    @Test("Existing mp3Stream preset unchanged")
    func mp3StreamPresetUnchanged() {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "my_pass"
        )
        #expect(config.serverURL == "http://icecast.test:8000")
        #expect(config.mountpoint == "/live.mp3")
        #expect(config.credentials.password == "my_pass")
        #expect(config.contentType == .mp3)
        #expect(config.serverPreset == nil)
    }

    @Test("Existing aacStream preset unchanged")
    func aacStreamPresetUnchanged() {
        let config = IcecastPusherConfiguration.aacStream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.aac",
            password: "my_pass"
        )
        #expect(config.contentType == .aac)
        #expect(config.serverPreset == nil)
    }
}
