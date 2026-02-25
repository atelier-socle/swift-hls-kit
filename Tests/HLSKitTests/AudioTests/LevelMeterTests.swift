// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LevelMeter", .timeLimit(.minutes(1)))
struct LevelMeterTests {

    // MARK: - Helpers

    private func makeSineFloat32(
        frequency: Double = 440, amplitude: Float = 0.8,
        sampleRate: Int = 48000, channels: Int = 1, frames: Int = 4800
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

    private func makeDC(value: Float, frames: Int, channels: Int = 1) -> Data {
        var data = Data(capacity: frames * channels * 4)
        for _ in 0..<frames {
            for _ in 0..<channels {
                withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
            }
        }
        return data
    }

    // MARK: - Basic Tests

    @Test("Empty data returns empty array")
    func emptyData() {
        let meter = LevelMeter()
        let result = meter.measure(data: Data(), channels: 2)
        #expect(result.isEmpty)
    }

    @Test("Zero channels returns empty array")
    func zeroChannels() {
        let meter = LevelMeter()
        let data = makeSilence(frames: 100)
        let result = meter.measure(data: data, channels: 0)
        #expect(result.isEmpty)
    }

    @Test("Silence gives -infinity dBFS")
    func silence() {
        let meter = LevelMeter()
        let data = makeSilence(frames: 4800)
        let levels = meter.measure(data: data, channels: 1)
        #expect(levels.count == 1)
        #expect(levels[0].rmsDB == -.infinity)
        #expect(levels[0].peakDB == -.infinity)
        #expect(levels[0].truePeakDB == -.infinity)
        #expect(levels[0].rms == 0)
        #expect(levels[0].peak == 0)
    }

    @Test("Full-scale DC gives 0 dBFS peak")
    func fullScaleDC() {
        let meter = LevelMeter()
        let data = makeDC(value: 1.0, frames: 4800)
        let levels = meter.measure(data: data, channels: 1)
        #expect(levels[0].peak == 1.0)
        #expect(levels[0].peakDB == 0.0)
        #expect(levels[0].rms == 1.0)
        #expect(levels[0].rmsDB == 0.0)
    }

    @Test("Sine wave RMS is approximately -3 dBFS for full-scale")
    func sineWaveRMS() {
        let meter = LevelMeter()
        let data = makeSineFloat32(
            amplitude: 1.0, frames: 48000
        )
        let levels = meter.measure(data: data, channels: 1)
        // RMS of sine = amplitude / sqrt(2) ≈ 0.707 → -3.01 dBFS
        #expect(levels[0].rmsDB > -3.2)
        #expect(levels[0].rmsDB < -2.8)
        #expect(levels[0].peakDB > -0.1)
        #expect(levels[0].peakDB <= 0.0)
    }

    @Test("Half-amplitude sine gives approximately -9 dBFS RMS")
    func halfAmplitudeSine() {
        let meter = LevelMeter()
        let data = makeSineFloat32(
            amplitude: 0.5, frames: 48000
        )
        let levels = meter.measure(data: data, channels: 1)
        // RMS ≈ 0.5/sqrt(2) ≈ 0.354 → -9.03 dBFS
        #expect(levels[0].rmsDB > -9.5)
        #expect(levels[0].rmsDB < -8.5)
    }

    // MARK: - Stereo

    @Test("Stereo measures each channel independently")
    func stereoChannels() {
        let meter = LevelMeter()
        // Left = 0.8 sine, Right = 0.2 sine
        let frames = 48000
        var data = Data(capacity: frames * 2 * 4)
        for i in 0..<frames {
            let t = Double(i) / 48000.0
            let left = Float(0.8 * sin(2.0 * .pi * 440.0 * t))
            let right = Float(0.2 * sin(2.0 * .pi * 440.0 * t))
            withUnsafeBytes(of: left) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: right) { data.append(contentsOf: $0) }
        }
        let levels = meter.measure(data: data, channels: 2)
        #expect(levels.count == 2)
        // Left louder than right
        #expect(levels[0].rmsDB > levels[1].rmsDB)
        #expect(levels[0].peakDB > levels[1].peakDB)
    }

    // MARK: - Mono Measurement

    @Test("measureMono on empty data returns zeros")
    func measureMonoEmpty() {
        let meter = LevelMeter()
        let level = meter.measureMono(data: Data())
        #expect(level.rms == 0)
        #expect(level.rmsDB == -.infinity)
    }

    @Test("measureMono gives correct RMS")
    func measureMonoSine() {
        let meter = LevelMeter()
        let data = makeSineFloat32(
            amplitude: 0.5, frames: 48000
        )
        let level = meter.measureMono(data: data)
        #expect(level.rmsDB > -9.5)
        #expect(level.rmsDB < -8.5)
        #expect(level.peak > 0.49)
        #expect(level.peak < 0.51)
    }

    // MARK: - True Peak

    @Test("True peak detects intersample peaks")
    func truePeakDetection() {
        let meter = LevelMeter()
        // Create signal where intersample peak exceeds sample peak
        // Two adjacent samples at ~0.9 that interpolate above 0.9
        let frames = 100
        var data = Data(capacity: frames * 4)
        for i in 0..<frames {
            let t = Double(i) / 100.0
            let value = Float(0.9 * sin(2.0 * .pi * 25.0 * t))
            withUnsafeBytes(of: value) { data.append(contentsOf: $0) }
        }
        let levels = meter.measure(data: data, channels: 1)
        // True peak should be >= sample peak
        #expect(levels[0].truePeak >= levels[0].peak)
    }

    @Test("Single sample true peak")
    func singleSampleTruePeak() {
        let meter = LevelMeter()
        var data = Data(count: 4)
        let value: Float = 0.75
        data.withUnsafeMutableBytes { ptr in
            ptr.storeBytes(of: value, as: Float.self)
        }
        let levels = meter.measure(data: data, channels: 1)
        #expect(levels[0].peak == 0.75)
        #expect(levels[0].truePeak == 0.75)
    }

    // MARK: - toDBFS

    @Test("toDBFS converts correctly")
    func toDBFSConversion() {
        #expect(LevelMeter.toDBFS(1.0) == 0.0)
        #expect(LevelMeter.toDBFS(0) == -.infinity)
        let half = LevelMeter.toDBFS(0.5)
        #expect(half > -6.1)
        #expect(half < -6.0)
    }

    // MARK: - Edge Cases

    @Test("Negative samples handled correctly")
    func negativeSamples() {
        let meter = LevelMeter()
        let data = makeDC(value: -0.5, frames: 4800)
        let levels = meter.measure(data: data, channels: 1)
        #expect(levels[0].peak == 0.5)
        #expect(levels[0].rms == 0.5)
    }

    @Test("Insufficient data for full frame returns empty")
    func insufficientData() {
        let meter = LevelMeter()
        // 3 bytes is not enough for even 1 Float32 sample
        let data = Data([0, 0, 0])
        let levels = meter.measure(data: data, channels: 1)
        #expect(levels.isEmpty)
    }

    @Test("ChannelLevel is Equatable")
    func channelLevelEquatable() {
        let a = ChannelLevel(
            rms: 0.5, rmsDB: -6.0, peak: 0.8, peakDB: -1.9,
            truePeak: 0.85, truePeakDB: -1.4
        )
        let b = ChannelLevel(
            rms: 0.5, rmsDB: -6.0, peak: 0.8, peakDB: -1.9,
            truePeak: 0.85, truePeakDB: -1.4
        )
        #expect(a == b)
    }
}
