// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AudioFormat")
struct AudioFormatTests {

    // MARK: - AudioCodec

    @Test("AudioCodec: all cases count")
    func audioCodecAllCases() {
        let cases = AudioCodec.allCases
        #expect(cases.count == 12)
    }

    @Test("AudioCodec: PCM variants")
    func audioCodecPCMVariants() {
        #expect(AudioCodec.pcmInt16.isPCM)
        #expect(AudioCodec.pcmInt24.isPCM)
        #expect(AudioCodec.pcmInt32.isPCM)
        #expect(AudioCodec.pcmFloat32.isPCM)
        #expect(AudioCodec.pcmFloat64.isPCM)
    }

    @Test("AudioCodec: compressed codecs are not PCM")
    func audioCodecCompressedNotPCM() {
        #expect(!AudioCodec.aac.isPCM)
        #expect(!AudioCodec.opus.isPCM)
        #expect(!AudioCodec.mp3.isPCM)
        #expect(!AudioCodec.ac3.isPCM)
        #expect(!AudioCodec.eac3.isPCM)
        #expect(!AudioCodec.alac.isPCM)
        #expect(!AudioCodec.flac.isPCM)
    }

    @Test("AudioCodec: lossless codecs")
    func audioCodecLossless() {
        #expect(AudioCodec.pcmInt16.isLossless)
        #expect(AudioCodec.pcmInt24.isLossless)
        #expect(AudioCodec.alac.isLossless)
        #expect(AudioCodec.flac.isLossless)
        #expect(!AudioCodec.aac.isLossless)
        #expect(!AudioCodec.mp3.isLossless)
    }

    @Test("AudioCodec: HLS codec strings")
    func audioCodecHLSStrings() {
        #expect(AudioCodec.aac.hlsCodecString == "mp4a.40.2")
        #expect(AudioCodec.ac3.hlsCodecString == "ac-3")
        #expect(AudioCodec.eac3.hlsCodecString == "ec-3")
        #expect(AudioCodec.flac.hlsCodecString == "fLaC")
        #expect(AudioCodec.opus.hlsCodecString == "Opus")
        #expect(AudioCodec.alac.hlsCodecString == "alac")
        #expect(AudioCodec.pcmInt16.hlsCodecString == nil)
    }

    @Test("AudioCodec: raw values")
    func audioCodecRawValues() {
        #expect(AudioCodec.aac.rawValue == "aac")
        #expect(AudioCodec.pcmInt16.rawValue == "pcmInt16")
        #expect(AudioCodec.ac3.rawValue == "ac3")
    }

    // MARK: - AACProfile

    @Test("AACProfile: all cases")
    func aacProfileAllCases() {
        let cases = AACProfile.allCases
        #expect(cases.count == 5)
        #expect(cases.contains(.lc))
        #expect(cases.contains(.he))
        #expect(cases.contains(.heV2))
        #expect(cases.contains(.ld))
        #expect(cases.contains(.eld))
    }

    @Test("AACProfile: HLS codec strings")
    func aacProfileHLSStrings() {
        #expect(AACProfile.lc.hlsCodecString == "mp4a.40.2")
        #expect(AACProfile.he.hlsCodecString == "mp4a.40.5")
        #expect(AACProfile.heV2.hlsCodecString == "mp4a.40.29")
        #expect(AACProfile.ld.hlsCodecString == "mp4a.40.23")
        #expect(AACProfile.eld.hlsCodecString == "mp4a.40.39")
    }

    // MARK: - AudioFormat Initialization

    @Test("AudioFormat: basic initialization")
    func audioFormatBasicInit() {
        let format = AudioFormat(
            codec: .aac,
            sampleRate: 48000,
            channels: 2
        )
        #expect(format.codec == .aac)
        #expect(format.sampleRate == 48000)
        #expect(format.channels == 2)
        #expect(format.bitsPerSample == nil)
        #expect(!format.isFloat)
        #expect(format.isInterleaved)
    }

    @Test("AudioFormat: full initialization")
    func audioFormatFullInit() {
        let format = AudioFormat(
            codec: .pcmInt24,
            sampleRate: 96000,
            channels: 2,
            bitsPerSample: 24,
            isFloat: false,
            isInterleaved: true,
            bitrate: nil,
            aacProfile: nil
        )
        #expect(format.codec == .pcmInt24)
        #expect(format.sampleRate == 96000)
        #expect(format.bitsPerSample == 24)
    }

    // MARK: - Convenience Constructors

