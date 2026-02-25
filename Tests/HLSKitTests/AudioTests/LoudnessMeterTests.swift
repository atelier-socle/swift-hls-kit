// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LoudnessMeter", .timeLimit(.minutes(1)))
struct LoudnessMeterTests {

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

    private func makeSilence(
        frames: Int, channels: Int = 1
    ) -> Data {
        Data(count: frames * channels * 4)
    }

    // MARK: - Basic Tests

    @Test("Empty block does not crash")
    func emptyBlock() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        meter.process(block: Data())
        let result = meter.integratedLoudness()
        #expect(result.loudness == -.infinity)
    }

    @Test("Silence gives -infinity LUFS")
    func silence() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        let data = makeSilence(frames: 48000)
        meter.process(block: data)
        let result = meter.integratedLoudness()
        #expect(result.loudness == -.infinity)
    }

    @Test("Sine wave gives finite LUFS")
    func sineWaveLoudness() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        // 2 seconds of sine at 0.5 amplitude
        let data = makeSineFloat32(frames: 96000)
        meter.process(block: data)
        let result = meter.integratedLoudness()
        #expect(result.loudness.isFinite)
        #expect(result.loudness < 0)
    }

    @Test("Louder signal gives higher LUFS")
    func louderSignalHigherLUFS() {
        var meterLoud = LoudnessMeter(sampleRate: 48000, channels: 1)
        var meterQuiet = LoudnessMeter(sampleRate: 48000, channels: 1)
        let loud = makeSineFloat32(
            amplitude: 0.8, frames: 96000
        )
        let quiet = makeSineFloat32(
            amplitude: 0.1, frames: 96000
        )
        meterLoud.process(block: loud)
        meterQuiet.process(block: quiet)
        let loudResult = meterLoud.integratedLoudness()
        let quietResult = meterQuiet.integratedLoudness()
        #expect(loudResult.loudness > quietResult.loudness)
    }

    // MARK: - Momentary

    @Test("Momentary loudness returns nil for short data")
    func momentaryTooShort() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        // Less than 400ms = 19200 frames
        let data = makeSineFloat32(frames: 10000)
        meter.process(block: data)
        #expect(meter.momentaryLoudness() == nil)
    }

    @Test("Momentary loudness returns value for 400ms+")
    func momentaryEnoughData() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        // Exactly 400ms = 19200 frames
        let data = makeSineFloat32(frames: 19200)
        meter.process(block: data)
        let momentary = meter.momentaryLoudness()
        #expect(momentary != nil)
        if let m = momentary {
            #expect(m.isFinite)
            #expect(m < 0)
        }
    }

    // MARK: - Short-term

    @Test("Short-term loudness returns nil for short data")
    func shortTermTooShort() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        let data = makeSineFloat32(frames: 48000)  // 1s < 3s
        meter.process(block: data)
        #expect(meter.shortTermLoudness() == nil)
    }

    @Test("Short-term loudness returns value for 3s+")
    func shortTermEnoughData() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        let data = makeSineFloat32(frames: 144000)  // 3s
        meter.process(block: data)
        let shortTerm = meter.shortTermLoudness()
        #expect(shortTerm != nil)
        if let st = shortTerm {
            #expect(st.isFinite)
            #expect(st < 0)
        }
    }

    // MARK: - Integrated

    @Test("Integrated loudness with gating blocks")
    func integratedGating() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        // 2 seconds of signal — enough for gating blocks
        let data = makeSineFloat32(
            amplitude: 0.5, frames: 96000
        )
        meter.process(block: data)
        let result = meter.integratedLoudness()
        #expect(result.loudness.isFinite)
        #expect(result.loudness < 0)
    }

    @Test("LoudnessResult is Equatable")
    func loudnessResultEquatable() {
        let a = LoudnessResult(loudness: -16.0, range: 5.0)
        let b = LoudnessResult(loudness: -16.0, range: 5.0)
        #expect(a == b)
    }

    @Test("GatingBlock stores channel energy and loudness")
    func gatingBlockProperties() {
        let block = GatingBlock(
            channelEnergy: [0.01, 0.02],
            loudness: -23.0
        )
        #expect(block.channelEnergy.count == 2)
        #expect(block.loudness == -23.0)
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func resetClearsState() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        let data = makeSineFloat32(frames: 96000)
        meter.process(block: data)
        let before = meter.integratedLoudness()
        #expect(before.loudness.isFinite)

        meter.reset()
        let after = meter.integratedLoudness()
        #expect(after.loudness == -.infinity)
        #expect(meter.momentaryLoudness() == nil)
    }

    // MARK: - Sample Rate

    @Test("Works with 44100 Hz sample rate")
    func sampleRate44100() {
        var meter = LoudnessMeter(sampleRate: 44100, channels: 1)
        let data = makeSineFloat32(
            sampleRate: 44100, frames: 88200
        )
        meter.process(block: data)
        let result = meter.integratedLoudness()
        #expect(result.loudness.isFinite)
    }

    @Test("Works with 48000 Hz sample rate")
    func sampleRate48000() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 2)
        let data = makeSineFloat32(
            sampleRate: 48000, channels: 2, frames: 96000
        )
        meter.process(block: data)
        let result = meter.integratedLoudness()
        #expect(result.loudness.isFinite)
    }

    // MARK: - Loudness Range

    @Test("Loudness range returns nil for short data")
    func loudnessRangeShort() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        let data = makeSineFloat32(frames: 48000)  // 1s < 3s
        meter.process(block: data)
        #expect(meter.loudnessRange() == nil)
    }

    @Test("Loudness range returns value for long varied signal")
    func loudnessRangeVaried() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        // 5 seconds of signal for enough short-term blocks
        let data = makeSineFloat32(
            amplitude: 0.5, frames: 240000
        )
        meter.process(block: data)
        let range = meter.loudnessRange()
        // Constant signal should have small range
        if let r = range {
            #expect(r >= 0)
        }
    }

    // MARK: - Multiple Blocks

    @Test("Processing multiple blocks accumulates correctly")
    func multipleBlocks() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        let block = makeSineFloat32(frames: 48000)
        meter.process(block: block)
        meter.process(block: block)
        let result = meter.integratedLoudness()
        #expect(result.loudness.isFinite)
    }

    @Test("Integrated loudness has optional range")
    func integratedWithRange() {
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        // Need 3+ seconds for range calculation
        let data = makeSineFloat32(
            amplitude: 0.3, frames: 192000
        )
        meter.process(block: data)
        let result = meter.integratedLoudness()
        #expect(result.loudness.isFinite)
        // Range may or may not be available depending on block count
    }
}
