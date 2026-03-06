// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock: Legacy 0.3.0 Transport (core methods only)

/// A mock that only implements the original 0.3.0 requirements.
/// Verifies that default implementations for v2 methods kick in.
private actor LegacyIcecastTransport: IcecastTransport {
    private var connected = false

    var isConnected: Bool { connected }

    func connect(
        to url: String,
        credentials: IcecastCredentials,
        mountpoint: String
    ) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(_ data: Data) async throws {}

    func updateMetadata(
        _ metadata: IcecastMetadata
    ) async throws {}
}

// MARK: - Mock: Full v2 Transport

/// A mock that implements all v2 requirements.
private actor FullV2IcecastTransport: IcecastTransport {
    private var connected = false

    var isConnected: Bool { connected }

    func connect(
        to url: String,
        credentials: IcecastCredentials,
        mountpoint: String
    ) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(_ data: Data) async throws {}

    func updateMetadata(
        _ metadata: IcecastMetadata
    ) async throws {}

    var serverVersion: String? { "Icecast 2.5.0" }

    var streamStatistics: IcecastStreamStatistics? {
        IcecastStreamStatistics(
            bytesSent: 50_000,
            duration: 120.0,
            currentBitrate: 128_000.0,
            metadataUpdateCount: 3,
            reconnectionCount: 0
        )
    }
}

// MARK: - Tests

@Suite("IcecastTransport v2 — Protocol Evolution")
struct IcecastTransportV2Tests {

    // MARK: - Default Implementations

    @Test("Legacy transport gets default nil serverVersion")
    func legacyDefaultServerVersion() async {
        let transport = LegacyIcecastTransport()
        let version = await transport.serverVersion
        #expect(version == nil)
    }

    @Test("Legacy transport gets default nil streamStatistics")
    func legacyDefaultStreamStatistics() async {
        let transport = LegacyIcecastTransport()
        let stats = await transport.streamStatistics
        #expect(stats == nil)
    }

    // MARK: - v2 Implementations

    @Test("v2 transport reports serverVersion")
    func v2ServerVersion() async {
        let transport = FullV2IcecastTransport()
        let version = await transport.serverVersion
        #expect(version == "Icecast 2.5.0")
    }

    @Test("v2 transport reports streamStatistics")
    func v2StreamStatistics() async {
        let transport = FullV2IcecastTransport()
        let stats = await transport.streamStatistics
        #expect(stats != nil)
        #expect(stats?.bytesSent == 50_000)
        #expect(stats?.currentBitrate == 128_000.0)
        #expect(stats?.metadataUpdateCount == 3)
    }

    // MARK: - IcecastCredentials

    @Test("IcecastCredentials existing init defaults to basic auth")
    func credentialsDefaultAuth() {
        let creds = IcecastCredentials(password: "secret")
        #expect(creds.username == "source")
        #expect(creds.password == "secret")
        #expect(creds.authenticationMode == .basic)
    }

    @Test("IcecastCredentials with explicit auth mode")
    func credentialsExplicitAuth() {
        let creds = IcecastCredentials(
            username: "admin",
            password: "token123",
            authenticationMode: .bearer
        )
        #expect(creds.username == "admin")
        #expect(creds.authenticationMode == .bearer)
    }

    @Test("IcecastAuthMode raw values and all cases")
    func authModeRawValues() {
        #expect(IcecastAuthMode.basic.rawValue == "basic")
        #expect(IcecastAuthMode.digest.rawValue == "digest")
        #expect(IcecastAuthMode.bearer.rawValue == "bearer")
        #expect(IcecastAuthMode.allCases.count == 3)
    }

    // MARK: - IcecastMetadata Unchanged

    @Test("IcecastMetadata unchanged from 0.3.0")
    func metadataUnchanged() {
        let meta = IcecastMetadata(
            streamTitle: "Test Song",
            streamURL: "http://example.com",
            customFields: ["artist": "Test"]
        )
        #expect(meta.streamTitle == "Test Song")
        #expect(meta.streamURL == "http://example.com")
        #expect(meta.customFields["artist"] == "Test")
    }

    // MARK: - Backward Compatibility

    @Test("Legacy transport conforms to IcecastTransport")
    func legacyConformsToProtocol() async throws {
        let transport: any IcecastTransport =
            LegacyIcecastTransport()
        try await transport.connect(
            to: "http://icecast.test:8000",
            credentials: IcecastCredentials(password: "pass"),
            mountpoint: "/live.mp3"
        )
        #expect(await transport.isConnected)
        await transport.disconnect()
        #expect(await transport.isConnected == false)
    }
}
