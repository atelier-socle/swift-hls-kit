// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Audio Helpers Showcase", .timeLimit(.minutes(1)))
struct AudioHelpersShowcaseTests {

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

    // MARK: - Podcast

    @Test("Podcast: 48kHz stereo → 44.1kHz mono for RSS")
    func podcastWorkflow() {
        let gen = PCMTestDataGenerator(
            sampleRate: 48000, channels: 2, frequency: 440
        )
        let input = gen.generateFloat32(sampleCount: 480)

        // Stereo → Mono
        let mono = mix.stereoToMono(input)
        #expect(mono.count == 480 * 4)

        // 48kHz → 44.1kHz
        let resampled = src.convert(
            mono, from: 48000, to: 44100, channels: 1, sampleFormat: .float32
        )
        let outSamples = resampled.count / 4
        #expect(
            outSamples
                == src.outputSampleCount(
                    inputCount: 480, fromRate: 48000, toRate: 44100
                ))
    }

    // MARK: - Music Streaming

    @Test("Music: CD quality → 48kHz for HLS")
    func musicStreaming() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 2, frequency: 440
        )
        let input = gen.generateInt16(sampleCount: 441)

        // Int16 → Float32
        let f32 = fmt.int16ToFloat32(input)

        // 44.1kHz → 48kHz
        let resampled = src.convert(
            f32, from: 44100, to: 48000, channels: 2, sampleFormat: .float32
        )
        let outFrames = resampled.count / (2 * 4)
        #expect(
            outFrames
                == src.outputSampleCount(
                    inputCount: 441, fromRate: 44100, toRate: 48000
                ))
    }

    // MARK: - Broadcast Downmix

    @Test("Broadcast: 5.1 surround → stereo HLS variant")
    func broadcastDownmix() {
        var values = [Float]()
        for i in 0..<100 {
            let v = Float(sin(Double(i) * 0.1)) * 0.3
            values.append(contentsOf: [v, v, v * 0.5, 0.1, v * 0.3, v * 0.3])
        }
        let surround = makeFloat32(values)
        let stereo = mix.surroundToStereo(surround)
        #expect(stereo.count == 100 * 2 * 4)

        // Verify no clipping
        let samples = stereo.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
        for s in samples {
            #expect(s >= -1.0 && s <= 1.0)
        }
    }

    // MARK: - Hi-Res to Standard

    @Test("Hi-res: 96kHz Int32 → 48kHz Int16 for streaming")
    func hiResToStandard() {
        // Generate Int32 data (simulate 24-bit in 32-bit container)
        let sampleCount = 960
        var data = Data(capacity: sampleCount * 4)
        for i in 0..<sampleCount {
            let v = Int32(sin(Double(i) * 0.05) * 100_000_000)
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }

        // Int32 → Float32
        let f32 = fmt.int32ToFloat32(data)

        // 96kHz → 48kHz
        let resampled = src.convert(
            f32, from: 96000, to: 48000, channels: 1, sampleFormat: .float32
        )
        let outSamples = resampled.count / 4
        #expect(outSamples == 480)

        // Float32 → Int16
        let i16 = fmt.float32ToInt16(resampled)
        #expect(i16.count == 480 * 2)
    }

    // MARK: - Live Radio

    @Test("Live radio: 22050Hz mono → 44100Hz stereo")
    func liveRadio() {
        let gen = PCMTestDataGenerator(
            sampleRate: 22050, channels: 1, frequency: 440
        )
        let input = gen.generateFloat32(sampleCount: 221)

        // 22050 → 44100
        let resampled = src.convert(
            input, from: 22050, to: 44100, channels: 1, sampleFormat: .float32
        )
        #expect(resampled.count == 442 * 4)

        // Mono → Stereo
        let stereo = mix.monoToStereo(resampled)
        #expect(stereo.count == 442 * 2 * 4)
    }

    // MARK: - Multi-Format Export

    @Test("Multi-format: single source → 3 output formats")
    func multiFormatExport() {
        let gen = PCMTestDataGenerator(
            sampleRate: 48000, channels: 2, frequency: 440
        )
        let source = gen.generateFloat32(sampleCount: 480)

        // Low: mono, 22050Hz, Int16
        let loMono = mix.stereoToMono(source)
        let loResampled = src.convert(
            loMono, from: 48000, to: 22050, channels: 1, sampleFormat: .float32
        )
        let loInt16 = fmt.float32ToInt16(loResampled)
        #expect(loInt16.count > 0)

        // Mid: stereo, 44100Hz, Float32
        let mid = src.convert(
            source, from: 48000, to: 44100, channels: 2, sampleFormat: .float32
        )
        #expect(mid.count > 0)

        // High: stereo, 48000Hz, Float32 (original)
        #expect(source.count == 480 * 2 * 4)
    }

    // MARK: - Interleave Workflow

    @Test("Interleave: planar processing → interleaved output")
    func interleaveWorkflow() {
        let gen = PCMTestDataGenerator(
            sampleRate: 44100, channels: 2, frequency: 440
        )
        let interleaved = gen.generateFloat32(sampleCount: 100)

        // Deinterleave for per-channel processing
        let planar = fmt.deinterleave(
            interleaved, channels: 2, sampleFormat: .float32
        )

        // Re-interleave
        let back = fmt.interleave(
            planar, channels: 2, sampleFormat: .float32
        )
        #expect(back.count == interleaved.count)
    }

    // MARK: - Conference Audio

    @Test("Conference: 16kHz mono → 48kHz stereo podcast")
    func conferenceAudio() {
        // Simulate 16kHz mono telephony audio
        let sampleCount = 160
        var data = Data(capacity: sampleCount * 4)
        for i in 0..<sampleCount {
            let v = Float(sin(Double(i) * 0.3)) * 0.5
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }

        // 16000 → 48000
        let resampled = src.convert(
            data, from: 16000, to: 48000, channels: 1, sampleFormat: .float32
        )
        let outSamples = resampled.count / 4
        #expect(
            outSamples
                == src.outputSampleCount(
                    inputCount: 160, fromRate: 16000, toRate: 48000
                ))

        // Mono → Stereo
        let stereo = mix.monoToStereo(resampled)
        #expect(stereo.count == outSamples * 2 * 4)
    }
}
