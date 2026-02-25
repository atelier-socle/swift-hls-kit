// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("SRTPusherConfiguration", .timeLimit(.minutes(1)))
struct SRTPusherConfigurationTests {

    @Test("Low latency preset")
    func lowLatencyPreset() {
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        #expect(config.host == "srt.example.com")
        #expect(config.port == 9000)
        #expect(config.options.latency == 50)
    }

    @Test("Encrypted preset")
    func encryptedPreset() {
        let config = SRTPusherConfiguration.encrypted(
            host: "srt.example.com",
            port: 9001,
            passphrase: "secret"
        )
        #expect(config.host == "srt.example.com")
        #expect(config.port == 9001)
        #expect(config.options.passphrase == "secret")
    }

    @Test("Custom configuration")
    func customConfig() {
        let config = SRTPusherConfiguration(
            host: "10.0.0.1",
            port: 4000,
            options: SRTOptions(latency: 200),
            retryPolicy: .aggressive
        )
        #expect(config.host == "10.0.0.1")
        #expect(config.port == 4000)
        #expect(config.options.latency == 200)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let b = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let c = SRTPusherConfiguration.lowLatency(
            host: "other.com"
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Default port for encrypted preset")
    func encryptedDefaultPort() {
        let config = SRTPusherConfiguration.encrypted(
            host: "srt.example.com",
            passphrase: "pass"
        )
        #expect(config.port == 9000)
    }
}
