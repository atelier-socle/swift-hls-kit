// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AudioNormalizer", .timeLimit(.minutes(1)))
struct AudioNormalizerTests {

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

    // MARK: - Presets

    @Test("NormalizationPreset podcast is -16 LUFS")
    func presetPodcast() {
        #expect(NormalizationPreset.podcast.targetLoudness == -16.0)
    }

    @Test("NormalizationPreset musicStreaming is -14 LUFS")
    func presetMusicStreaming() {
        #expect(NormalizationPreset.musicStreaming.targetLoudness == -14.0)
    }

    @Test("NormalizationPreset broadcast is -23 LUFS")
    func presetBroadcast() {
        #expect(NormalizationPreset.broadcast.targetLoudness == -23.0)
    }

    @Test("NormalizationPreset film is -24 LUFS")
    func presetFilm() {
        #expect(NormalizationPreset.film.targetLoudness == -24.0)
    }

    @Test("NormalizationPreset is CaseIterable")
    func presetCaseIterable() {
        let all = NormalizationPreset.allCases
        #expect(all.count == 4)
    }

    @Test("NormalizationPreset raw values")
    func presetRawValues() {
        #expect(NormalizationPreset.podcast.rawValue == "podcast")
        #expect(NormalizationPreset.film.rawValue == "film")
    }

    // MARK: - Init

    @Test("Init with target loudness")
    func initWithTarget() {
        let normalizer = AudioNormalizer(
            targetLoudness: -16.0, truePeakLimit: -2.0
        )
        #expect(normalizer.targetLoudness == -16.0)
        #expect(normalizer.truePeakLimit == -2.0)
    }

    @Test("Init with preset")
    func initWithPreset() {
        let normalizer = AudioNormalizer(preset: .broadcast)
        #expect(normalizer.targetLoudness == -23.0)
        #expect(normalizer.truePeakLimit == -1.0)
    }

    @Test("Default true peak limit is -1 dBFS")
    func defaultTruePeakLimit() {
        let normalizer = AudioNormalizer(targetLoudness: -16.0)
        #expect(normalizer.truePeakLimit == -1.0)
    }

    // MARK: - Normalize Silence

    @Test("Normalize silence returns unchanged data")
    func normalizeSilence() {
        let normalizer = AudioNormalizer(preset: .podcast)
        let silence = makeSilence(frames: 48000)
        let result = normalizer.normalize(
            data: silence, sampleRate: 48000, channels: 1
        )
        #expect(result.gainDB == 0)
        #expect(result.gainLinear == 1.0)
        #expect(result.peakLimited == false)
        #expect(result.data == silence)
        #expect(!result.originalLoudness.isFinite)
    }

    // MARK: - Normalize Audio

    @Test("Normalize applies gain to audio")
    func normalizeAppliesGain() {
        let normalizer = AudioNormalizer(targetLoudness: -16.0)
        // Quiet signal
        let data = makeSineFloat32(
            amplitude: 0.05, frames: 96000
        )
        let result = normalizer.normalize(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(result.gainDB > 0)  // Should amplify
        #expect(result.gainLinear > 1.0)
        #expect(result.originalLoudness.isFinite)
        #expect(result.data.count == data.count)
    }

    @Test("Normalize attenuates loud audio")
    func normalizeAttenuatesLoud() {
        let normalizer = AudioNormalizer(targetLoudness: -23.0)
        // Loud signal
        let data = makeSineFloat32(
            amplitude: 0.9, frames: 96000
        )
        let result = normalizer.normalize(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(result.gainDB < 0)  // Should attenuate
        #expect(result.gainLinear < 1.0)
    }

    // MARK: - Calculate Gain

    @Test("calculateGain returns gain without modifying data")
    func calculateGainOnly() {
        let normalizer = AudioNormalizer(targetLoudness: -16.0)
        let data = makeSineFloat32(
            amplitude: 0.3, frames: 96000
        )
        let (gainDB, original) = normalizer.calculateGain(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(original.isFinite)
        #expect(gainDB.isFinite)
        // gain = target - original
        let expected = -16.0 - original
        #expect(abs(gainDB - expected) < 0.01)
    }

    @Test("calculateGain for silence returns zero gain")
    func calculateGainSilence() {
        let normalizer = AudioNormalizer(targetLoudness: -16.0)
        let silence = makeSilence(frames: 48000)
        let (gainDB, original) = normalizer.calculateGain(
            data: silence, sampleRate: 48000, channels: 1
        )
        #expect(gainDB == 0)
        #expect(!original.isFinite)
    }

    // MARK: - True Peak Limiting

    @Test("True peak limiting is applied when needed")
    func truePeakLimiting() {
        // Use a low truePeakLimit so the limiter branch is triggered
        let normalizer = AudioNormalizer(
            targetLoudness: -5.0, truePeakLimit: -20.0
        )
        let data = makeSineFloat32(
            amplitude: 0.3, frames: 96000
        )
        let result = normalizer.normalize(
            data: data, sampleRate: 48000, channels: 1
        )
        // Peak limiter should have been engaged
        #expect(result.peakLimited)
        #expect(result.truePeakAfter <= 0.0)
    }

    // MARK: - NormalizationResult

    @Test("NormalizationResult contains all fields")
    func normalizationResultFields() {
        let normalizer = AudioNormalizer(preset: .podcast)
        let data = makeSineFloat32(
            amplitude: 0.3, frames: 96000
        )
        let result = normalizer.normalize(
            data: data, sampleRate: 48000, channels: 1
        )
        #expect(result.originalLoudness.isFinite)
        #expect(result.targetLoudness == -16.0)
        #expect(result.gainDB.isFinite)
        #expect(result.gainLinear.isFinite)
        #expect(result.data.count == data.count)
    }

    // MARK: - Stereo

    @Test("Normalize works with stereo data")
    func normalizeStereo() {
        let normalizer = AudioNormalizer(targetLoudness: -16.0)
        let data = makeSineFloat32(
            amplitude: 0.3, channels: 2, frames: 96000
        )
        let result = normalizer.normalize(
            data: data, sampleRate: 48000, channels: 2
        )
        #expect(result.originalLoudness.isFinite)
        #expect(result.data.count == data.count)
    }
}
