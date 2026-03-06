// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Icecast Transport v2 Showcase

@Suite("Icecast Transport v2 Showcase — Auth Modes & Server Presets")
struct IcecastTransportV2ShowcaseTests {

    // MARK: - Auth Modes

    @Test("IcecastCredentials supports all six authentication modes")
    func allAuthModes() {
        let modes: [IcecastAuthMode] = [
            .basic, .digest, .bearer, .queryToken, .shoutcast, .shoutcastV2
        ]
        #expect(modes.count == 6)
        #expect(IcecastAuthMode.allCases.count == 6)

        let basicCreds = IcecastCredentials(password: "secret")
        #expect(basicCreds.username == "source")
        #expect(basicCreds.password == "secret")
        #expect(basicCreds.authenticationMode == .basic)

        let digestCreds = IcecastCredentials(
            username: "admin",
            password: "digest-pass",
            authenticationMode: .digest
        )
        #expect(digestCreds.username == "admin")
        #expect(digestCreds.authenticationMode == .digest)

        let bearerCreds = IcecastCredentials(
            password: "tok_abc123",
            authenticationMode: .bearer
        )
        #expect(bearerCreds.authenticationMode == .bearer)

        let queryCreds = IcecastCredentials(
            password: "qtoken",
            authenticationMode: .queryToken
        )
        #expect(queryCreds.authenticationMode == .queryToken)

        let shoutcastCreds = IcecastCredentials(
            password: "sc-pass",
            authenticationMode: .shoutcast
        )
        #expect(shoutcastCreds.authenticationMode == .shoutcast)

        let shoutcastV2Creds = IcecastCredentials(
            username: "dj",
            password: "sc2-pass",
            authenticationMode: .shoutcastV2
        )
        #expect(shoutcastV2Creds.username == "dj")
        #expect(shoutcastV2Creds.authenticationMode == .shoutcastV2)
    }

    // MARK: - Server Presets

    @Test("AzuraCast preset uses port 8000 and azuracast server preset")
    func azuracastPreset() {
        let config = IcecastPusherConfiguration.azuracast(
            host: "radio.example.com",
            password: "az-secret"
        )

        #expect(config.serverURL == "http://radio.example.com:8000")
        #expect(config.mountpoint == "/radio.mp3")
        #expect(config.serverPreset == .azuracast)
        #expect(config.contentType == .mp3)
        #expect(config.credentials.username == "source")
        #expect(config.credentials.password == "az-secret")
        #expect(config.credentials.authenticationMode == .basic)
    }

    @Test("LibreTime preset uses /main.mp3 mountpoint and libretime server preset")
    func libretimePreset() {
        let config = IcecastPusherConfiguration.libretime(
            host: "libre.example.org",
            password: "lt-pass"
        )

        #expect(config.serverURL == "http://libre.example.org:8000")
        #expect(config.mountpoint == "/main.mp3")
        #expect(config.serverPreset == .libretime)
        #expect(config.contentType == .mp3)
        #expect(config.credentials.password == "lt-pass")
    }

    @Test("SHOUTcast DNAS preset uses root mountpoint and shoutcastDNAS server preset")
    func shoutcastDNASPreset() {
        let config = IcecastPusherConfiguration.shoutcastDNAS(
            host: "shout.example.com",
            password: "sc-pass"
        )

        #expect(config.serverURL == "http://shout.example.com:8000")
        #expect(config.mountpoint == "/")
        #expect(config.serverPreset == .shoutcastDNAS)
        #expect(config.contentType == .mp3)
        #expect(config.credentials.password == "sc-pass")
    }

    @Test("Broadcastify preset uses bearer auth mode on port 80")
    func broadcastifyPreset() {
        let config = IcecastPusherConfiguration.broadcastify(
            host: "feed.broadcastify.com",
            token: "bf-token-xyz"
        )

        #expect(config.serverURL == "http://feed.broadcastify.com:80")
        #expect(config.mountpoint == "/stream.mp3")
        #expect(config.serverPreset == .broadcastify)
        #expect(config.credentials.password == "bf-token-xyz")
        #expect(config.credentials.authenticationMode == .bearer)
    }

    // MARK: - Stream Statistics

    @Test("IcecastStreamStatistics converts to TransportStatisticsSnapshot")
    func statisticsConversion() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let stats = IcecastStreamStatistics(
            bytesSent: 5_242_880,
            duration: 300.0,
            currentBitrate: 128_000.0,
            metadataUpdateCount: 5,
            reconnectionCount: 1
        )

        #expect(stats.bytesSent == 5_242_880)
        #expect(stats.duration == 300.0)
        #expect(stats.currentBitrate == 128_000.0)
        #expect(stats.metadataUpdateCount == 5)
        #expect(stats.reconnectionCount == 1)

        let snapshot = stats.toTransportStatisticsSnapshot(
            peakBitrate: 192_000.0,
            timestamp: timestamp
        )

        #expect(snapshot.bytesSent == 5_242_880)
        #expect(snapshot.duration == 300.0)
        #expect(snapshot.currentBitrate == 128_000.0)
        #expect(snapshot.peakBitrate == 192_000.0)
        #expect(snapshot.reconnectionCount == 1)
        #expect(snapshot.timestamp == timestamp)

        // When peakBitrate is nil, it defaults to currentBitrate.
        let defaultSnapshot = stats.toTransportStatisticsSnapshot()
        #expect(defaultSnapshot.peakBitrate == 128_000.0)
    }

    // MARK: - Metadata

    @Test("IcecastMetadata holds stream title and custom fields")
    func metadataFields() {
        let metadata = IcecastMetadata(
            streamTitle: "Episode 42 - Swift Concurrency Deep Dive",
            streamURL: "https://podcast.example.com",
            customFields: [
                "artist": "Tech Talks",
                "album": "Season 3"
            ]
        )

        #expect(metadata.streamTitle == "Episode 42 - Swift Concurrency Deep Dive")
        #expect(metadata.streamURL == "https://podcast.example.com")
        #expect(metadata.customFields.count == 2)
        #expect(metadata.customFields["artist"] == "Tech Talks")
        #expect(metadata.customFields["album"] == "Season 3")

        // Minimal metadata with defaults.
        let minimal = IcecastMetadata()
        #expect(minimal.streamTitle == nil)
        #expect(minimal.streamURL == nil)
        #expect(minimal.customFields.isEmpty)
    }

    // MARK: - Server Preset Enumeration

    @Test("IcecastServerPreset has all 7 known presets and is CaseIterable")
    func serverPresetCaseIterable() {
        let allPresets = IcecastServerPreset.allCases
        #expect(allPresets.count == 7)

        let expectedPresets: [IcecastServerPreset] = [
            .azuracast,
            .libretime,
            .radioCo,
            .centovaCast,
            .shoutcastDNAS,
            .icecastOfficial,
            .broadcastify
        ]

        for preset in expectedPresets {
            #expect(allPresets.contains(preset))
        }

        // Verify raw values are non-empty strings.
        for preset in allPresets {
            #expect(!preset.rawValue.isEmpty)
        }
    }
}
