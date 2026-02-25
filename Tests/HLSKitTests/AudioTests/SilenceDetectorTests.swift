// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SilenceDetector", .timeLimit(.minutes(1)))
struct SilenceDetectorTests {

    // MARK: - Helpers

    private func makeSineFloat32(
        frequency: Double = 1000, amplitude: Float = 0.5,
        sampleRate: Int = 48000, channels: Int = 1, frames: Int
    ) -> Data {
        var data = Data(capacity: frames * channels * 4)
        for i in 0..<frames {
            let t = Double(i) / Double(sampleRate)
            let value = amplitude * Float(sin(2.0 * .pi * frequency * t))
            for _ in 0..<channels {
                withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
            }
        }
        return data
    }

    private func makeSilence(frames: Int, channels: Int = 1) -> Data {
        Data(count: frames * channels * 4)
    }

    /// Creates data with silence in the middle:
    /// [signal][silence][signal]
    private func makeSignalSilenceSignal(
        signalFrames: Int, silenceFrames: Int,
        sampleRate: Int = 48000, channels: Int = 1,
        amplitude: Float = 0.5
    ) -> Data {
        let signal = makeSineFloat32(
            amplitude: amplitude, sampleRate: sampleRate,
            channels: channels, frames: signalFrames
        )
        let silence = makeSilence(
            frames: silenceFrames, channels: channels
        )
        return signal + silence + signal
    }

    // MARK: - Basic Tests

    @Test("Empty data returns empty regions")
    func emptyData() {
        let detector = SilenceDetector()
        let regions = detector.detect(
            data: Data(), sampleRate: 48000, channels: 1
        )
        #expect(regions.isEmpty)
    }

    @Test("Zero channels returns empty regions")
    func zeroChannels() {
        let detector = SilenceDetector()
        let data = makeSilence(frames: 48000)
        let regions = detector.detect(
            data: data, sampleRate: 48000, channels: 0
        )
        #expect(regions.isEmpty)
    }

    @Test("Zero sample rate returns empty regions")
    func zeroSampleRate() {
        let detector = SilenceDetector()
        let data = makeSilence(frames: 48000)
        let regions = detector.detect(
            data: data, sampleRate: 0, channels: 1
        )
        #expect(regions.isEmpty)
    }

