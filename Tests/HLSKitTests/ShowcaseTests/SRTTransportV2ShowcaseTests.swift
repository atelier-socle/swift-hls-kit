// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - SRT Transport v2 Showcase

@Suite("SRT Transport v2 Showcase — Modes, FEC & Quality")
struct SRTTransportV2ShowcaseTests {

    // MARK: - Connection Modes

    @Test("SRTOptions supports all connection modes: caller, listener, rendezvous")
    func connectionModes() {
        let caller = SRTOptions(mode: .caller)
        #expect(caller.mode == .caller)
        #expect(caller.mode.rawValue == "caller")

        let listener = SRTOptions(mode: .listener)
        #expect(listener.mode == .listener)
        #expect(listener.mode.rawValue == "listener")

        let rendezvous = SRTOptions(mode: .rendezvous)
        #expect(rendezvous.mode == .rendezvous)
        #expect(rendezvous.mode.rawValue == "rendezvous")

        // Default mode is .caller
        let defaults = SRTOptions()
        #expect(defaults.mode == .caller)

        // All cases
        #expect(SRTConnectionMode.allCases.count == 3)
    }

    // MARK: - FEC Configuration

    @Test("SRTFECConfiguration.smpte2022 uses staircase layout with 5x5 matrix")
    func fecSMPTE2022() {
        let fec = SRTFECConfiguration.smpte2022

        #expect(fec.layout == .staircase)
        #expect(fec.rows == 5)
        #expect(fec.columns == 5)

        // Custom FEC with even layout
        let custom = SRTFECConfiguration(layout: .even, rows: 10, columns: 8)
        #expect(custom.layout == .even)
        #expect(custom.rows == 10)
        #expect(custom.columns == 8)

        // Layout cases
        #expect(SRTFECConfiguration.Layout.allCases.count == 2)
        #expect(SRTFECConfiguration.Layout.even.rawValue == "even")
        #expect(SRTFECConfiguration.Layout.staircase.rawValue == "staircase")

        // Options with FEC enabled
        let options = SRTOptions(fecConfiguration: .smpte2022)
        let fecConfig = options.fecConfiguration
        #expect(fecConfig == .smpte2022)
    }

    // MARK: - Congestion Control

    @Test("SRTCongestionControl: .live for real-time, .file for throughput")
    func congestionControl() {
        #expect(SRTCongestionControl.live.rawValue == "live")
        #expect(SRTCongestionControl.file.rawValue == "file")
        #expect(SRTCongestionControl.allCases.count == 2)

        // Default is .live
        let defaults = SRTOptions()
        #expect(defaults.congestionControl == .live)

        // File mode for bulk transfer
        let fileMode = SRTOptions(congestionControl: .file)
        #expect(fileMode.congestionControl == .file)
    }

    // MARK: - Network Stats v2

    @Test("SRTNetworkStats with v2 fields: buffers, RTT variance, flow window")
    func networkStatsV2() {
        let stats = SRTNetworkStats(
            roundTripTime: 0.025,
            bandwidth: 5_000_000.0,
            packetLossRate: 0.001,
            retransmitRate: 0.002,
            sendBufferMs: 45.0,
            receiveBufferMs: 120.0,
            rttVariance: 0.003,
            flowWindowSize: 8192
        )

        #expect(stats.roundTripTime == 0.025)
        #expect(stats.bandwidth == 5_000_000.0)
        #expect(stats.packetLossRate == 0.001)
        #expect(stats.retransmitRate == 0.002)
        #expect(stats.sendBufferMs == 45.0)
        #expect(stats.receiveBufferMs == 120.0)
        #expect(stats.rttVariance == 0.003)
        #expect(stats.flowWindowSize == 8192)

        // v2 fields default to zero
        let minimal = SRTNetworkStats(
            roundTripTime: 0.050,
            bandwidth: 1_000_000.0,
            packetLossRate: 0.0,
            retransmitRate: 0.0
        )
        #expect(minimal.sendBufferMs == 0.0)
        #expect(minimal.receiveBufferMs == 0.0)
        #expect(minimal.rttVariance == 0.0)
        #expect(minimal.flowWindowSize == 0)
    }

