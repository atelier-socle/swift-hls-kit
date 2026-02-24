// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Comprehensive audio format descriptor for HLSKit.
///
/// Describes both raw (PCM) and compressed (AAC, AC-3, etc.) audio formats.
/// Used by ``MediaSource``, ``LiveEncoder``, and audio processing helpers.
public struct AudioFormat: Sendable, Equatable, Hashable {

    /// Audio codec or PCM format.
    public let codec: AudioCodec

    /// Sample rate in Hz (e.g., 44100, 48000, 96000).
    public let sampleRate: Double

    /// Number of audio channels.
    public let channels: Int

    /// Bits per sample for PCM (16, 24, 32). Nil for compressed formats.
    public let bitsPerSample: Int?

    /// Whether samples are floating-point (Float32). Only applicable to PCM.
    public let isFloat: Bool

    /// Whether samples are interleaved (LRLRLR) vs. planar (LLLLRRRR).
    public let isInterleaved: Bool

    /// Bitrate in bits per second for compressed formats. Nil for PCM.
    public let bitrate: Int?

    /// AAC profile, if codec is AAC.
    public let aacProfile: AACProfile?

    /// Creates an audio format descriptor.
    ///
    /// - Parameters:
    ///   - codec: The audio codec or PCM format.
    ///   - sampleRate: Sample rate in Hz.
    ///   - channels: Number of audio channels.
    ///   - bitsPerSample: Bits per sample for PCM. Nil for compressed.
    ///   - isFloat: Whether samples are floating-point.
    ///   - isInterleaved: Whether samples are interleaved.
    ///   - bitrate: Bitrate for compressed formats.
    ///   - aacProfile: AAC profile if codec is AAC.
    public init(
        codec: AudioCodec,
        sampleRate: Double,
        channels: Int,
        bitsPerSample: Int? = nil,
        isFloat: Bool = false,
        isInterleaved: Bool = true,
        bitrate: Int? = nil,
        aacProfile: AACProfile? = nil
    ) {
        self.codec = codec
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitsPerSample = bitsPerSample
        self.isFloat = isFloat
        self.isInterleaved = isInterleaved
        self.bitrate = bitrate
        self.aacProfile = aacProfile
    }

    // MARK: - Convenience Constructors

    /// Standard PCM format.
    ///
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz. Default is 48000.
    ///   - channels: Number of channels. Default is 2 (stereo).
    ///   - bitsPerSample: Bits per sample. Default is 16.
    ///   - isFloat: Whether samples are floating-point. Default is false.
    ///   - isInterleaved: Whether samples are interleaved. Default is true.
    /// - Returns: A PCM audio format.
    public static func pcm(
        sampleRate: Double = 48000,
        channels: Int = 2,
        bitsPerSample: Int = 16,
        isFloat: Bool = false,
        isInterleaved: Bool = true
    ) -> AudioFormat {
        let codec: AudioCodec = isFloat ? .pcmFloat32 : (bitsPerSample == 24 ? .pcmInt24 : .pcmInt16)
        return AudioFormat(
            codec: codec,
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: bitsPerSample,
            isFloat: isFloat,
            isInterleaved: isInterleaved
        )
    }

    /// Standard AAC-LC format.
    ///
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz. Default is 48000.
    ///   - channels: Number of channels. Default is 2 (stereo).
    ///   - bitrate: Bitrate in bits per second. Default is 128000.
    ///   - profile: AAC profile. Default is LC.
    /// - Returns: An AAC audio format.
    public static func aac(
        sampleRate: Double = 48000,
        channels: Int = 2,
        bitrate: Int = 128_000,
        profile: AACProfile = .lc
    ) -> AudioFormat {
        AudioFormat(
            codec: .aac,
            sampleRate: sampleRate,
            channels: channels,
            bitrate: bitrate,
            aacProfile: profile
        )
    }

    /// Standard Float32 format (for AudioToolbox / DSP pipelines).
    ///
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz. Default is 48000.
    ///   - channels: Number of channels. Default is 2 (stereo).
    ///   - isInterleaved: Whether samples are interleaved. Default is true.
    /// - Returns: A Float32 PCM audio format.
    public static func float32(
        sampleRate: Double = 48000,
        channels: Int = 2,
        isInterleaved: Bool = true
    ) -> AudioFormat {
        AudioFormat(
            codec: .pcmFloat32,
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: 32,
            isFloat: true,
            isInterleaved: isInterleaved
        )
    }

