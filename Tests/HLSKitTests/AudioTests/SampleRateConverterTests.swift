// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SampleRateConverter", .timeLimit(.minutes(1)))
struct SampleRateConverterTests {

    let converter = SampleRateConverter()

    // MARK: - Helpers

    private func makeFloat32Mono(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * 4)
        for v in values {
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func makeFloat32Stereo(frames: Int) -> Data {
        var data = Data(capacity: frames * 2 * 4)
        for i in 0..<frames {
            let v = Float(sin(2.0 * .pi * 440.0 * Double(i) / 44100.0))
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }
        return data
    }

    // MARK: - Sample Count

    @Test("44100→48000: output has correct sample count")
    func upsampling44To48() {
        let data = makeFloat32Mono(Array(repeating: 0.5, count: 441))
        let result = converter.convert(
            data, from: 44100, to: 48000, channels: 1, sampleFormat: .float32
        )
        let expected = converter.outputSampleCount(
            inputCount: 441, fromRate: 44100, toRate: 48000
        )
        #expect(result.count == expected * 4)
    }

    @Test("48000→44100: output has correct sample count")
    func downsampling48To44() {
        let data = makeFloat32Mono(Array(repeating: 0.5, count: 480))
        let result = converter.convert(
            data, from: 48000, to: 44100, channels: 1, sampleFormat: .float32
        )
        let expected = converter.outputSampleCount(
            inputCount: 480, fromRate: 48000, toRate: 44100
        )
        #expect(result.count == expected * 4)
    }

    @Test("Same rate → identity")
    func sameRateIdentity() {
        let data = makeFloat32Mono([0.5, -0.5, 0.25])
        let result = converter.convert(
            data, from: 44100, to: 44100, channels: 1, sampleFormat: .float32
        )
        #expect(result == data)
    }

    // MARK: - Integer Ratio

    @Test("44100→88200: 2× upsampling, output is 2× length")
    func upsample2x() {
        let data = makeFloat32Mono(Array(repeating: 0.5, count: 100))
        let result = converter.convert(
            data, from: 44100, to: 88200, channels: 1, sampleFormat: .float32
        )
        #expect(result.count == 200 * 4)
    }

    @Test("88200→44100: 2× downsampling, output is ½ length")
    func downsample2x() {
        let data = makeFloat32Mono(Array(repeating: 0.5, count: 200))
        let result = converter.convert(
            data, from: 88200, to: 44100, channels: 1, sampleFormat: .float32
        )
        #expect(result.count == 100 * 4)
    }

    @Test("48000→96000: 2× upsampling")
    func upsample48To96() {
        let data = makeFloat32Mono(Array(repeating: 0.3, count: 48))
        let result = converter.convert(
            data, from: 48000, to: 96000, channels: 1, sampleFormat: .float32
        )
        #expect(result.count == 96 * 4)
    }

    @Test("22050→44100: 2× upsampling")
    func upsample22To44() {
        let data = makeFloat32Mono(Array(repeating: 0.7, count: 22))
        let result = converter.convert(
            data, from: 22050, to: 44100, channels: 1, sampleFormat: .float32
        )
        #expect(result.count == 44 * 4)
    }

    // MARK: - Simple Ratio

    @Test("isSimpleRatio: 44100→88200 is true")
    func simpleRatio44To88() {
        #expect(converter.isSimpleRatio(from: 44100, to: 88200))
    }

    @Test("isSimpleRatio: 44100→48000 is false")
    func notSimpleRatio44To48() {
        #expect(!converter.isSimpleRatio(from: 44100, to: 48000))
    }

    // MARK: - Output Calculations

    @Test("outputSampleCount calculation")
    func outputSampleCountCalc() {
        let count = converter.outputSampleCount(
            inputCount: 44100, fromRate: 44100, toRate: 48000
        )
        #expect(count == 48000)
    }

    @Test("outputDataSize calculation")
    func outputDataSizeCalc() {
        let size = converter.outputDataSize(
            inputSize: 44100 * 4, fromRate: 44100, toRate: 48000,
            sampleFormat: .float32
        )
        #expect(size == 48000 * 4)
    }

    // MARK: - Multi-Channel

    @Test("Stereo conversion preserves channel count")
    func stereoConversion() {
        let data = makeFloat32Stereo(frames: 100)
        let result = converter.convert(
            data, from: 44100, to: 48000, channels: 2, sampleFormat: .float32
        )
        let outFrames = result.count / (2 * 4)
        let expected = converter.outputSampleCount(
            inputCount: 100, fromRate: 44100, toRate: 48000
        )
        #expect(outFrames == expected)
    }

    // MARK: - Configuration

    @Test("Configuration.standard preset")
    func standardConfig() {
        let config = SampleRateConverter.Configuration.standard
        #expect(config.quality == .fast)
    }

    @Test("Configuration.highQuality preset")
    func highQualityConfig() {
        let config = SampleRateConverter.Configuration.highQuality
        #expect(config.quality == .best)
    }

    // MARK: - Medium Quality

    @Test("Medium quality: downsampling applies pre-filter")
    func mediumQualityDownsample() {
        let conv = SampleRateConverter(
            configuration: .init(quality: .medium)
        )
        let data = makeFloat32Mono(Array(repeating: 0.5, count: 200))
        let result = conv.convert(
            data, from: 88200, to: 44100, channels: 1, sampleFormat: .float32
        )
        #expect(result.count == 100 * 4)
    }

    @Test("Medium quality: upsampling uses linear")
    func mediumQualityUpsample() {
        let conv = SampleRateConverter(
            configuration: .init(quality: .medium)
        )
        let data = makeFloat32Mono(Array(repeating: 0.5, count: 100))
        let result = conv.convert(
            data, from: 44100, to: 88200, channels: 1, sampleFormat: .float32
        )
        #expect(result.count == 200 * 4)
    }

    @Test("Medium quality stereo downsampling")
    func mediumQualityStereoDownsample() {
        let conv = SampleRateConverter(
            configuration: .init(quality: .medium)
        )
        let data = makeFloat32Stereo(frames: 200)
        let result = conv.convert(
            data, from: 96000, to: 48000, channels: 2, sampleFormat: .float32
        )
        let outFrames = result.count / (2 * 4)
        #expect(outFrames == 100)
    }

    // MARK: - Best Quality (Sinc)

    @Test("Best quality: upsample preserves sample count")
    func bestQualityUpsample() {
        let conv = SampleRateConverter(
            configuration: .init(quality: .best)
        )
        let data = makeFloat32Mono(Array(repeating: 0.5, count: 100))
        let result = conv.convert(
            data, from: 44100, to: 48000, channels: 1, sampleFormat: .float32
        )
        let expected = conv.outputSampleCount(
            inputCount: 100, fromRate: 44100, toRate: 48000
        )
        #expect(result.count == expected * 4)
    }

    @Test("Best quality: downsample preserves sample count")
    func bestQualityDownsample() {
        let conv = SampleRateConverter(
            configuration: .init(quality: .best)
        )
        let data = makeFloat32Mono(Array(repeating: 0.5, count: 200))
        let result = conv.convert(
            data, from: 88200, to: 44100, channels: 1, sampleFormat: .float32
        )
        #expect(result.count == 100 * 4)
    }

    @Test("Best quality stereo conversion")
    func bestQualityStereo() {
        let conv = SampleRateConverter(
            configuration: .init(quality: .best)
        )
        let data = makeFloat32Stereo(frames: 100)
        let result = conv.convert(
            data, from: 44100, to: 48000, channels: 2, sampleFormat: .float32
        )
        let outFrames = result.count / (2 * 4)
        let expected = conv.outputSampleCount(
            inputCount: 100, fromRate: 44100, toRate: 48000
        )
        #expect(outFrames == expected)
    }

    // MARK: - Int16 Format Conversion

    @Test("Conversion with Int16 format does internal Float32 round-trip")
    func int16FormatConversion() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 1, frequency: 440
        )
        let data = gen.generateInt16(sampleCount: 441)
        let result = converter.convert(
            data, from: 44100, to: 48000, channels: 1, sampleFormat: .int16
        )
        let expected = converter.outputSampleCount(
            inputCount: 441, fromRate: 44100, toRate: 48000
        )
        #expect(result.count == expected * 2)
    }

    // MARK: - Edge Cases

    @Test("Empty data → empty result")
    func emptyData() {
        let result = converter.convert(
            Data(), from: 44100, to: 48000, channels: 1, sampleFormat: .float32
        )
        #expect(result.isEmpty)
    }

    @Test("StandardRate has all expected cases")
    func standardRateCases() {
        #expect(SampleRateConverter.StandardRate.allCases.count == 7)
        #expect(SampleRateConverter.StandardRate.hz44100.rawValue == 44100)
        #expect(SampleRateConverter.StandardRate.hz48000.rawValue == 48000)
    }
}
