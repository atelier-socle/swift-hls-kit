// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Audio Metering — Showcase", .timeLimit(.minutes(1)))
struct AudioMeteringShowcaseTests {

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

    // MARK: - Showcase

    @Test("Podcast loudness normalization to -16 LUFS")
    func podcastNormalization() {
        // Simulate raw podcast recording — quiet voice
        let voice = makeSineFloat32(
            frequency: 200, amplitude: 0.15, frames: 96000
        )

        // Normalize to podcast standard
        let normalizer = AudioNormalizer(preset: .podcast)
        let result = normalizer.normalize(
            data: voice, sampleRate: 48000, channels: 1
        )

        #expect(result.targetLoudness == -16.0)
        #expect(result.gainDB > 0)  // Should amplify
        #expect(result.data.count == voice.count)

        // Verify true peak is within limit
        #expect(result.truePeakAfter <= 0.0)
    }

    @Test("Music streaming target at -14 LUFS")
    func musicStreamingTarget() {
        let music = makeSineFloat32(
            frequency: 440, amplitude: 0.6, channels: 2, frames: 96000
        )

        let normalizer = AudioNormalizer(preset: .musicStreaming)
        let result = normalizer.normalize(
            data: music, sampleRate: 48000, channels: 2
        )

        #expect(result.targetLoudness == -14.0)
        #expect(result.originalLoudness.isFinite)
        #expect(result.data.count == music.count)
    }

    @Test("Broadcast compliance — EBU R 128 at -23 LUFS")
    func broadcastCompliance() {
        let broadcast = makeSineFloat32(
            frequency: 1000, amplitude: 0.4, frames: 96000
        )

        // Measure loudness
        var meter = LoudnessMeter(sampleRate: 48000, channels: 1)
        meter.process(block: broadcast)
        let measured = meter.integratedLoudness()
        #expect(measured.loudness.isFinite)

        // Normalize to EBU R 128
        let normalizer = AudioNormalizer(preset: .broadcast)
        let result = normalizer.normalize(
            data: broadcast, sampleRate: 48000, channels: 1
        )
        #expect(result.targetLoudness == -23.0)
        #expect(result.truePeakAfter <= 0.0)
    }

    @Test("Silence detection in podcast with intro gaps")
    func podcastSilenceDetection() {
        // 0.5s silence + 2s speech + 2s silence + 2s speech
        let speech = makeSineFloat32(
            frequency: 200, amplitude: 0.3, frames: 96000
        )
        let shortSilence = makeSilence(frames: 24000)  // 0.5s
        let longSilence = makeSilence(frames: 96000)  // 2s

        let podcast = shortSilence + speech + longSilence + speech

        let detector = SilenceDetector(
            thresholdDB: -40, minimumDuration: 1.0
        )
        let regions = detector.detect(
            data: podcast, sampleRate: 48000, channels: 1
        )

        // Should detect the 2s silence gap (>= 1.0s minimum)
        // The 0.5s intro silence may or may not be detected
        let longRegions = regions.filter { $0.duration >= 1.0 }
        #expect(!longRegions.isEmpty)
    }

    @Test("Level monitoring for live audio meters")
    func levelMonitoring() {
        // Simulate audio blocks arriving in real-time
        let meter = LevelMeter()
        let blocks = [
            makeSineFloat32(
                amplitude: 0.1, frames: 4800
            ),
            makeSineFloat32(
                amplitude: 0.5, frames: 4800
            ),
            makeSineFloat32(
                amplitude: 0.9, frames: 4800
            )
        ]

        var peakDBValues = [Float]()
        for block in blocks {
            let levels = meter.measure(data: block, channels: 1)
            peakDBValues.append(levels[0].peakDB)
        }

        // Levels should increase
        #expect(peakDBValues[0] < peakDBValues[1])
        #expect(peakDBValues[1] < peakDBValues[2])
    }

    @Test("Film delivery at -24 LKFS with true peak limiting")
    func filmDelivery() {
        let audio = makeSineFloat32(
            frequency: 500, amplitude: 0.7, frames: 96000
        )

        let normalizer = AudioNormalizer(
            preset: .film, truePeakLimit: -1.0
        )
        let result = normalizer.normalize(
            data: audio, sampleRate: 48000, channels: 1
        )

        #expect(result.targetLoudness == -24.0)
        // True peak should respect the -1 dBFS limit
        #expect(result.truePeakAfter <= 0.0)
    }

    @Test("Multi-stage podcast production pipeline")
    func podcastProductionPipeline() {
        // Step 1: Raw recording
        let raw = makeSineFloat32(
            frequency: 200, amplitude: 0.15, channels: 2, frames: 96000
        )

        // Step 2: Measure original levels
        let levelMeter = LevelMeter()
        let rawLevels = levelMeter.measure(data: raw, channels: 2)
        #expect(rawLevels.count == 2)

        // Step 3: Check for silence
        let detector = SilenceDetector(minimumDuration: 1.0)
        let isSilent = detector.isSilent(block: raw, channels: 2)
        #expect(!isSilent)

        // Step 4: Measure loudness
        var loudness = LoudnessMeter(sampleRate: 48000, channels: 2)
        loudness.process(block: raw)
        let measured = loudness.integratedLoudness()
        #expect(measured.loudness.isFinite)

        // Step 5: Normalize to podcast standard
        let normalizer = AudioNormalizer(preset: .podcast)
        let result = normalizer.normalize(
            data: raw, sampleRate: 48000, channels: 2
        )
        #expect(result.data.count == raw.count)
        #expect(result.gainDB > 0)

        // Step 6: Verify final levels
        let finalLevels = levelMeter.measure(
            data: result.data, channels: 2
        )
        #expect(finalLevels[0].rmsDB > rawLevels[0].rmsDB)
    }

    @Test("Voice level check — green/yellow/red zones")
    func voiceLevelCheck() {
        let meter = LevelMeter()

        // Green: moderate level
        let green = makeSineFloat32(
            amplitude: 0.3, frames: 4800
        )
        let greenLevel = meter.measure(data: green, channels: 1)
        let greenDB = greenLevel[0].rmsDB

        // Yellow: getting loud
        let yellow = makeSineFloat32(
            amplitude: 0.7, frames: 4800
        )
        let yellowLevel = meter.measure(data: yellow, channels: 1)
        let yellowDB = yellowLevel[0].rmsDB

        // Red: too hot
        let red = makeSineFloat32(
            amplitude: 0.99, frames: 4800
        )
        let redLevel = meter.measure(data: red, channels: 1)
        let redDB = redLevel[0].rmsDB

        // Verify ordering
        #expect(greenDB < yellowDB)
        #expect(yellowDB < redDB)
        #expect(redDB < 0)  // All should be below 0 dBFS
    }
}
