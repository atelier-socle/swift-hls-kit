// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - DolbyAtmosEncoder

@Suite("DolbyAtmosEncoder — Properties & Validation")
struct DolbyAtmosEncoderTests {

    @Test("Init with defaults")
    func initDefaults() {
        let encoder = DolbyAtmosEncoder()
        #expect(encoder.format == .dolbyAtmos)
        #expect(encoder.channelLayout == .atmos7_1_4)
        #expect(encoder.bitrate == 768_000)
    }

    @Test("Init with custom layout and bitrate")
    func initCustom() {
        let encoder = DolbyAtmosEncoder(
            channelLayout: .surround7_1,
            bitrate: 1_000_000
        )
        #expect(encoder.channelLayout == .surround7_1)
        #expect(encoder.bitrate == 1_000_000)
    }

    @Test("Format is always dolbyAtmos")
    func formatIsAtmos() {
        let encoder = DolbyAtmosEncoder(channelLayout: .surround5_1)
        #expect(encoder.format == .dolbyAtmos)
    }

    @Test("validateLayout succeeds for atmos7_1_4")
    func validateAtmos714() throws {
        let encoder = DolbyAtmosEncoder(channelLayout: .atmos7_1_4)
        try encoder.validateLayout()
    }

    @Test("validateLayout succeeds for 7.1")
    func validate71() throws {
        let encoder = DolbyAtmosEncoder(channelLayout: .surround7_1)
        try encoder.validateLayout()
    }

    @Test("validateLayout succeeds for 5.1")
    func validate51() throws {
        let encoder = DolbyAtmosEncoder(channelLayout: .surround5_1)
        try encoder.validateLayout()
    }

    @Test("validateLayout throws for stereo")
    func validateStereoThrows() {
        let encoder = DolbyAtmosEncoder(channelLayout: .stereo)
        #expect(throws: SpatialAudioEncoderError.self) {
            try encoder.validateLayout()
        }
    }

    @Test("validateLayout throws for mono")
    func validateMonoThrows() {
        let encoder = DolbyAtmosEncoder(channelLayout: .mono)
        #expect(throws: SpatialAudioEncoderError.self) {
            try encoder.validateLayout()
        }
    }

    @Test("flush returns nil")
    func flushReturnsNil() throws {
        let encoder = DolbyAtmosEncoder()
        let result = try encoder.flush()
        #expect(result == nil)
    }

    #if canImport(AudioToolbox)
        @Test("encode with empty data throws invalidInput")
        func encodeEmptyThrows() {
            let encoder = DolbyAtmosEncoder()
            #expect(throws: SpatialAudioEncoderError.self) {
                _ = try encoder.encode(pcmData: Data(), sampleRate: 48000)
            }
        }

        @Test("encode with valid data returns compressed output")
        func encodeValidData() throws {
            let encoder = DolbyAtmosEncoder(channelLayout: .surround5_1)
            let pcm = Data(repeating: 0, count: 4096)
            let result = try encoder.encode(pcmData: pcm, sampleRate: 48000)
            #expect(result.count > 0)
            #expect(result.count < pcm.count)
        }
    #endif
}

// MARK: - AC3Encoder

@Suite("AC3Encoder — Properties & Validation")
struct AC3EncoderTests {

    @Test("Init with default E-AC-3")
    func initDefaultEAC3() {
        let encoder = AC3Encoder()
        #expect(encoder.variant == .eac3)
        #expect(encoder.channelLayout == .surround5_1)
        #expect(encoder.bitrate == 384_000)
        #expect(encoder.format == .dolbyDigitalPlus)
    }

    @Test("Init with AC-3 variant")
    func initAC3() {
        let encoder = AC3Encoder(variant: .ac3)
        #expect(encoder.variant == .ac3)
        #expect(encoder.format == .dolbyDigital)
    }

    @Test("AC-3 bitrate range is 192k–640k")
    func ac3BitrateRange() {
        let encoder = AC3Encoder(variant: .ac3)
        #expect(encoder.bitrateRange == 192_000...640_000)
    }

    @Test("E-AC-3 bitrate range is 96k–6144k")
    func eac3BitrateRange() {
        let encoder = AC3Encoder(variant: .eac3)
        #expect(encoder.bitrateRange == 96_000...6_144_000)
    }

    @Test("AC-3 maxChannels is 6")
    func ac3MaxChannels() {
        let encoder = AC3Encoder(variant: .ac3)
        #expect(encoder.maxChannels == 6)
    }

    @Test("E-AC-3 maxChannels is 8")
    func eac3MaxChannels() {
        let encoder = AC3Encoder(variant: .eac3)
        #expect(encoder.maxChannels == 8)
    }

    @Test("AC-3 validate throws for 7.1 layout")
    func ac3ValidateTooManyChannels() {
        let encoder = AC3Encoder(
            variant: .ac3,
            channelLayout: .surround7_1
        )
        #expect(throws: SpatialAudioEncoderError.self) {
            try encoder.validate()
        }
    }

    @Test("AC-3 validate throws for out-of-range bitrate")
    func ac3ValidateBitrate() {
        let encoder = AC3Encoder(
            variant: .ac3,
            channelLayout: .surround5_1,
            bitrate: 100_000
        )
        #expect(throws: SpatialAudioEncoderError.self) {
            try encoder.validate()
        }
    }

    @Test("E-AC-3 validate succeeds for 7.1 at 384k")
    func eac3ValidateSuccess() throws {
        let encoder = AC3Encoder(
            variant: .eac3,
            channelLayout: .surround7_1,
            bitrate: 384_000
        )
        try encoder.validate()
    }

    @Test("flush returns nil")
    func flushReturnsNil() throws {
        let encoder = AC3Encoder()
        let result = try encoder.flush()
        #expect(result == nil)
    }

    @Test("Variant is CaseIterable with 2 cases")
    func variantCaseIterable() {
        #expect(AC3Encoder.Variant.allCases.count == 2)
    }
}

// MARK: - SpatialAudioEncoderError

@Suite("SpatialAudioEncoderError — Equatable")
struct SpatialAudioEncoderErrorTests {

    @Test("Same errors are equal")
    func sameErrorsEqual() {
        let a = SpatialAudioEncoderError.unsupportedPlatform
        let b = SpatialAudioEncoderError.unsupportedPlatform
        #expect(a == b)
    }

    @Test("Different errors are not equal")
    func differentErrorsNotEqual() {
        let a = SpatialAudioEncoderError.unsupportedPlatform
        let b = SpatialAudioEncoderError.encodingFailed("test")
        #expect(a != b)
    }

    @Test("bitrateOutOfRange errors with same values are equal")
    func bitrateErrorEqual() {
        let a = SpatialAudioEncoderError.bitrateOutOfRange(
            requested: 100, valid: 200...500
        )
        let b = SpatialAudioEncoderError.bitrateOutOfRange(
            requested: 100, valid: 200...500
        )
        #expect(a == b)
    }

    @Test("unsupportedFormat errors compare correctly")
    func formatErrorCompare() {
        let a = SpatialAudioEncoderError.unsupportedFormat(.dolbyAtmos)
        let b = SpatialAudioEncoderError.unsupportedFormat(.dolbyDigital)
        #expect(a != b)
    }

    @Test("unsupportedLayout errors compare correctly")
    func layoutErrorCompare() {
        let a = SpatialAudioEncoderError.unsupportedLayout(.stereo)
        let b = SpatialAudioEncoderError.unsupportedLayout(.stereo)
        #expect(a == b)
    }
}
