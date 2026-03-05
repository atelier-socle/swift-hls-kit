// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock: Legacy 0.3.0 Transport (core methods only)

/// A mock that only implements the original 0.3.0 requirements.
/// Verifies that default implementations for v2 methods kick in.
private actor LegacySRTTransport: SRTTransport {
    private var connected = false

    var isConnected: Bool { connected }

    func connect(
        to host: String, port: Int, options: SRTOptions
    ) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(_ data: Data) async throws {}

    var networkStats: SRTNetworkStats? { nil }
}

// MARK: - Mock: Full v2 Transport

/// A mock that implements all v2 requirements.
private actor FullV2SRTTransport: SRTTransport {
    private var connected = false

    var isConnected: Bool { connected }

    func connect(
        to host: String, port: Int, options: SRTOptions
    ) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(_ data: Data) async throws {}

    var networkStats: SRTNetworkStats? { nil }

    var connectionQuality: SRTConnectionQuality? {
        SRTConnectionQuality(
            score: 0.88,
            grade: .good,
            rttMs: 25.0,
            packetLossRate: 0.005,
            recommendation: nil
        )
    }

    var isEncrypted: Bool { true }
}

// MARK: - Tests

@Suite("SRTTransport v2 — Protocol Evolution")
struct SRTTransportV2Tests {

    // MARK: - Default Implementations

    @Test("Legacy transport gets default nil connectionQuality")
    func legacyDefaultConnectionQuality() async {
        let transport = LegacySRTTransport()
        let quality = await transport.connectionQuality
        #expect(quality == nil)
    }

    @Test("Legacy transport gets default false isEncrypted")
    func legacyDefaultIsEncrypted() async {
        let transport = LegacySRTTransport()
        let encrypted = await transport.isEncrypted
        #expect(encrypted == false)
    }

    // MARK: - v2 Implementations

    @Test("v2 transport reports connectionQuality")
    func v2ConnectionQuality() async {
        let transport = FullV2SRTTransport()
        let quality = await transport.connectionQuality
        #expect(quality != nil)
        #expect(quality?.score == 0.88)
        #expect(quality?.grade == .good)
    }

    @Test("v2 transport reports isEncrypted")
    func v2IsEncrypted() async {
        let transport = FullV2SRTTransport()
        let encrypted = await transport.isEncrypted
        #expect(encrypted == true)
    }

    // MARK: - SRTOptions Backward Compatibility

    @Test("SRTOptions.default still works unchanged")
    func optionsDefaultUnchanged() {
        let opts = SRTOptions.default
        #expect(opts.passphrase == nil)
        #expect(opts.keyLength == .aes128)
        #expect(opts.latency == 120)
        #expect(opts.maxBandwidth == 0)
        #expect(opts.streamID == nil)
        #expect(opts.mode == .caller)
        #expect(opts.fecConfiguration == nil)
        #expect(opts.congestionControl == .live)
    }

    @Test("SRTOptions.encrypted() still works unchanged")
    func optionsEncryptedUnchanged() {
        let opts = SRTOptions.encrypted(
            passphrase: "secret", keyLength: .aes256
        )
        #expect(opts.passphrase == "secret")
        #expect(opts.keyLength == .aes256)
        #expect(opts.mode == .caller)
        #expect(opts.congestionControl == .live)
    }

    // MARK: - New SRTOptions Properties

    @Test("SRTOptions new properties configurable")
    func optionsNewProperties() {
        let opts = SRTOptions(
            mode: .rendezvous,
            fecConfiguration: .smpte2022,
            congestionControl: .file
        )
        #expect(opts.mode == .rendezvous)
        #expect(opts.fecConfiguration == .smpte2022)
        #expect(opts.congestionControl == .file)
    }

    // MARK: - New Types

    @Test("SRTConnectionMode raw values match SRTKit")
    func connectionModeRawValues() {
        #expect(SRTConnectionMode.caller.rawValue == "caller")
        #expect(SRTConnectionMode.listener.rawValue == "listener")
        #expect(
            SRTConnectionMode.rendezvous.rawValue == "rendezvous"
        )
    }

    @Test("SRTCongestionControl raw values match SRTKit")
    func congestionControlRawValues() {
        #expect(SRTCongestionControl.live.rawValue == "live")
        #expect(SRTCongestionControl.file.rawValue == "file")
    }

    @Test("SRTFECConfiguration.smpte2022 preset")
    func fecSmpte2022Preset() {
        let fec = SRTFECConfiguration.smpte2022
        #expect(fec.layout == .staircase)
        #expect(fec.rows == 5)
        #expect(fec.columns == 5)
    }

    @Test("SRTFECConfiguration.Layout raw values")
    func fecLayoutRawValues() {
        #expect(SRTFECConfiguration.Layout.even.rawValue == "even")
        #expect(
            SRTFECConfiguration.Layout.staircase.rawValue
                == "staircase"
        )
    }

    // MARK: - SRTNetworkStats

    @Test("SRTNetworkStats backward compat — existing 4 properties")
    func networkStatsBackwardCompat() {
        let stats = SRTNetworkStats(
            roundTripTime: 0.025,
            bandwidth: 5_000_000.0,
            packetLossRate: 0.01,
            retransmitRate: 0.005
        )
        #expect(stats.roundTripTime == 0.025)
        #expect(stats.bandwidth == 5_000_000.0)
        #expect(stats.packetLossRate == 0.01)
        #expect(stats.retransmitRate == 0.005)
        #expect(stats.sendBufferMs == 0.0)
        #expect(stats.receiveBufferMs == 0.0)
        #expect(stats.rttVariance == 0.0)
        #expect(stats.flowWindowSize == 0)
    }

    @Test("SRTNetworkStats new properties configurable")
    func networkStatsNewProperties() {
        let stats = SRTNetworkStats(
            roundTripTime: 0.030,
            bandwidth: 4_000_000.0,
            packetLossRate: 0.02,
            retransmitRate: 0.01,
            sendBufferMs: 120.0,
            receiveBufferMs: 80.0,
            rttVariance: 0.005,
            flowWindowSize: 8192
        )
        #expect(stats.sendBufferMs == 120.0)
        #expect(stats.receiveBufferMs == 80.0)
        #expect(stats.rttVariance == 0.005)
        #expect(stats.flowWindowSize == 8192)
    }

    // MARK: - Backward Compatibility

    @Test("Legacy transport conforms to SRTTransport")
    func legacyConformsToProtocol() async throws {
        let transport: any SRTTransport = LegacySRTTransport()
        try await transport.connect(
            to: "srt.test.com", port: 9000, options: .default
        )
        #expect(await transport.isConnected)
        await transport.disconnect()
        #expect(await transport.isConnected == false)
    }
}
