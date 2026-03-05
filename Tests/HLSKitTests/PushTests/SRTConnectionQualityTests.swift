// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SRTConnectionQuality — Quality Assessment")
struct SRTConnectionQualityTests {

    @Test("Init stores all properties")
    func initStoresAllProperties() {
        let quality = SRTConnectionQuality(
            score: 0.92,
            grade: .excellent,
            rttMs: 15.0,
            packetLossRate: 0.001,
            recommendation: nil
        )
        #expect(quality.score == 0.92)
        #expect(quality.grade == .excellent)
        #expect(quality.rttMs == 15.0)
        #expect(quality.packetLossRate == 0.001)
        #expect(quality.recommendation == nil)
    }

    @Test("Init with recommendation")
    func initWithRecommendation() {
        let quality = SRTConnectionQuality(
            score: 0.35,
            grade: .poor,
            rttMs: 250.0,
            packetLossRate: 0.12,
            recommendation: "Reduce bitrate"
        )
        #expect(quality.recommendation == "Reduce bitrate")
    }

    @Test("Equatable — equal values")
    func equatableEqual() {
        let a = SRTConnectionQuality(
            score: 0.8,
            grade: .good,
            rttMs: 30.0,
            packetLossRate: 0.02
        )
        let b = SRTConnectionQuality(
            score: 0.8,
            grade: .good,
            rttMs: 30.0,
            packetLossRate: 0.02
        )
        #expect(a == b)
    }

    @Test("Equatable — different values")
    func equatableNotEqual() {
        let a = SRTConnectionQuality(
            score: 0.8,
            grade: .good,
            rttMs: 30.0,
            packetLossRate: 0.02
        )
        let b = SRTConnectionQuality(
            score: 0.5,
            grade: .fair,
            rttMs: 100.0,
            packetLossRate: 0.05
        )
        #expect(a != b)
    }

    @Test("toTransportQuality preserves score, grade, recommendation")
    func toTransportQualityConversion() {
        let date = Date()
        let quality = SRTConnectionQuality(
            score: 0.75,
            grade: .good,
            rttMs: 40.0,
            packetLossRate: 0.03,
            recommendation: "Consider FEC"
        )
        let transport = quality.toTransportQuality(timestamp: date)
        #expect(transport.score == 0.75)
        #expect(transport.grade == .good)
        #expect(transport.recommendation == "Consider FEC")
        #expect(transport.timestamp == date)
    }

    @Test("Sendable conformance in async context")
    func sendableConformance() async {
        let quality = SRTConnectionQuality(
            score: 0.25,
            grade: .critical,
            rttMs: 500.0,
            packetLossRate: 0.2,
            recommendation: "Connection unstable"
        )
        let result = await Task { quality }.value
        #expect(result.score == 0.25)
        #expect(result.grade == .critical)
    }
}