    // MARK: - Connection Quality & Conversion

    @Test("SRTConnectionQuality converts to TransportQuality via .toTransportQuality()")
    func connectionQualityConversion() {
        let srtQuality = SRTConnectionQuality(
            score: 0.88,
            grade: .good,
            rttMs: 25.0,
            packetLossRate: 0.001,
            recommendation: "Connection stable"
        )

        #expect(srtQuality.score == 0.88)
        #expect(srtQuality.grade == .good)
        #expect(srtQuality.rttMs == 25.0)
        #expect(srtQuality.packetLossRate == 0.001)
        #expect(srtQuality.recommendation == "Connection stable")

        // Convert to unified TransportQuality
        let now = Date()
        let transportQuality = srtQuality.toTransportQuality(timestamp: now)
        #expect(transportQuality.score == 0.88)
        #expect(transportQuality.grade == .good)
        #expect(transportQuality.recommendation == "Connection stable")
        #expect(transportQuality.timestamp == now)
    }

    // MARK: - ARQ Mode

    @Test("SRTARQMode cases: always, onreq, never")
    func arqModeCases() {
        #expect(SRTARQMode.always.rawValue == "always")
        #expect(SRTARQMode.onreq.rawValue == "onreq")
        #expect(SRTARQMode.never.rawValue == "never")
        #expect(SRTARQMode.allCases.count == 3)

        // Default is .always
        let defaults = SRTOptions()
        #expect(defaults.arqMode == .always)

        // FEC-only mode disables retransmission
        let fecOnly = SRTOptions(
            fecConfiguration: .smpte2022,
            arqMode: .never
        )
        #expect(fecOnly.arqMode == .never)
        #expect(fecOnly.fecConfiguration == .smpte2022)
    }

    // MARK: - Bonding Mode

    @Test("SRTBondingMode cases: broadcast, mainBackup, balancing")
    func bondingModeCases() {
        #expect(SRTBondingMode.broadcast.rawValue == "broadcast")
        #expect(SRTBondingMode.mainBackup.rawValue == "mainBackup")
        #expect(SRTBondingMode.balancing.rawValue == "balancing")
        #expect(SRTBondingMode.allCases.count == 3)

        // Default is nil (no bonding)
        let defaults = SRTOptions()
        #expect(defaults.bondingMode == nil)

        // Broadcast bonding: send on all links
        let bonded = SRTOptions(bondingMode: .broadcast)
        #expect(bonded.bondingMode == .broadcast)
    }

    // MARK: - Pusher Configuration Presets

    @Test("SRTPusherConfiguration presets: lowLatency, encrypted, rendezvous")
    func pusherConfigurationPresets() {
        // Low latency: 50ms latency, aggressive retry
        let lowLatency = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com", port: 9000
        )
        #expect(lowLatency.host == "srt.example.com")
        #expect(lowLatency.port == 9000)
        #expect(lowLatency.options.latency == 50)
        #expect(lowLatency.retryPolicy == .aggressive)

        // Encrypted: passphrase-based AES
        let encrypted = SRTPusherConfiguration.encrypted(
            host: "secure.example.com",
            port: 9001,
            passphrase: "my-secret-key"
        )
        #expect(encrypted.host == "secure.example.com")
        #expect(encrypted.port == 9001)
        #expect(encrypted.options.passphrase == "my-secret-key")

        // Rendezvous: NAT traversal with encryption
        let rendezvous = SRTPusherConfiguration.rendezvous(
            host: "peer.example.com",
            port: 9002,
            passphrase: "shared-secret"
        )
        #expect(rendezvous.host == "peer.example.com")
        #expect(rendezvous.port == 9002)
        #expect(rendezvous.options.mode == .rendezvous)
        #expect(rendezvous.options.passphrase == "shared-secret")

        // Default port is 9000
        let defaultPort = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        #expect(defaultPort.port == 9000)
    }
}