    /// Hi-Res audio format.
    ///
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz. Default is 96000.
    ///   - bitsPerSample: Bits per sample. Default is 24.
    ///   - channels: Number of channels. Default is 2 (stereo).
    /// - Returns: A hi-res PCM audio format.
    public static func hiRes(
        sampleRate: Double = 96000,
        bitsPerSample: Int = 24,
        channels: Int = 2
    ) -> AudioFormat {
        AudioFormat(
            codec: bitsPerSample == 24 ? .pcmInt24 : .pcmInt32,
            sampleRate: sampleRate,
            channels: channels,
            bitsPerSample: bitsPerSample,
            isFloat: false,
            isInterleaved: true
        )
    }

    // MARK: - Computed Properties

    /// Bytes per sample per channel.
    public var bytesPerSample: Int {
        guard let bits = bitsPerSample else { return 0 }
        return bits / 8
    }

    /// Bytes per frame (all channels combined).
    public var bytesPerFrame: Int {
        bytesPerSample * channels
    }

    /// Byte rate for PCM (sampleRate × bytesPerFrame).
    public var pcmByteRate: Double? {
        guard codec.isPCM else { return nil }
        return sampleRate * Double(bytesPerFrame)
    }

    /// Duration in seconds for a given byte count (PCM only).
    ///
    /// - Parameter byteCount: The number of bytes.
    /// - Returns: Duration in seconds, or nil for non-PCM formats.
    public func duration(forByteCount byteCount: Int) -> Double? {
        guard let rate = pcmByteRate, rate > 0 else { return nil }
        return Double(byteCount) / rate
    }

    /// Byte count for a given duration (PCM only).
    ///
    /// - Parameter duration: Duration in seconds.
    /// - Returns: Byte count, or nil for non-PCM formats.
    public func byteCount(forDuration duration: Double) -> Int? {
        guard let rate = pcmByteRate else { return nil }
        return Int(duration * rate)
    }
}

// MARK: - AudioCodec

/// Supported audio codecs.
public enum AudioCodec: String, Sendable, Codable, CaseIterable {

    /// Linear PCM, signed 16-bit integer.
    case pcmInt16

    /// Linear PCM, signed 24-bit integer.
    case pcmInt24

    /// Linear PCM, signed 32-bit integer.
    case pcmInt32

    /// Linear PCM, 32-bit float.
    case pcmFloat32

    /// Linear PCM, 64-bit float.
    case pcmFloat64

    /// AAC (all profiles via AACProfile).
    case aac

    /// Opus.
    case opus

    /// MPEG Audio Layer III.
    case mp3

    /// AC-3 (Dolby Digital).
    case ac3

    /// E-AC-3 (Dolby Digital Plus).
    case eac3

    /// Apple Lossless.
    case alac

    /// Free Lossless Audio Codec.
    case flac

    /// Whether this is a PCM (uncompressed) format.
    public var isPCM: Bool {
        switch self {
        case .pcmInt16, .pcmInt24, .pcmInt32, .pcmFloat32, .pcmFloat64:
            true
        default:
            false
        }
    }

    /// Whether this is a lossless format.
    public var isLossless: Bool {
        switch self {
        case .pcmInt16, .pcmInt24, .pcmInt32, .pcmFloat32, .pcmFloat64, .alac, .flac:
            true
        default:
            false
        }
    }

    /// HLS codec string for manifest CODECS attribute.
    public var hlsCodecString: String? {
        switch self {
        case .aac: "mp4a.40.2"  // AAC-LC default; refined by AACProfile
        case .ac3: "ac-3"
        case .eac3: "ec-3"
        case .flac: "fLaC"
        case .opus: "Opus"
        case .alac: "alac"
        default: nil
        }
    }
}

// MARK: - AACProfile

/// AAC profile variants.
public enum AACProfile: String, Sendable, Codable, CaseIterable {

    /// AAC-LC (Low Complexity) — most common.
    case lc

    /// HE-AAC v1 (SBR).
    case he

    /// HE-AAC v2 (SBR + PS).
    case heV2

    /// AAC-LD (Low Delay).
    case ld

    /// AAC-ELD (Enhanced Low Delay).
    case eld

    /// HLS CODECS attribute string.
    public var hlsCodecString: String {
        switch self {
        case .lc: "mp4a.40.2"
        case .he: "mp4a.40.5"
        case .heV2: "mp4a.40.29"
        case .ld: "mp4a.40.23"
        case .eld: "mp4a.40.39"
        }
    }
}
