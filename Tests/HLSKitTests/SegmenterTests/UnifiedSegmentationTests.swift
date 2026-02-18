// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("UnifiedSegmentation")
struct UnifiedSegmentationTests {

    // MARK: - Format Dispatch

    @Test("HLSEngine with .fragmentedMP4 → fMP4 result")
    func fragmentedMP4Dispatch() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let engine = HLSEngine()
        var config = SegmentationConfig()
        config.containerFormat = .fragmentedMP4
        let result = try engine.segment(
            data: data, config: config
        )
        #expect(result.hasInitSegment)
        #expect(result.segmentCount > 0)
    }

    @Test("HLSEngine with .mpegTS → TS result")
    func mpegTSDispatch() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let engine = HLSEngine()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try engine.segment(
            data: data, config: config
        )
        #expect(!result.hasInitSegment)
        #expect(result.segmentCount > 0)
    }

    // MARK: - Duration Consistency

    @Test("Same source, different format: durations match")
    func durationConsistency() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let engine = HLSEngine()

        var fmp4Config = SegmentationConfig()
        fmp4Config.containerFormat = .fragmentedMP4
        let fmp4Result = try engine.segment(
            data: data, config: fmp4Config
        )

        let tsConfig = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let tsResult = try engine.segment(
            data: data, config: tsConfig
        )

        let tolerance = 0.1
        #expect(
            abs(fmp4Result.totalDuration - tsResult.totalDuration)
                < tolerance
        )
    }

    // MARK: - Backward Compatibility

    @Test("Default config is .fragmentedMP4")
    func defaultIsFragmentedMP4() {
        let config = SegmentationConfig()
        #expect(config.containerFormat == .fragmentedMP4)
    }

    @Test("Default fMP4 segment pattern is segment_%d.m4s")
    func defaultFMP4Pattern() {
        let config = SegmentationConfig()
        #expect(config.segmentNamePattern == "segment_%d.m4s")
    }

    @Test("Default TS segment pattern is segment_%d.ts")
    func defaultTSPattern() {
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        #expect(config.segmentNamePattern == "segment_%d.ts")
    }

    @Test("Default fMP4 HLS version is 7")
    func defaultFMP4Version() {
        let config = SegmentationConfig()
        #expect(config.hlsVersion == 7)
    }

    @Test("Default TS HLS version is 3")
    func defaultTSVersion() {
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        #expect(config.hlsVersion == 3)
    }

    @Test("Existing fMP4 tests: segmentation still works")
    func existingFMP4StillWorks() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        #expect(!result.initSegment.isEmpty)
        #expect(result.segmentCount > 0)
        #expect(result.playlist != nil)
    }
}
