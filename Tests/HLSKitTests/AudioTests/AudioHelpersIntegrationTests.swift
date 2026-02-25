// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Audio Helpers Integration", .timeLimit(.minutes(1)))
struct AudioHelpersIntegrationTests {

    let fmt = AudioFormatConverter()
    let src = SampleRateConverter()
    let mix = ChannelMixer()

    // MARK: - Helpers

    private func makeFloat32(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * 4)
        for v in values {
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func readFloat32(_ data: Data) -> [Float] {
        data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    private func makeInt16Stereo(sampleCount: Int) -> Data {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 2, frequency: 440
        )
        return gen.generateInt16(sampleCount: sampleCount)
    }

    // MARK: - Full Pipeline

    @Test("Pipeline: Int16 44.1kHz stereo → Float32 48kHz mono")
    func fullPipelineInt16ToFloat32Mono() {
        let input = makeInt16Stereo(sampleCount: 441)

        // Step 1: Int16 → Float32
        let f32 = fmt.int16ToFloat32(input, channels: 2)
        #expect(f32.count == 441 * 2 * 4)

        // Step 2: 44100 → 48000
        let resampled = src.convert(
            f32, from: 44100, to: 48000, channels: 2, sampleFormat: .float32
        )
        let resampledFrames = resampled.count / (2 * 4)
        #expect(
            resampledFrames
                == src.outputSampleCount(
                    inputCount: 441, fromRate: 44100, toRate: 48000
                ))

        // Step 3: Stereo → Mono
        let mono = mix.stereoToMono(resampled)
        #expect(mono.count == resampledFrames * 4)
    }

    @Test("Pipeline: generate → convert → resample → mix → verify")
    func generateConvertResampleMix() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 1, frequency: 440
        )
        let pcm = gen.generateFloat32(sampleCount: 441)
        let resampled = src.convert(
            pcm, from: 44100, to: 48000, channels: 1, sampleFormat: .float32
        )
        let stereo = mix.monoToStereo(resampled)
        let outFrames = stereo.count / (2 * 4)
        let expected = src.outputSampleCount(
            inputCount: 441, fromRate: 44100, toRate: 48000
        )
        #expect(outFrames == expected)
    }

    // MARK: - Duration Preservation

    @Test("Format convert + resample: output duration matches input")
    func durationPreservation() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 2, frequency: 440
        )
        let input = gen.generateFloat32(sampleCount: 44100)
        let inputDur = fmt.duration(
            dataSize: input.count,
            format: .init(sampleRate: 44100, channels: 2)
        )

        let resampled = src.convert(
            input, from: 44100, to: 48000, channels: 2, sampleFormat: .float32
        )
        let outputDur = fmt.duration(
            dataSize: resampled.count,
            format: .init(sampleRate: 48000, channels: 2)
        )
        #expect(abs(inputDur - outputDur) < 0.01)
    }

    // MARK: - Channel Mix + Format Convert

    @Test("Channel mix + format convert: mono Int16 → stereo Float32")
    func monoInt16ToStereoFloat32() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 1, frequency: 440
        )
        let input = gen.generateInt16(sampleCount: 100)

        // Int16 → Float32
        let f32 = fmt.int16ToFloat32(input)

        // Mono → Stereo
        let stereo = mix.monoToStereo(f32)
        #expect(stereo.count == 100 * 2 * 4)
    }

    // MARK: - 5.1 Pipeline

    @Test("5.1 surround → stereo → mono pipeline")
    func surroundToMono() {
        // 10 frames of 5.1 surround
        var values = [Float]()
        for _ in 0..<10 {
            values.append(contentsOf: [0.3, 0.3, 0.5, 0.1, 0.2, 0.2])
        }
        let surround = makeFloat32(values)

        let stereo = mix.surroundToStereo(surround)
        #expect(stereo.count == 10 * 2 * 4)

        let mono = mix.stereoToMono(stereo)
        #expect(mono.count == 10 * 4)
    }

    // MARK: - Large Buffer

    @Test("Large buffer: 1s of 48kHz stereo Float32 → correct output")
    func largeBuffer() {
        let gen = PCMTestDataGenerator(
            sampleRate: 48000, channels: 2, frequency: 440
        )
        let input = gen.generateFloat32(sampleCount: 48000)
        #expect(input.count == 48000 * 2 * 4)

        let mono = mix.stereoToMono(input)
        #expect(mono.count == 48000 * 4)

        let resampled = src.convert(
            mono, from: 48000, to: 44100, channels: 1, sampleFormat: .float32
        )
        let outSamples = resampled.count / 4
        let expected = src.outputSampleCount(
            inputCount: 48000, fromRate: 48000, toRate: 44100
        )
        #expect(outSamples == expected)
    }

    // MARK: - Format Chain

    @Test("PCMFormat chain: cdQuality → standard → podcast")
    func formatChain() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 2, frequency: 440
        )
        let cd = gen.generateInt16(sampleCount: 100)

        // cdQuality → standard
        let standard = fmt.convert(cd, from: .cdQuality, to: .standard)
        #expect(standard.count == 100 * 2 * 4)

        // standard → podcast (just format, not rate/channels)
        let podcast = fmt.convert(
            standard,
            from: .standard,
            to: .init(sampleFormat: .float32, sampleRate: 48000, channels: 2)
        )
        #expect(podcast.count == standard.count)
    }

    // MARK: - Mixed Endianness

    @Test("Mixed endianness: big-endian Int16 → little-endian Float32")
    func mixedEndianness() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 2, frequency: 440
        )
        let leData = gen.generateInt16(sampleCount: 100)

        // Simulate big-endian Int16
        let beData = fmt.swapEndianness(leData, sampleFormat: .int16)

        // Convert from big-endian Int16 to little-endian Float32
        let beFormat = AudioFormatConverter.PCMFormat(
            sampleFormat: .int16, sampleRate: 44100,
            channels: 2, endianness: .big
        )
        let leFormat = AudioFormatConverter.PCMFormat.standard

        let result = fmt.convert(beData, from: beFormat, to: leFormat)
        #expect(result.count == 100 * 2 * 4)
    }

    // MARK: - Deinterleave Pipeline

    @Test("Deinterleave → process each channel → interleave")
    func deinterleaveProcessInterleave() {
        let data = makeFloat32([0.5, -0.5, 0.3, -0.3, 0.1, -0.1])
        let planar = fmt.deinterleave(
            data, channels: 2, sampleFormat: .float32
        )
        // Planar: [0.5, 0.3, 0.1, -0.5, -0.3, -0.1]
        let back = fmt.interleave(planar, channels: 2, sampleFormat: .float32)
        let original = readFloat32(data)
        let roundTrip = readFloat32(back)
        for i in 0..<original.count {
            #expect(abs(roundTrip[i] - original[i]) < 1e-5)
        }
    }

    // MARK: - Round-Trip

    @Test("Round-trip: all conversions preserve approximate values")
    func allConversionsRoundTrip() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 1, frequency: 440, amplitude: 0.5
        )
        let original = gen.generateFloat32(sampleCount: 100)
        let origValues = readFloat32(original)

        // Float32 → Int16 → Float32
        let i16 = fmt.float32ToInt16(original)
        let backF32 = fmt.int16ToFloat32(i16)
        let backValues = readFloat32(backF32)

        for i in 0..<origValues.count {
            #expect(abs(backValues[i] - origValues[i]) < 0.001)
        }
    }
}
