// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Describes the format of media data from a ``MediaSource``.
///
/// Cross-platform equivalent of CMFormatDescription.
public struct MediaFormatDescription: Sendable {

    /// Audio format, if this source provides audio.
    public let audioFormat: AudioFormat?

    /// Video format, if this source provides video.
    public let videoFormat: VideoFormatInfo?

    /// Creates a media format description.
    ///
    /// - Parameters:
    ///   - audioFormat: Optional audio format.
    ///   - videoFormat: Optional video format.
    /// - Precondition: At least one format must be non-nil.
    public init(audioFormat: AudioFormat? = nil, videoFormat: VideoFormatInfo? = nil) {
        precondition(
            audioFormat != nil || videoFormat != nil,
            "MediaFormatDescription requires at least one format"
        )
        self.audioFormat = audioFormat
        self.videoFormat = videoFormat
    }
}

// MARK: - VideoFormatInfo

/// Video format descriptor — cross-platform.
public struct VideoFormatInfo: Sendable, Equatable {

    /// Video codec.
    public let codec: VideoCodec

    /// Frame width in pixels.
    public let width: Int

    /// Frame height in pixels.
    public let height: Int

    /// Frame rate (frames per second).
    public let frameRate: Double

    /// Bit depth (8, 10, 12).
    public let bitDepth: Int

    /// Color space information.
    public let colorSpace: VideoColorSpace?

    /// Creates a video format info.
    ///
    /// - Parameters:
    ///   - codec: The video codec.
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - frameRate: Frame rate in frames per second.
    ///   - bitDepth: Bit depth. Default is 8.
    ///   - colorSpace: Optional color space information.
    public init(
        codec: VideoCodec,
        width: Int,
        height: Int,
        frameRate: Double,
        bitDepth: Int = 8,
        colorSpace: VideoColorSpace? = nil
    ) {
        self.codec = codec
        self.width = width
        self.height = height
        self.frameRate = frameRate
        self.bitDepth = bitDepth
        self.colorSpace = colorSpace
    }

    /// The video resolution.
    public var resolution: Resolution {
        Resolution(width: width, height: height)
    }
}

// MARK: - VideoCodec

/// Supported video codecs for media input.
public enum VideoCodec: String, Sendable, Codable, CaseIterable, Hashable {

    /// H.264 / AVC.
    case h264

    /// H.265 / HEVC.
    case h265

    /// AV1.
    case av1

    /// VP9 (WebM).
    case vp9
}

// MARK: - VideoColorSpace

/// Video color space descriptor — for HDR support.
public struct VideoColorSpace: Sendable, Equatable {

    /// Color primaries.
    public let primaries: ColorPrimaries

    /// Transfer characteristics (gamma curve).
    public let transfer: TransferCharacteristics

    /// Matrix coefficients for YCbCr conversion.
    public let matrix: MatrixCoefficients

    /// Creates a video color space.
    ///
    /// - Parameters:
    ///   - primaries: Color primaries.
    ///   - transfer: Transfer characteristics.
    ///   - matrix: Matrix coefficients.
    public init(
        primaries: ColorPrimaries,
        transfer: TransferCharacteristics,
        matrix: MatrixCoefficients
    ) {
        self.primaries = primaries
        self.transfer = transfer
        self.matrix = matrix
    }

    /// Color primaries standard.
    public enum ColorPrimaries: String, Sendable, Codable {

        /// BT.709 (SDR).
        case bt709

        /// BT.2020 (HDR wide gamut).
        case bt2020

        /// Display P3.
        case displayP3
    }

    /// Transfer characteristics (OETF/EOTF).
    public enum TransferCharacteristics: String, Sendable, Codable {

        /// BT.709 (SDR gamma).
        case bt709

        /// SMPTE ST 2084 (Perceptual Quantizer for HDR10, Dolby Vision).
        case pq

        /// Hybrid Log-Gamma.
        case hlg

        /// Linear (no gamma).
        case linear
    }

    /// Matrix coefficients for YCbCr conversion.
    public enum MatrixCoefficients: String, Sendable, Codable {

        /// BT.709.
        case bt709

        /// BT.2020 non-constant luminance.
        case bt2020NonConstant

        /// BT.2020 constant luminance.
        case bt2020Constant
    }

    // MARK: - Convenience Presets

    /// SDR color space (BT.709).
    public static let sdr = VideoColorSpace(
        primaries: .bt709,
        transfer: .bt709,
        matrix: .bt709
    )

    /// HDR10 color space (BT.2020 + PQ).
    public static let hdr10 = VideoColorSpace(
        primaries: .bt2020,
        transfer: .pq,
        matrix: .bt2020NonConstant
    )

    /// HLG color space (BT.2020 + HLG).
    public static let hlg = VideoColorSpace(
        primaries: .bt2020,
        transfer: .hlg,
        matrix: .bt2020NonConstant
    )
}
