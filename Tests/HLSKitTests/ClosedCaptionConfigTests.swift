// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - ClosedCaptionConfig

@Suite("ClosedCaptionConfig — Configuration")
struct ClosedCaptionConfigTests {

    @Test("Default init uses CEA-708 with empty services")
    func defaultInit() {
        let config = ClosedCaptionConfig()
        #expect(config.standard == .cea708)
        #expect(config.services.isEmpty)
        #expect(config.groupID == "cc")
    }

    @Test("Custom init sets all properties")
    func customInit() {
        let config = ClosedCaptionConfig(
            standard: .cea608,
            services: [
                .init(serviceID: 1, language: "en", name: "English")
            ],
            groupID: "captions"
        )
        #expect(config.standard == .cea608)
        #expect(config.services.count == 1)
        #expect(config.groupID == "captions")
    }

    @Test("CaptionStandard raw values match spec")
    func standardRawValues() {
        #expect(ClosedCaptionConfig.CaptionStandard.cea608.rawValue == "cea-608")
        #expect(ClosedCaptionConfig.CaptionStandard.cea708.rawValue == "cea-708")
    }

    @Test("CaptionStandard has all cases")
    func standardCaseIterable() {
        let cases = ClosedCaptionConfig.CaptionStandard.allCases
        #expect(cases.count == 2)
    }

    @Test("CEA-608 instreamID generates CC1-CC4")
    func cea608InstreamID() {
        let service1 = ClosedCaptionConfig.CaptionService(
            serviceID: 1, language: "en", name: "English"
        )
        let service4 = ClosedCaptionConfig.CaptionService(
            serviceID: 4, language: "fr", name: "French"
        )
        #expect(service1.instreamID(standard: .cea608) == "CC1")
        #expect(service4.instreamID(standard: .cea608) == "CC4")
    }

    @Test("CEA-708 instreamID generates SERVICE1-SERVICE63")
    func cea708InstreamID() {
        let service1 = ClosedCaptionConfig.CaptionService(
            serviceID: 1, language: "en", name: "English"
        )
        let service63 = ClosedCaptionConfig.CaptionService(
            serviceID: 63, language: "ko", name: "Korean"
        )
        #expect(service1.instreamID(standard: .cea708) == "SERVICE1")
        #expect(service63.instreamID(standard: .cea708) == "SERVICE63")
    }

    @Test("CaptionService default isDefault is false")
    func serviceDefaultIsDefault() {
        let service = ClosedCaptionConfig.CaptionService(
            serviceID: 1, language: "en", name: "English"
        )
        #expect(!service.isDefault)
    }

    @Test("CaptionService with isDefault true")
    func serviceIsDefaultTrue() {
        let service = ClosedCaptionConfig.CaptionService(
            serviceID: 1, language: "en", name: "English", isDefault: true
        )
        #expect(service.isDefault)
    }

    @Test("maxServices is 4 for CEA-608")
    func maxServicesCEA608() {
        let config = ClosedCaptionConfig(standard: .cea608)
        #expect(config.maxServices == 4)
    }

    @Test("maxServices is 63 for CEA-708")
    func maxServicesCEA708() {
        let config = ClosedCaptionConfig(standard: .cea708)
        #expect(config.maxServices == 63)
    }

    @Test("Validate empty services returns error")
    func validateEmptyServices() {
        let config = ClosedCaptionConfig()
        let errors = config.validate()
        #expect(errors.contains { $0.contains("No caption services") })
    }

    @Test("Validate serviceID out of range for CEA-608")
    func validateServiceIDOutOfRange608() {
        let config = ClosedCaptionConfig(
            standard: .cea608,
            services: [.init(serviceID: 5, language: "en", name: "English")]
        )
        let errors = config.validate()
        #expect(errors.contains { $0.contains("out of range") })
    }

    @Test("Validate serviceID out of range for CEA-708")
    func validateServiceIDOutOfRange708() {
        let config = ClosedCaptionConfig(
            standard: .cea708,
            services: [.init(serviceID: 64, language: "en", name: "English")]
        )
        let errors = config.validate()
        #expect(errors.contains { $0.contains("out of range") })
    }

    @Test("Validate duplicate service IDs")
    func validateDuplicateIDs() {
        let config = ClosedCaptionConfig(
            standard: .cea708,
            services: [
                .init(serviceID: 1, language: "en", name: "English"),
                .init(serviceID: 1, language: "es", name: "Spanish")
            ]
        )
        let errors = config.validate()
        #expect(errors.contains { $0.contains("Duplicate") })
    }

    @Test("Valid configuration has no errors")
    func validateValid() {
        let errors = ClosedCaptionConfig.englishSpanish708.validate()
        #expect(errors.isEmpty)
    }
}

// MARK: - Presets

@Suite("ClosedCaptionConfig — Presets")
struct ClosedCaptionConfigPresetTests {

    @Test("englishOnly608 preset")
    func englishOnly608() {
        let config = ClosedCaptionConfig.englishOnly608
        #expect(config.standard == .cea608)
        #expect(config.services.count == 1)
        #expect(config.services[0].language == "en")
        #expect(config.services[0].isDefault)
    }

    @Test("englishSpanish708 preset")
    func englishSpanish708() {
        let config = ClosedCaptionConfig.englishSpanish708
        #expect(config.standard == .cea708)
        #expect(config.services.count == 2)
        #expect(config.services[0].language == "en")
        #expect(config.services[1].language == "es")
    }

    @Test("broadcast708 preset has 3 languages")
    func broadcast708() {
        let config = ClosedCaptionConfig.broadcast708
        #expect(config.standard == .cea708)
        #expect(config.services.count == 3)
        #expect(config.services[2].language == "fr")
    }
}

// MARK: - Equatable

@Suite("ClosedCaptionConfig — Equatable")
struct ClosedCaptionConfigEquatableTests {

    @Test("Identical configs are equal")
    func identical() {
        let a = ClosedCaptionConfig.englishSpanish708
        let b = ClosedCaptionConfig.englishSpanish708
        #expect(a == b)
    }

    @Test("Different configs are not equal")
    func different() {
        let a = ClosedCaptionConfig.englishOnly608
        let b = ClosedCaptionConfig.englishSpanish708
        #expect(a != b)
    }
}