    @Test("AudioFormat.pcm: default stereo 16-bit")
    func audioFormatPCMDefault() {
        let format = AudioFormat.pcm()
        #expect(format.codec == .pcmInt16)
        #expect(format.sampleRate == 48000)
        #expect(format.channels == 2)
        #expect(format.bitsPerSample == 16)
        #expect(!format.isFloat)
    }

    @Test("AudioFormat.pcm: 24-bit hi-res")
    func audioFormatPCM24Bit() {
        let format = AudioFormat.pcm(sampleRate: 96000, bitsPerSample: 24)
        #expect(format.codec == .pcmInt24)
        #expect(format.sampleRate == 96000)
        #expect(format.bitsPerSample == 24)
    }

    @Test("AudioFormat.aac: default AAC-LC")
    func audioFormatAACDefault() {
        let format = AudioFormat.aac()
        #expect(format.codec == .aac)
        #expect(format.sampleRate == 48000)
        #expect(format.channels == 2)
        #expect(format.bitrate == 128_000)
        #expect(format.aacProfile == .lc)
    }

    @Test("AudioFormat.aac: custom bitrate and profile")
    func audioFormatAACCustom() {
        let format = AudioFormat.aac(bitrate: 256_000, profile: .he)
        #expect(format.bitrate == 256_000)
        #expect(format.aacProfile == .he)
    }

    @Test("AudioFormat.float32: default")
    func audioFormatFloat32Default() {
        let format = AudioFormat.float32()
        #expect(format.codec == .pcmFloat32)
        #expect(format.sampleRate == 48000)
        #expect(format.channels == 2)
        #expect(format.bitsPerSample == 32)
        #expect(format.isFloat)
    }

    @Test("AudioFormat.hiRes: 96kHz 24-bit")
    func audioFormatHiRes() {
        let format = AudioFormat.hiRes()
        #expect(format.codec == .pcmInt24)
        #expect(format.sampleRate == 96000)
        #expect(format.bitsPerSample == 24)
    }

    // MARK: - Computed Properties

    @Test("AudioFormat: bytesPerSample")
    func audioFormatBytesPerSample() {
        let format16 = AudioFormat.pcm(bitsPerSample: 16)
        let format24 = AudioFormat.pcm(bitsPerSample: 24)
        let format32 = AudioFormat.float32()

        #expect(format16.bytesPerSample == 2)
        #expect(format24.bytesPerSample == 3)
        #expect(format32.bytesPerSample == 4)
    }

    @Test("AudioFormat: bytesPerFrame")
    func audioFormatBytesPerFrame() {
        let stereo16 = AudioFormat.pcm(channels: 2, bitsPerSample: 16)
        let mono16 = AudioFormat.pcm(sampleRate: 48000, channels: 1, bitsPerSample: 16)

        #expect(stereo16.bytesPerFrame == 4)
        #expect(mono16.bytesPerFrame == 2)
    }

    @Test("AudioFormat: pcmByteRate")
    func audioFormatPCMByteRate() {
        let format = AudioFormat.pcm(sampleRate: 48000, channels: 2, bitsPerSample: 16)
        #expect(format.pcmByteRate == 192000)
    }

    @Test("AudioFormat: pcmByteRate nil for compressed")
    func audioFormatPCMByteRateNilForCompressed() {
        let format = AudioFormat.aac()
        #expect(format.pcmByteRate == nil)
    }

    @Test("AudioFormat: duration for byte count")
    func audioFormatDuration() {
        let format = AudioFormat.pcm(sampleRate: 48000, channels: 2, bitsPerSample: 16)
        let duration = format.duration(forByteCount: 192000)
        #expect(duration == 1.0)
    }

    @Test("AudioFormat: byte count for duration")
    func audioFormatByteCount() {
        let format = AudioFormat.pcm(sampleRate: 48000, channels: 2, bitsPerSample: 16)
        let bytes = format.byteCount(forDuration: 1.0)
        #expect(bytes == 192000)
    }

    // MARK: - Conformances

    @Test("AudioFormat: Equatable")
    func audioFormatEquatable() {
        let format1 = AudioFormat.aac()
        let format2 = AudioFormat.aac()
        let format3 = AudioFormat.aac(bitrate: 256_000)
        #expect(format1 == format2)
        #expect(format1 != format3)
    }

    @Test("AudioFormat: Hashable")
    func audioFormatHashable() {
        var set = Set<AudioFormat>()
        set.insert(AudioFormat.aac())
        set.insert(AudioFormat.aac())
        set.insert(AudioFormat.pcm())
        #expect(set.count == 2)
    }

    @Test("AudioFormat: Sendable")
    func audioFormatSendable() async {
        let format = AudioFormat.aac()
        await Task {
            #expect(format.codec == .aac)
        }.value
    }
}
