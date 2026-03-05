// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TransportQuality — Quality Measurement")
struct TransportQualityTests {

    // MARK: - Init

    @Test("Init stores all parameters")
    func initStoresAllParameters() {
        let now = Date()
        let quality = TransportQuality(
            score: 0.85,
            grade: .good,
            recommendation: "Consider increasing bitrate",
            timestamp: now
        )
        #expect(quality.score == 0.85)
        #expect(quality.grade == .good)
        #expect(quality.recommendation == "Consider increasing bitrate")
        #expect(quality.timestamp == now)
    }

    @Test("Init with nil recommendation")
    func initWithNilRecommendation() {
        let quality = TransportQuality(
            score: 0.95,
            grade: .excellent,
            recommendation: nil,
            timestamp: Date()
        )
        #expect(quality.recommendation == nil)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatableConformance() {
        let now = Date()
        let a = TransportQuality(
            score: 0.5, grade: .fair, recommendation: nil, timestamp: now
        )
        let b = TransportQuality(
            score: 0.5, grade: .fair, recommendation: nil, timestamp: now
        )
        #expect(a == b)
    }

    // MARK: - Sendable

    @Test("Sendable conformance in async context")
    func sendableInAsyncContext() async {
        let quality = TransportQuality(
            score: 0.8, grade: .good, recommendation: nil, timestamp: Date()
        )
        let task = Task { quality }
        let result = await task.value
        #expect(result.score == 0.8)
    }
}

@Suite("TransportQualityGrade — Grade Thresholds")
struct TransportQualityGradeTests {

    // MARK: - Init from Score

    @Test(
        "Init from score maps to correct grade",
        arguments: [
            (0.0, TransportQualityGrade.critical),
            (0.3, TransportQualityGrade.critical),
            (0.31, TransportQualityGrade.poor),
            (0.5, TransportQualityGrade.poor),
            (0.51, TransportQualityGrade.fair),
            (0.7, TransportQualityGrade.fair),
            (0.71, TransportQualityGrade.good),
            (0.9, TransportQualityGrade.good),
            (0.91, TransportQualityGrade.excellent),
            (1.0, TransportQualityGrade.excellent)
        ]
    )
    func initFromScore(score: Double, expected: TransportQualityGrade) {
        #expect(TransportQualityGrade(score: score) == expected)
    }

    // MARK: - Comparable

    @Test("Comparable ordering: excellent > good > fair > poor > critical")
    func comparableOrdering() {
        #expect(TransportQualityGrade.excellent > .good)
        #expect(TransportQualityGrade.good > .fair)
        #expect(TransportQualityGrade.fair > .poor)
        #expect(TransportQualityGrade.poor > .critical)
        #expect(TransportQualityGrade.critical < .excellent)
    }

    // MARK: - CaseIterable

    @Test("CaseIterable contains all 5 grades")
    func caseIterableContainsAllGrades() {
        #expect(TransportQualityGrade.allCases.count == 5)
        #expect(TransportQualityGrade.allCases.contains(.excellent))
        #expect(TransportQualityGrade.allCases.contains(.critical))
    }

    // MARK: - Raw Values

    @Test("Raw value strings match case names")
    func rawValueStrings() {
        #expect(TransportQualityGrade.excellent.rawValue == "excellent")
        #expect(TransportQualityGrade.good.rawValue == "good")
        #expect(TransportQualityGrade.fair.rawValue == "fair")
        #expect(TransportQualityGrade.poor.rawValue == "poor")
        #expect(TransportQualityGrade.critical.rawValue == "critical")
    }

    // MARK: - Boundary Behavior

    @Test("Boundary at exactly 0.3 is critical")
    func boundaryAt03() {
        #expect(TransportQualityGrade(score: 0.3) == .critical)
    }

    @Test("Boundary at exactly 0.5 is poor")
    func boundaryAt05() {
        #expect(TransportQualityGrade(score: 0.5) == .poor)
    }

    @Test("Boundary at exactly 0.7 is fair")
    func boundaryAt07() {
        #expect(TransportQualityGrade(score: 0.7) == .fair)
    }

    @Test("Boundary at exactly 0.9 is good")
    func boundaryAt09() {
        #expect(TransportQualityGrade(score: 0.9) == .good)
    }
}
