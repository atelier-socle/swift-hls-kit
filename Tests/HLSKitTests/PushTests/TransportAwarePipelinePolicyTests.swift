// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "TransportAwarePipelinePolicy",
    .timeLimit(.minutes(1))
)
struct TransportAwarePipelinePolicyTests {

    @Test("Init with all parameters")
    func initWithAllParams() {
        let policy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: true,
            minimumQualityGrade: .fair,
            abrResponsiveness: .immediate
        )
        #expect(policy.autoAdjustBitrate)
        #expect(policy.minimumQualityGrade == .fair)
        #expect(policy.abrResponsiveness == .immediate)
    }

    @Test("Default preset values")
    func defaultPreset() {
        let policy = TransportAwarePipelinePolicy.default
        #expect(policy.autoAdjustBitrate)
        #expect(policy.minimumQualityGrade == .poor)
        #expect(policy.abrResponsiveness == .responsive)
    }

    @Test("Disabled preset values")
    func disabledPreset() {
        let policy = TransportAwarePipelinePolicy.disabled
        #expect(!policy.autoAdjustBitrate)
        #expect(policy.minimumQualityGrade == .critical)
        #expect(policy.abrResponsiveness == .conservative)
    }

    @Test("Equatable conformance — equal")
    func equatableEqual() {
        let a = TransportAwarePipelinePolicy.default
        let b = TransportAwarePipelinePolicy(
            autoAdjustBitrate: true,
            minimumQualityGrade: .poor,
            abrResponsiveness: .responsive
        )
        #expect(a == b)
    }

    @Test("Equatable conformance — not equal")
    func equatableNotEqual() {
        let a = TransportAwarePipelinePolicy.default
        let b = TransportAwarePipelinePolicy.disabled
        #expect(a != b)
    }

    @Test("ABRResponsiveness raw values")
    func abrResponsivenessRawValues() {
        #expect(
            TransportAwarePipelinePolicy.ABRResponsiveness
                .conservative.rawValue == "conservative"
        )
        #expect(
            TransportAwarePipelinePolicy.ABRResponsiveness
                .responsive.rawValue == "responsive"
        )
        #expect(
            TransportAwarePipelinePolicy.ABRResponsiveness
                .immediate.rawValue == "immediate"
        )
    }

    @Test("ABRResponsiveness CaseIterable has 3 cases")
    func abrResponsivenessCaseIterable() {
        #expect(
            TransportAwarePipelinePolicy.ABRResponsiveness
                .allCases.count == 3
        )
    }

    @Test("Custom policy construction")
    func customPolicy() {
        let policy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: false,
            minimumQualityGrade: .good,
            abrResponsiveness: .immediate
        )
        #expect(!policy.autoAdjustBitrate)
        #expect(policy.minimumQualityGrade == .good)
        #expect(policy.abrResponsiveness == .immediate)
    }

    @Test("Sendable conformance")
    func sendableConformance() async {
        let policy = TransportAwarePipelinePolicy.default
        await Task {
            #expect(policy.autoAdjustBitrate)
        }.value
    }

    @Test("Default and disabled are different")
    func defaultVsDisabled() {
        #expect(
            TransportAwarePipelinePolicy.default
                != TransportAwarePipelinePolicy.disabled
        )
    }
}
