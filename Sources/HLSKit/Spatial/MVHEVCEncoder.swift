// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(VideoToolbox)

    import Foundation

    /// Protocol for MV-HEVC stereoscopic video encoding.
    ///
    /// Implementors provide hardware-accelerated encoding of left/right
    /// eye views into a single MV-HEVC bitstream for Apple Vision Pro.
    ///
    /// This protocol is only available on platforms with VideoToolbox.
    public protocol MVHEVCEncoder: Sendable {

        /// Whether the encoder is available on the current hardware.
        var isAvailable: Bool { get }

        /// Encodes separate left and right eye buffers into MV-HEVC.
        ///
        /// - Parameters:
        ///   - leftEye: Left eye pixel buffer data.
        ///   - rightEye: Right eye pixel buffer data.
        /// - Returns: Encoded MV-HEVC NAL unit data.
        /// - Throws: ``MVHEVCEncoderError`` on failure.
        func encode(leftEye: Data, rightEye: Data) throws -> Data

        /// Encodes a pre-composed spatial sample into MV-HEVC.
        ///
        /// - Parameter spatialSample: Combined spatial video sample data.
        /// - Returns: Encoded MV-HEVC NAL unit data.
        /// - Throws: ``MVHEVCEncoderError`` on failure.
        func encode(spatialSample: Data) throws -> Data
    }

    /// Errors produced by MV-HEVC encoding operations.
    public enum MVHEVCEncoderError: Error, Sendable, Equatable {
        /// MV-HEVC encoding is not available on this hardware.
        case encodingNotAvailable
        /// Encoding failed with a description.
        case encodingFailed(String)
        /// The input data is invalid.
        case invalidInput(String)
    }

#endif
