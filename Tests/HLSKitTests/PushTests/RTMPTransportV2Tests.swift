// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock: Legacy 0.3.0 Transport (core methods only)

/// A mock that only implements the original 0.3.0 requirements.
/// Verifies that default implementations for v2 methods kick in.
private actor LegacyRTMPTransport: RTMPTransport {
    private var connected = false

    var isConnected: Bool { connected }

    func connect(to url: String) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(
        data: Data, timestamp: UInt32, type: FLVTagType
    ) async throws {}
}

// MARK: - Mock: Full v2 Transport

/// A mock that implements all v2 requirements.
private actor FullV2RTMPTransport: RTMPTransport {
    private var connected = false
    private(set) var lastMetadata: [String: String]?

    var isConnected: Bool { connected }

    func connect(to url: String) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(
        data: Data, timestamp: UInt32, type: FLVTagType
    ) async throws {}

    func sendMetadata(_ metadata: [String: String]) async throws {
        lastMetadata = metadata
    }

    var serverCapabilities: RTMPServerCapabilities? {
        RTMPServerCapabilities(
            supportsEnhancedRTMP: true,
            serverVersion: "TestServer/1.0",
            supportedCodecs: ["hvc1", "av01"]
        )
    }
}

// MARK: - Tests

@Suite("RTMPTransport v2 — Protocol Evolution")
struct RTMPTransportV2Tests {

    // MARK: - FLVTagType Unchanged

    @Test("FLVTagType values unchanged from 0.3.0")
    func flvTagTypeUnchanged() {
        #expect(FLVTagType.audio.rawValue == 8)
        #expect(FLVTagType.video.rawValue == 9)
        #expect(FLVTagType.scriptData.rawValue == 18)
    }

    // MARK: - Default Implementations

    @Test("Legacy transport gets default sendMetadata no-op")
    func legacyDefaultSendMetadata() async throws {
        let transport = LegacyRTMPTransport()
        // Should not throw — default is a no-op.
        try await transport.sendMetadata(["title": "Test"])
    }

    @Test("Legacy transport gets default nil serverCapabilities")
    func legacyDefaultServerCapabilities() async {
        let transport = LegacyRTMPTransport()
        let caps = await transport.serverCapabilities
        #expect(caps == nil)
    }

    // MARK: - v2 Implementations

    @Test("v2 transport sends metadata")
    func v2SendsMetadata() async throws {
        let transport = FullV2RTMPTransport()
        try await transport.sendMetadata(["title": "Live Stream"])
        let last = await transport.lastMetadata
        #expect(last == ["title": "Live Stream"])
    }

    @Test("v2 transport reports server capabilities")
    func v2ServerCapabilities() async {
        let transport = FullV2RTMPTransport()
        let caps = await transport.serverCapabilities
        #expect(caps != nil)
        #expect(caps?.supportsEnhancedRTMP == true)
        #expect(caps?.serverVersion == "TestServer/1.0")
        #expect(caps?.supportedCodecs.contains("hvc1") == true)
    }

    // MARK: - Backward Compatibility

    @Test("Legacy transport conforms to RTMPTransport")
    func legacyConformsToProtocol() async throws {
        let transport: any RTMPTransport = LegacyRTMPTransport()
        try await transport.connect(to: "rtmp://test/app/key")
        #expect(await transport.isConnected)
        await transport.disconnect()
        #expect(await transport.isConnected == false)
    }

    @Test("v2 transport conforms to RTMPTransport")
    func v2ConformsToProtocol() async throws {
        let transport: any RTMPTransport = FullV2RTMPTransport()
        try await transport.connect(to: "rtmp://test/app/key")
        #expect(await transport.isConnected)
    }

    @Test("Both transports can be used interchangeably")
    func interchangeableUsage() async throws {
        let transports: [any RTMPTransport] = [
            LegacyRTMPTransport(),
            FullV2RTMPTransport()
        ]
        for transport in transports {
            try await transport.connect(to: "rtmp://test/key")
            #expect(await transport.isConnected)
            // Both support sendMetadata (default or overridden).
            try await transport.sendMetadata(["key": "value"])
            await transport.disconnect()
        }
    }

    @Test("Legacy transport core methods still work")
    func legacyCoreMethodsWork() async throws {
        let transport = LegacyRTMPTransport()
        #expect(await transport.isConnected == false)
        try await transport.connect(to: "rtmp://server/app/key")
        #expect(await transport.isConnected)
        try await transport.send(
            data: Data([0x01, 0x02]),
            timestamp: 1000,
            type: .video
        )
        await transport.disconnect()
        #expect(await transport.isConnected == false)
    }
}
