// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Audio Metering — Integration", .timeLimit(.minutes(1)))
struct AudioMeteringIntegrationTests {

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

    // MARK: - Level + Loudness Combined

    @Test("Level meter and loudness meter agree on silence")
    func levelAndLoudnessSilence() {
        let data = makeSilence(frames: 96000)

        let levelMeter = LevelMeter()
        let levels = levelMeter.measure(data: data, channels: 1)
        #expect(levels[0].rmsDB == -.infinity)

        var loudnessMeter = LoudnessMeter(
            sampleRate: 48000, channels: 1
        )
        loudnessMeter.process(block: data)
        let loudness = loudnessMeter.integratedLoudness()
        #expect(loudness.loudness == -.infinity)
    }

    @Test("Level meter and loudness meter both detect signal")
    func levelAndLoudnessSignal() {
        let data = makeSineFloat32(
            amplitude: 0.5, frames: 96000
        )

        let levelMeter = LevelMeter()
        let levels = levelMeter.measure(data: data, channels: 1)
        #expect(levels[0].rmsDB.isFinite)
        #expect(levels[0].rmsDB < 0)

        var loudnessMeter = LoudnessMeter(
            sampleRate: 48000, channels: 1
        )
        loudnessMeter.process(block: data)
        let loudness = loudnessMeter.integratedLoudness()
        #expect(loudness.loudness.isFinite)
        #expect(loudness.loudness < 0)
    }

    // MARK: - Normalize + Verify Levels

    @Test("Normalized audio has correct level")
    func normalizeAndVerifyLevel() {
        let data = makeSineFloat32(
            amplitude: 0.3, frames: 96000
        )

        let normalizer = AudioNormalizer(targetLoudness: -16.0)
        let result = normalizer.normalize(
            data: data, sampleRate: 48000, channels: 1
        )

        // Verify normalized data has different levels
        let meter = LevelMeter()
        let originalLevels = meter.measure(data: data, channels: 1)
        let normalizedLevels = meter.measure(
            data: result.data, channels: 1
        )

        if result.gainDB > 0 {
            #expect(normalizedLevels[0].rmsDB > originalLevels[0].rmsDB)
        } else {
            #expect(normalizedLevels[0].rmsDB < originalLevels[0].rmsDB)
        }
    }

    // MARK: - Silence Detection + Normalization

    @Test("Detect silence then normalize non-silent parts")
    func silenceDetectionAndNormalization() {
        // Create signal with silence
        let signal = makeSineFloat32(
            amplitude: 0.3, frames: 96000
        )
        let silence = makeSilence(frames: 96000)
        let combined = signal + silence + signal

        // Detect silence
        let detector = SilenceDetector(
            thresholdDB: -40, minimumDuration: 0.5
        )
        let regions = detector.detect(
            data: combined, sampleRate: 48000, channels: 1
        )
        #expect(!regions.isEmpty)

        // Normalize the signal portion only
        let normalizer = AudioNormalizer(targetLoudness: -16.0)
        let result = normalizer.normalize(
            data: signal, sampleRate: 48000, channels: 1
        )
        #expect(result.originalLoudness.isFinite)
        #expect(result.data.count == signal.count)
    }

    // MARK: - Full Pipeline

    @Test("Full metering pipeline: measure, normalize, verify")
    func fullMeteringPipeline() {
        let data = makeSineFloat32(
            amplitude: 0.2, frames: 96000
        )

        // Step 1: Measure original
        let levelMeter = LevelMeter()
        let originalLevels = levelMeter.measure(data: data, channels: 1)
        #expect(originalLevels[0].rmsDB.isFinite)

        // Step 2: Measure loudness
        var loudnessMeter = LoudnessMeter(
            sampleRate: 48000, channels: 1
        )
        loudnessMeter.process(block: data)
        let originalLoudness = loudnessMeter.integratedLoudness()
        #expect(originalLoudness.loudness.isFinite)

        // Step 3: Check silence
        let detector = SilenceDetector()
        let isSilent = detector.isSilent(block: data, channels: 1)
        #expect(!isSilent)

        // Step 4: Normalize
        let normalizer = AudioNormalizer(preset: .podcast)
        let result = normalizer.normalize(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(result.data.count == data.count)

        // Step 5: Verify normalized levels
        let normalizedLevels = levelMeter.measure(
            data: result.data, channels: 1
        )
        #expect(normalizedLevels[0].rmsDB.isFinite)
    }

    // MARK: - Stereo Pipeline

    @Test("Stereo metering pipeline works end-to-end")
    func stereoPipeline() {
        let data = makeSineFloat32(
            amplitude: 0.4, channels: 2, frames: 96000
        )

        // Measure levels
        let meter = LevelMeter()
        let levels = meter.measure(data: data, channels: 2)
        #expect(levels.count == 2)

        // Measure loudness
        var loudness = LoudnessMeter(sampleRate: 48000, channels: 2)
        loudness.process(block: data)
        let result = loudness.integratedLoudness()
        #expect(result.loudness.isFinite)

        // Normalize
        let normalizer = AudioNormalizer(targetLoudness: -16.0)
        let normalized = normalizer.normalize(
            data: data, sampleRate: 48000, channels: 2
        )
        #expect(normalized.data.count == data.count)
    }

    @Test("Silence detector with stereo metering")
    func silenceDetectorWithStereoMetering() {
        let silence = makeSilence(frames: 96000, channels: 2)

        let detector = SilenceDetector(minimumDuration: 0.5)
        let regions = detector.detect(
            data: silence, sampleRate: 48000, channels: 2
        )
        #expect(!regions.isEmpty)

        // Verify with level meter
        let meter = LevelMeter()
        let levels = meter.measure(data: silence, channels: 2)
        #expect(levels[0].rmsDB == -.infinity)
        #expect(levels[1].rmsDB == -.infinity)
    }

    @Test("Multiple normalization presets produce different results")
    func multiplePresets() {
        let data = makeSineFloat32(
            amplitude: 0.3, frames: 96000
        )
        let podcastNorm = AudioNormalizer(preset: .podcast)
        let broadcastNorm = AudioNormalizer(preset: .broadcast)

        let podcastResult = podcastNorm.normalize(
            data: data, sampleRate: 48000, channels: 1
        )
        let broadcastResult = broadcastNorm.normalize(
            data: data, sampleRate: 48000, channels: 1
        )

        // Podcast (-16) should have higher gain than broadcast (-23)
        #expect(podcastResult.gainDB > broadcastResult.gainDB)
    }
}
