// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("SRTOptions & SRTNetworkStats", .timeLimit(.minutes(1)))
struct SRTOptionsTests {

    @Test("Default options")
    func defaultOptions() {
        let opts = SRTOptions.default
        #expect(opts.passphrase == nil)
        #expect(opts.keyLength == .aes128)
        #expect(opts.latency == 120)
        #expect(opts.maxBandwidth == 0)
        #expect(opts.streamID == nil)
    }

    @Test("Encrypted options")
    func encryptedOptions() {
        let opts = SRTOptions.encrypted(
            passphrase: "secret123",
            keyLength: .aes256
        )
        #expect(opts.passphrase == "secret123")
        #expect(opts.keyLength == .aes256)
    }

    @Test("Key lengths raw values")
    func keyLengthValues() {
        #expect(SRTOptions.KeyLength.aes128.rawValue == 16)
        #expect(SRTOptions.KeyLength.aes192.rawValue == 24)
        #expect(SRTOptions.KeyLength.aes256.rawValue == 32)
    }

    @Test("SRTNetworkStats creation")
    func networkStats() {
        let stats = SRTNetworkStats(
            roundTripTime: 0.025,
            bandwidth: 5_000_000,
            packetLossRate: 0.01,
            retransmitRate: 0.005
        )
        #expect(stats.roundTripTime == 0.025)
        #expect(stats.bandwidth == 5_000_000)
        #expect(stats.packetLossRate == 0.01)
        #expect(stats.retransmitRate == 0.005)
    }

    @Test("Equatable conformance for SRTOptions")
    func equatable() {
        let a = SRTOptions.encrypted(passphrase: "abc")
        let b = SRTOptions.encrypted(passphrase: "abc")
        let c = SRTOptions.encrypted(passphrase: "xyz")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("SRTNetworkStats Equatable")
    func networkStatsEquatable() {
        let a = SRTNetworkStats(
            roundTripTime: 0.01, bandwidth: 1000,
            packetLossRate: 0, retransmitRate: 0
        )
        let b = SRTNetworkStats(
            roundTripTime: 0.01, bandwidth: 1000,
            packetLossRate: 0, retransmitRate: 0
        )
        #expect(a == b)
    }
}
