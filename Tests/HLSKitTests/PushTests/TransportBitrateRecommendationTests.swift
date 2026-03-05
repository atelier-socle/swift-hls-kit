// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TransportBitrateRecommendation — Bitrate Recommendations")
struct TransportBitrateRecommendationTests {

    // MARK: - Init

    @Test("Init stores all parameters")
    func initStoresAllParameters() {
        let now = Date()
        let rec = TransportBitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentEstimatedBitrate: 3_000_000,
            direction: .decrease,
            reason: "Congestion detected",
            confidence: 0.85,
            timestamp: now
        )
        #expect(rec.recommendedBitrate == 2_000_000)
        #expect(rec.currentEstimatedBitrate == 3_000_000)
        #expect(rec.direction == .decrease)
        #expect(rec.reason == "Congestion detected")
        #expect(rec.confidence == 0.85)
        #expect(rec.timestamp == now)
    }

    // MARK: - Direction

    @Test("Direction raw values")
    func directionRawValues() {
        #expect(TransportBitrateRecommendation.Direction.increase.rawValue == "increase")
        #expect(TransportBitrateRecommendation.Direction.decrease.rawValue == "decrease")
        #expect(TransportBitrateRecommendation.Direction.maintain.rawValue == "maintain")
    }

    @Test("Direction CaseIterable contains all 3 cases")
    func directionCaseIterable() {
        #expect(TransportBitrateRecommendation.Direction.allCases.count == 3)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatableConformance() {
        let now = Date()
        let a = TransportBitrateRecommendation(
            recommendedBitrate: 1_000_000,
            currentEstimatedBitrate: 1_500_000,
            direction: .maintain,
            reason: "Stable",
            confidence: 0.9,
            timestamp: now
        )
        let b = TransportBitrateRecommendation(
            recommendedBitrate: 1_000_000,
            currentEstimatedBitrate: 1_500_000,
            direction: .maintain,
            reason: "Stable",
            confidence: 0.9,
            timestamp: now
        )
        #expect(a == b)
    }

    // MARK: - Scenarios

    @Test("Decrease scenario due to congestion")
    func decreaseScenario() {
        let rec = TransportBitrateRecommendation(
            recommendedBitrate: 500_000,
            currentEstimatedBitrate: 800_000,
            direction: .decrease,
            reason: "Packet loss above 5%",
            confidence: 0.7,
            timestamp: Date()
        )
        #expect(rec.direction == .decrease)
        #expect(rec.recommendedBitrate < rec.currentEstimatedBitrate)
    }

    @Test("Increase scenario due to recovered bandwidth")
    func increaseScenario() {
        let rec = TransportBitrateRecommendation(
            recommendedBitrate: 4_000_000,
            currentEstimatedBitrate: 5_000_000,
            direction: .increase,
            reason: "Bandwidth recovered",
            confidence: 0.6,
            timestamp: Date()
        )
        #expect(rec.direction == .increase)
    }

    @Test("Confidence edge case at 0.0")
    func confidenceZero() {
        let rec = TransportBitrateRecommendation(
            recommendedBitrate: 1_000_000,
            currentEstimatedBitrate: 1_000_000,
            direction: .maintain,
            reason: "Insufficient data",
            confidence: 0.0,
            timestamp: Date()
        )
        #expect(rec.confidence == 0.0)
    }

    @Test("Confidence edge case at 1.0")
    func confidenceOne() {
        let rec = TransportBitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentEstimatedBitrate: 2_500_000,
            direction: .decrease,
            reason: "High confidence measurement",
            confidence: 1.0,
            timestamp: Date()
        )
        #expect(rec.confidence == 1.0)
    }
}
