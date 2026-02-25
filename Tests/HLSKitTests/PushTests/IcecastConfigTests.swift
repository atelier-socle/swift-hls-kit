// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("Icecast Configuration & Models", .timeLimit(.minutes(1)))
struct IcecastConfigTests {

    // MARK: - IcecastCredentials

    @Test("Credentials default username is source")
    func credentialsDefaultUsername() {
        let creds = IcecastCredentials(password: "hackme")
        #expect(creds.username == "source")
        #expect(creds.password == "hackme")
    }

    @Test("Credentials custom username")
    func credentialsCustomUsername() {
        let creds = IcecastCredentials(
            username: "admin", password: "pass"
        )
        #expect(creds.username == "admin")
    }

    // MARK: - IcecastMetadata

    @Test("Metadata creation")
    func metadataCreation() {
        let meta = IcecastMetadata(
            streamTitle: "My Song",
            streamURL: "https://example.com",
            customFields: ["genre": "jazz"]
        )
        #expect(meta.streamTitle == "My Song")
        #expect(meta.streamURL == "https://example.com")
        #expect(meta.customFields["genre"] == "jazz")
    }

    @Test("Metadata defaults")
    func metadataDefaults() {
        let meta = IcecastMetadata()
        #expect(meta.streamTitle == nil)
        #expect(meta.streamURL == nil)
        #expect(meta.customFields.isEmpty)
    }

    // MARK: - AudioContentType

    @Test("Content type raw values")
    func contentTypeRawValues() {
        #expect(
            IcecastPusherConfiguration.AudioContentType
                .mp3.rawValue == "audio/mpeg"
        )
        #expect(
            IcecastPusherConfiguration.AudioContentType
                .aac.rawValue == "audio/aac"
        )
        #expect(
            IcecastPusherConfiguration.AudioContentType
                .ogg.rawValue == "application/ogg"
        )
    }

    // MARK: - IcecastPusherConfiguration

    @Test("MP3 stream preset")
    func mp3StreamPreset() {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://icecast.example.com",
            mountpoint: "/live.mp3",
            password: "hackme"
        )
        #expect(
            config.serverURL == "https://icecast.example.com"
        )
        #expect(config.mountpoint == "/live.mp3")
        #expect(config.credentials.password == "hackme")
        #expect(config.contentType == .mp3)
    }

    @Test("AAC stream preset")
    func aacStreamPreset() {
        let config = IcecastPusherConfiguration.aacStream(
            serverURL: "https://icecast.example.com",
            mountpoint: "/live.aac",
            password: "secret"
        )
        #expect(config.contentType == .aac)
        #expect(config.credentials.username == "source")
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://a.com",
            mountpoint: "/live",
            password: "pass"
        )
        let b = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://a.com",
            mountpoint: "/live",
            password: "pass"
        )
        let c = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://b.com",
            mountpoint: "/live",
            password: "pass"
        )
        #expect(a == b)
        #expect(a != c)
    }
}
