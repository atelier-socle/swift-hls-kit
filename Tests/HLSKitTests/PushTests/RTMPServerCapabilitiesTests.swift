// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("RTMPServerCapabilities — Server Capabilities")
struct RTMPServerCapabilitiesTests {

    @Test("Init stores all parameters")
    func initStoresAllParameters() {
        let caps = RTMPServerCapabilities(
            supportsEnhancedRTMP: true,
            serverVersion: "nginx-rtmp/1.2",
            supportedCodecs: ["hvc1", "av01", "mp4a"]
        )
        #expect(caps.supportsEnhancedRTMP)
        #expect(caps.serverVersion == "nginx-rtmp/1.2")
        #expect(caps.supportedCodecs.count == 3)
        #expect(caps.supportedCodecs.contains("hvc1"))
    }

    @Test("Equatable conformance")
    func equatableConformance() {
        let a = RTMPServerCapabilities(
            supportsEnhancedRTMP: false,
            serverVersion: "Wowza/4.8",
            supportedCodecs: []
        )
        let b = RTMPServerCapabilities(
            supportsEnhancedRTMP: false,
            serverVersion: "Wowza/4.8",
            supportedCodecs: []
        )
        #expect(a == b)
    }

    @Test("Empty codecs set")
    func emptyCodecsSet() {
        let caps = RTMPServerCapabilities(
            supportsEnhancedRTMP: false,
            serverVersion: nil,
            supportedCodecs: []
        )
        #expect(caps.supportedCodecs.isEmpty)
        #expect(!caps.supportsEnhancedRTMP)
    }

    @Test("Nil server version")
    func nilServerVersion() {
        let caps = RTMPServerCapabilities(
            supportsEnhancedRTMP: true,
            serverVersion: nil,
            supportedCodecs: ["hvc1"]
        )
        #expect(caps.serverVersion == nil)
    }

    @Test("Sendable conformance in async context")
    func sendableInAsyncContext() async {
        let caps = RTMPServerCapabilities(
            supportsEnhancedRTMP: true,
            serverVersion: "Wowza/4.8",
            supportedCodecs: ["hvc1", "av01"]
        )
        let task = Task { caps }
        let result = await task.value
        #expect(result.supportsEnhancedRTMP)
    }
}