    @Test("All silence detects one region")
    func allSilence() {
        let detector = SilenceDetector(minimumDuration: 0.5)
        let data = makeSilence(frames: 96000)  // 2 seconds
        let regions = detector.detect(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(regions.count == 1)
        let region = regions[0]
        #expect(region.startFrame == 0)
        #expect(region.endFrame == 96000)
        #expect(region.startTime == 0.0)
        #expect(abs(region.duration - 2.0) < 0.01)
    }

    @Test("No silence in loud signal returns empty")
    func noSilence() {
        let detector = SilenceDetector()
        let data = makeSineFloat32(
            amplitude: 0.8, frames: 96000
        )
        let regions = detector.detect(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(regions.isEmpty)
    }

    // MARK: - Silence Detection

    @Test("Detects silence in middle of signal")
    func silenceInMiddle() {
        let detector = SilenceDetector(
            thresholdDB: -40, minimumDuration: 0.5
        )
        // 1s signal + 2s silence + 1s signal
        let data = makeSignalSilenceSignal(
            signalFrames: 48000, silenceFrames: 96000
        )
        let regions = detector.detect(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(regions.count >= 1)
        if let region = regions.first {
            #expect(region.duration >= 0.5)
            #expect(region.startTime > 0)
        }
    }

    @Test("Minimum duration filters short silence")
    func minimumDurationFilter() {
        let detector = SilenceDetector(minimumDuration: 2.0)
        // 1s signal + 0.5s silence + 1s signal
        let data = makeSignalSilenceSignal(
            signalFrames: 48000, silenceFrames: 24000
        )
        let regions = detector.detect(
            data: data, sampleRate: 48000, channels: 1
        )
        // 0.5s silence should be filtered out (< 2.0s minimum)
        #expect(regions.isEmpty)
    }

    @Test("Low minimum duration detects short silence")
    func lowMinimumDuration() {
        let detector = SilenceDetector(minimumDuration: 0.1)
        // 1s signal + 0.5s silence + 1s signal
        let data = makeSignalSilenceSignal(
            signalFrames: 48000, silenceFrames: 24000
        )
        let regions = detector.detect(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(!regions.isEmpty)
    }

    // MARK: - isSilent

    @Test("isSilent returns true for silence")
    func isSilentTrue() {
        let detector = SilenceDetector()
        let block = makeSilence(frames: 1024)
        #expect(detector.isSilent(block: block, channels: 1))
    }

    @Test("isSilent returns false for loud signal")
    func isSilentFalse() {
        let detector = SilenceDetector()
        let block = makeSineFloat32(
            amplitude: 0.8, frames: 1024
        )
        #expect(!detector.isSilent(block: block, channels: 1))
    }

    @Test("isSilent with empty block returns true")
    func isSilentEmptyBlock() {
        let detector = SilenceDetector()
        #expect(detector.isSilent(block: Data(), channels: 1))
    }

    @Test("isSilent with zero channels returns true")
    func isSilentZeroChannels() {
        let detector = SilenceDetector()
        let block = makeSineFloat32(
            amplitude: 0.8, frames: 1024
        )
        #expect(detector.isSilent(block: block, channels: 0))
    }

    // MARK: - Configuration

    @Test("Default configuration values")
    func defaultConfig() {
        let detector = SilenceDetector()
        #expect(detector.thresholdDB == -40)
        #expect(detector.minimumDuration == 1.0)
        #expect(detector.windowSize == 1024)
    }

    @Test("Custom configuration")
    func customConfig() {
        let detector = SilenceDetector(
            thresholdDB: -30, minimumDuration: 0.5, windowSize: 512
        )
        #expect(detector.thresholdDB == -30)
        #expect(detector.minimumDuration == 0.5)
        #expect(detector.windowSize == 512)
    }

    @Test("Window size minimum is 1")
    func windowSizeMinimum() {
        let detector = SilenceDetector(windowSize: 0)
        #expect(detector.windowSize == 1)
    }

    // MARK: - SilenceRegion

    @Test("SilenceRegion is Equatable")
    func silenceRegionEquatable() {
        let a = SilenceRegion(
            startTime: 1.0, endTime: 3.0, duration: 2.0,
            averageLevelDB: -60, startFrame: 48000, endFrame: 144000
        )
        let b = SilenceRegion(
            startTime: 1.0, endTime: 3.0, duration: 2.0,
            averageLevelDB: -60, startFrame: 48000, endFrame: 144000
        )
        #expect(a == b)
    }

    @Test("SilenceRegion properties are correct")
    func silenceRegionProperties() {
        let region = SilenceRegion(
            startTime: 2.0, endTime: 5.0, duration: 3.0,
            averageLevelDB: -55, startFrame: 96000, endFrame: 240000
        )
        #expect(region.startTime == 2.0)
        #expect(region.endTime == 5.0)
        #expect(region.duration == 3.0)
        #expect(region.averageLevelDB == -55)
        #expect(region.startFrame == 96000)
        #expect(region.endFrame == 240000)
    }

    // MARK: - Stereo

    @Test("Detect works with stereo data")
    func stereoDetection() {
        let detector = SilenceDetector(minimumDuration: 0.5)
        let data = makeSilence(frames: 96000, channels: 2)
        let regions = detector.detect(
            data: data, sampleRate: 48000, channels: 2
        )
        #expect(!regions.isEmpty)
    }

    // MARK: - Threshold

    @Test("Higher threshold detects more silence")
    func higherThreshold() {
        let strict = SilenceDetector(
            thresholdDB: -20, minimumDuration: 0.5
        )
        let lenient = SilenceDetector(
            thresholdDB: -60, minimumDuration: 0.5
        )
        // Quiet signal that's above -60 but below -20
        let data = makeSineFloat32(
            amplitude: 0.05, frames: 96000
        )
        let strictRegions = strict.detect(
            data: data, sampleRate: 48000, channels: 1
        )
        let lenientRegions = lenient.detect(
            data: data, sampleRate: 48000, channels: 1
        )
        // -20 dB threshold should detect more silence
        #expect(strictRegions.count >= lenientRegions.count)
    }
}
