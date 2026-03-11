// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("SRTPusherConfiguration — Presets")
struct SRTPusherConfigurationPresetsTests {

    // MARK: - New Presets (0.5.0)

    @Test("Rendezvous preset has correct mode and encryption")
    func rendezvousPreset() {
        let config = SRTPusherConfiguration.rendezvous(
            host: "srt.example.com",
            port: 9001,
            passphrase: "secret123"
        )
        #expect(config.host == "srt.example.com")
        #expect(config.port == 9001)
        #expect(config.options.mode == .rendezvous)
        #expect(config.options.passphrase == "secret123")
        #expect(config.options.congestionControl == .live)
    }

    @Test("High-throughput preset uses file congestion control")
    func highThroughputPreset() {
        let config = SRTPusherConfiguration.highThroughput(
            host: "srt.example.com"
        )
        #expect(config.host == "srt.example.com")
        #expect(config.port == 9000)
        #expect(config.options.congestionControl == .file)
        #expect(config.options.latency == 500)
        #expect(config.options.mode == .caller)
    }

    @Test("FEC preset enables forward error correction")
    func fecPreset() {
        let config = SRTPusherConfiguration.fec(
            host: "srt.example.com",
            layout: .staircase
        )
        #expect(config.host == "srt.example.com")
        #expect(config.port == 9000)
        #expect(config.options.fecConfiguration != nil)
        #expect(
            config.options.fecConfiguration?.layout == .staircase
        )
        #expect(config.options.fecConfiguration?.rows == 5)
        #expect(config.options.fecConfiguration?.columns == 5)
    }

    @Test("FEC preset with even layout")
    func fecPresetEvenLayout() {
        let config = SRTPusherConfiguration.fec(
            host: "srt.example.com",
            layout: .even
        )
        #expect(config.options.fecConfiguration?.layout == .even)
    }

    @Test("Broadcast preset has low latency and encryption")
    func broadcastPreset() {
        let config = SRTPusherConfiguration.broadcast(
            host: "srt.example.com",
            passphrase: "broadcast_key"
        )
        #expect(config.host == "srt.example.com")
        #expect(config.port == 9000)
        #expect(config.options.passphrase == "broadcast_key")
        #expect(config.options.latency == 50)
        #expect(config.options.congestionControl == .live)
        #expect(config.retryPolicy == .aggressive)
    }

    @Test("All new presets have sensible retry policy")
    func newPresetsRetryPolicy() {
        let rendezvous = SRTPusherConfiguration.rendezvous(
            host: "h", passphrase: "p"
        )
        let throughput = SRTPusherConfiguration.highThroughput(
            host: "h"
        )
        let fecConfig = SRTPusherConfiguration.fec(host: "h")
        let broadcast = SRTPusherConfiguration.broadcast(
            host: "h", passphrase: "p"
        )
        #expect(rendezvous.retryPolicy == .default)
        #expect(throughput.retryPolicy == .default)
        #expect(fecConfig.retryPolicy == .default)
        #expect(broadcast.retryPolicy == .aggressive)
    }

    // MARK: - Existing Presets (0.3.0 — Unchanged)

    @Test("Existing lowLatency preset unchanged")
    func lowLatencyPresetUnchanged() {
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.test.com"
        )
        #expect(config.host == "srt.test.com")
        #expect(config.port == 9000)
        #expect(config.options.latency == 50)
        #expect(config.retryPolicy == .aggressive)
        #expect(config.options.mode == .caller)
    }

    @Test("Existing encrypted preset unchanged")
    func encryptedPresetUnchanged() {
        let config = SRTPusherConfiguration.encrypted(
            host: "srt.test.com",
            passphrase: "my_secret"
        )
        #expect(config.host == "srt.test.com")
        #expect(config.port == 9000)
        #expect(config.options.passphrase == "my_secret")
        #expect(config.options.keyLength == .aes128)
        #expect(config.retryPolicy == .default)
    }
}
