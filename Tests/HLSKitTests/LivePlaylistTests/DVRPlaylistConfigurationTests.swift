// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("DVRPlaylistConfiguration", .timeLimit(.minutes(1)))
struct DVRPlaylistConfigurationTests {

    // MARK: - Defaults

    @Test("Default values")
    func defaults() {
        let config = DVRPlaylistConfiguration()
        #expect(config.dvrWindowDuration == 7200)
        #expect(config.targetDuration == 6.0)
        #expect(config.version == 7)
        #expect(config.initSegmentURI == nil)
    }

    // MARK: - Custom Values

    @Test("Custom values")
    func custom() {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 3600,
            targetDuration: 4.0,
            version: 6,
            initSegmentURI: "init.mp4"
        )
        #expect(config.dvrWindowDuration == 3600)
        #expect(config.targetDuration == 4.0)
        #expect(config.version == 6)
        #expect(config.initSegmentURI == "init.mp4")
    }

    // MARK: - Presets

    @Test("shortDVR preset: 30 minutes")
    func shortDVR() {
        let config = DVRPlaylistConfiguration.shortDVR
        #expect(config.dvrWindowDuration == 1800)
        #expect(config.targetDuration == 6.0)
        #expect(config.version == 7)
    }

    @Test("standardDVR preset: 2 hours")
    func standardDVR() {
        let config = DVRPlaylistConfiguration.standardDVR
        #expect(config.dvrWindowDuration == 7200)
    }

    @Test("longDVR preset: 8 hours")
    func longDVR() {
        let config = DVRPlaylistConfiguration.longDVR
        #expect(config.dvrWindowDuration == 28800)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatable() {
        let a = DVRPlaylistConfiguration()
        let b = DVRPlaylistConfiguration()
        #expect(a == b)
    }

    @Test("Not equal with different window")
    func notEqual() {
        let a = DVRPlaylistConfiguration(dvrWindowDuration: 3600)
        let b = DVRPlaylistConfiguration(dvrWindowDuration: 7200)
        #expect(a != b)
    }
}
