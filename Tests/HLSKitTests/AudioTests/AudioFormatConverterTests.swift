// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AudioFormatConverter", .timeLimit(.minutes(1)))
struct AudioFormatConverterTests {

    let converter = AudioFormatConverter()

    // MARK: - Helpers

    private func makeInt16(_ values: [Int16]) -> Data {
        var data = Data(capacity: values.count * 2)
        for v in values {
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func makeFloat32(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * 4)
        for v in values {
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func makeInt32(_ values: [Int32]) -> Data {
        var data = Data(capacity: values.count * 4)
        for v in values {
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func readFloat32(_ data: Data) -> [Float] {
        data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }

    private func readInt16(_ data: Data) -> [Int16] {
        data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Int16.self))
        }
    }

    private func readInt32(_ data: Data) -> [Int32] {
        data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Int32.self))
        }
    }

    // MARK: - Int16 ↔ Float32

    @Test("Int16 to Float32: known values")
    func int16ToFloat32KnownValues() {
        let data = makeInt16([0, 32767, -32768])
        let floats = readFloat32(converter.int16ToFloat32(data))
        #expect(abs(floats[0] - 0.0) < 1e-5)
        #expect(abs(floats[1] - (32767.0 / 32768.0)) < 1e-4)
        #expect(abs(floats[2] - (-1.0)) < 1e-5)
    }

    @Test("Float32 to Int16: clamping")
    func float32ToInt16Clamping() {
        let data = makeFloat32([1.5, -1.5, 0.5])
        let ints = readInt16(converter.float32ToInt16(data))
        #expect(ints[0] == 32767)
        #expect(ints[1] == -32767)
        #expect(abs(ints[2] - 16383) <= 1)
    }

    @Test("Float32 to Int16: round-trip accuracy")
    func float32Int16RoundTrip() {
        let original = makeFloat32([0.0, 0.5, -0.5, 0.25, -0.75])
        let int16Data = converter.float32ToInt16(original)
        let roundTrip = readFloat32(converter.int16ToFloat32(int16Data))
        let originals = readFloat32(original)
        for i in 0..<originals.count {
            #expect(abs(roundTrip[i] - originals[i]) < 0.001)
        }
    }

    // MARK: - Int16 ↔ Int32

    @Test("Int16 to Int32: left-shift by 16")
    func int16ToInt32LeftShift() {
        let data = makeInt16([1, -1, 100, -100])
        let ints = readInt32(converter.int16ToInt32(data))
        #expect(ints[0] == 1 << 16)
        #expect(ints[1] == -1 << 16)
        #expect(ints[2] == 100 << 16)
        #expect(ints[3] == -100 << 16)
    }

    @Test("Int32 to Int16: right-shift by 16")
    func int32ToInt16RightShift() {
        let data = makeInt32([65536, -65536, 6_553_600, -6_553_600])
        let ints = readInt16(converter.int32ToInt16(data))
        #expect(ints[0] == 1)
        #expect(ints[1] == -1)
        #expect(ints[2] == 100)
        #expect(ints[3] == -100)
    }

    // MARK: - Float32 ↔ Int32

    @Test("Float32 to Int32: full range")
    func float32ToInt32FullRange() {
        let data = makeFloat32([0.0, 1.0, -1.0])
        let ints = readInt32(converter.float32ToInt32(data))
        #expect(ints[0] == 0)
        #expect(ints[1] == 2_147_483_647)
        #expect(ints[2] == -2_147_483_647)
    }

    @Test("Int32 to Float32: full range")
    func int32ToFloat32FullRange() {
        let data = makeInt32([0, 2_147_483_647, -2_147_483_648])
        let floats = readFloat32(converter.int32ToFloat32(data))
        #expect(abs(floats[0]) < 1e-5)
        #expect(abs(floats[1] - 1.0) < 1e-5)
        #expect(abs(floats[2] - (-1.0)) < 1e-5)
    }

    // MARK: - Generic Convert

    @Test("Generic convert: Int16 → Float32 → Int16 round-trip")
    func genericConvertRoundTrip() {
        let original = makeInt16([0, 1000, -1000, 16383])
        let f32 = converter.convert(original, from: .int16, to: .float32)
        let back = converter.convert(f32, from: .float32, to: .int16)
        let origInts = readInt16(original)
        let backInts = readInt16(back)
        for i in 0..<origInts.count {
            #expect(abs(Int(origInts[i]) - Int(backInts[i])) <= 1)
        }
    }

    @Test("Generic convert: same format returns identity")
    func genericConvertSameFormat() {
        let data = makeFloat32([0.5, -0.5])
        let result = converter.convert(data, from: .float32, to: .float32)
        #expect(result == data)
    }

    // MARK: - Layout Conversion

    @Test("Deinterleave stereo: L0R0L1R1 → L0L1 R0R1")
    func deinterleaveStereo() {
        let data = makeFloat32([1.0, 2.0, 3.0, 4.0])
        let planar = converter.deinterleave(data, channels: 2, sampleFormat: .float32)
        let values = readFloat32(planar)
        #expect(values == [1.0, 3.0, 2.0, 4.0])
    }

    @Test("Interleave stereo: L0L1 R0R1 → L0R0L1R1")
    func interleaveStereo() {
        let data = makeFloat32([1.0, 3.0, 2.0, 4.0])
        let interleaved = converter.interleave(data, channels: 2, sampleFormat: .float32)
        let values = readFloat32(interleaved)
        #expect(values == [1.0, 2.0, 3.0, 4.0])
    }

    @Test("Deinterleave + interleave round-trip = identity")
    func deinterleaveInterleaveRoundTrip() {
        let data = makeFloat32([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
        let planar = converter.deinterleave(data, channels: 2, sampleFormat: .float32)
        let back = converter.interleave(planar, channels: 2, sampleFormat: .float32)
        #expect(readFloat32(back) == readFloat32(data))
    }

    @Test("Deinterleave 3 channels")
    func deinterleave3Channels() {
        // A0 B0 C0 A1 B1 C1
        let data = makeFloat32([1.0, 2.0, 3.0, 4.0, 5.0, 6.0])
        let planar = converter.deinterleave(data, channels: 3, sampleFormat: .float32)
        let values = readFloat32(planar)
        // Expected: A0 A1 B0 B1 C0 C1
        #expect(values == [1.0, 4.0, 2.0, 5.0, 3.0, 6.0])
    }

    // MARK: - Endianness

    @Test("Swap endianness Int16: round-trip = identity")
    func swapEndiannessInt16RoundTrip() {
        let data = makeInt16([1234, -5678])
        let swapped = converter.swapEndianness(data, sampleFormat: .int16)
        #expect(swapped != data)
        let back = converter.swapEndianness(swapped, sampleFormat: .int16)
        #expect(back == data)
    }

    @Test("Swap endianness Float32: round-trip = identity")
    func swapEndiannessFloat32RoundTrip() {
        let data = makeFloat32([0.5, -0.25])
        let swapped = converter.swapEndianness(data, sampleFormat: .float32)
        let back = converter.swapEndianness(swapped, sampleFormat: .float32)
        #expect(back == data)
    }

    // MARK: - Full Format Conversion

    @Test("Full format conversion: cdQuality → standard")
    func fullFormatConversion() {
        let data = makeInt16([1000, -1000, 500, -500])
        let result = converter.convert(data, from: .cdQuality, to: .standard)
        #expect(result.count == 4 * 4)
        let floats = readFloat32(result)
        #expect(abs(floats[0] - (1000.0 / 32768.0)) < 0.001)
    }

    // MARK: - PCMFormat Presets

    @Test("PCMFormat.standard preset")
    func standardPreset() {
        let fmt = AudioFormatConverter.PCMFormat.standard
        #expect(fmt.sampleFormat == .float32)
        #expect(fmt.sampleRate == 48000)
        #expect(fmt.channels == 2)
        #expect(fmt.layout == .interleaved)
        #expect(fmt.endianness == .little)
    }

    @Test("PCMFormat.cdQuality preset")
    func cdQualityPreset() {
        let fmt = AudioFormatConverter.PCMFormat.cdQuality
        #expect(fmt.sampleFormat == .int16)
        #expect(fmt.sampleRate == 44100)
        #expect(fmt.channels == 2)
    }

    @Test("PCMFormat.podcast preset")
    func podcastPreset() {
        let fmt = AudioFormatConverter.PCMFormat.podcast
        #expect(fmt.sampleFormat == .float32)
        #expect(fmt.sampleRate == 44100)
        #expect(fmt.channels == 1)
    }

    // MARK: - Bytes Per Sample / Frame

    @Test("bytesPerSample correct for each format")
    func bytesPerSample() {
        #expect(AudioFormatConverter.SampleFormat.int16.bytesPerSample == 2)
        #expect(AudioFormatConverter.SampleFormat.int32.bytesPerSample == 4)
        #expect(AudioFormatConverter.SampleFormat.float32.bytesPerSample == 4)
    }

    @Test("bytesPerFrame = bytesPerSample × channels")
    func bytesPerFrame() {
        let stereo = AudioFormatConverter.PCMFormat.standard
        #expect(stereo.bytesPerFrame == 8)
        let mono = AudioFormatConverter.PCMFormat.podcast
        #expect(mono.bytesPerFrame == 4)
        let cd = AudioFormatConverter.PCMFormat.cdQuality
        #expect(cd.bytesPerFrame == 4)
    }

    // MARK: - Utilities

    @Test("sampleCount calculation")
    func sampleCountCalc() {
        let fmt = AudioFormatConverter.PCMFormat.standard
        #expect(converter.sampleCount(dataSize: 800, format: fmt) == 100)
    }

    @Test("duration calculation")
    func durationCalc() {
        let fmt = AudioFormatConverter.PCMFormat.standard
        let dur = converter.duration(dataSize: 48000 * 8, format: fmt)
        #expect(abs(dur - 1.0) < 0.001)
    }

    @Test("dataSize calculation")
    func dataSizeCalc() {
        let fmt = AudioFormatConverter.PCMFormat.standard
        #expect(converter.dataSize(duration: 1.0, format: fmt) == 48000 * 8)
    }

    // MARK: - Endianness in Full Format

    @Test("Full format: little→big endianness conversion")
    func fullFormatLittleToBig() {
        let data = makeInt16([1000, -1000])
        let leFormat = AudioFormatConverter.PCMFormat(
            sampleFormat: .int16, sampleRate: 44100, channels: 1
        )
        let beFormat = AudioFormatConverter.PCMFormat(
            sampleFormat: .int16, sampleRate: 44100,
            channels: 1, endianness: .big
        )
        let result = converter.convert(data, from: leFormat, to: beFormat)
        let back = converter.convert(result, from: beFormat, to: leFormat)
        #expect(readInt16(back) == readInt16(data))
    }

    @Test("Full format: layout change interleaved→planar")
    func fullFormatLayoutChange() {
        let data = makeFloat32([1.0, 2.0, 3.0, 4.0])
        let interleavedFmt = AudioFormatConverter.PCMFormat(
            sampleFormat: .float32, sampleRate: 48000, channels: 2
        )
        let planarFmt = AudioFormatConverter.PCMFormat(
            sampleFormat: .float32, sampleRate: 48000,
            channels: 2, layout: .nonInterleaved
        )
        let planar = converter.convert(
            data, from: interleavedFmt, to: planarFmt
        )
        let values = readFloat32(planar)
        #expect(values == [1.0, 3.0, 2.0, 4.0])
    }

    // MARK: - Edge Cases

    @Test("Empty data → empty result")
    func emptyDataNosCrash() {
        #expect(converter.int16ToFloat32(Data()).isEmpty)
        #expect(converter.float32ToInt16(Data()).isEmpty)
        #expect(converter.int16ToInt32(Data()).isEmpty)
        #expect(converter.int32ToInt16(Data()).isEmpty)
        #expect(converter.float32ToInt32(Data()).isEmpty)
        #expect(converter.int32ToFloat32(Data()).isEmpty)
        #expect(converter.deinterleave(Data(), channels: 2, sampleFormat: .float32).isEmpty)
        #expect(converter.swapEndianness(Data(), sampleFormat: .int16).isEmpty)
    }
}
