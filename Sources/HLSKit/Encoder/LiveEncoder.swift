// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Protocol for real-time media encoders.
///
/// A ``LiveEncoder`` transforms raw media buffers (``RawMediaBuffer``) into
/// compressed frames (``EncodedFrame``) suitable for HLS segmentation.
///
/// ## Lifecycle
/// 1. Create the encoder instance.
/// 2. Call ``configure(_:)`` with a ``LiveEncoderConfiguration``.
/// 3. Feed buffers via ``encode(_:)`` — returns zero or more frames per call.
/// 4. Call ``flush()`` to drain any buffered data (e.g., last partial AAC frame).
/// 5. Call ``teardown()`` to release resources.
///
/// ## Concurrency
/// Implementations ensure serialized access (via actors or dedicated
/// dispatch queues). All methods are async.
///
/// ## Usage
/// ```swift
/// let encoder: some LiveEncoder = AudioEncoder()
/// try await encoder.configure(.podcastAudio)
/// let frames = try await encoder.encode(pcmBuffer)
/// let remaining = try await encoder.flush()
/// await encoder.teardown()
/// ```
public protocol LiveEncoder: Sendable {

    /// Configures the encoder with the given settings.
    ///
    /// Must be called before ``encode(_:)``. Can be called again to reconfigure.
    ///
    /// - Parameter configuration: The encoder configuration.
    /// - Throws: ``LiveEncoderError/unsupportedConfiguration(_:)`` if the
    ///   configuration is not supported by this encoder.
    func configure(_ configuration: LiveEncoderConfiguration) async throws

    /// Encodes a raw media buffer.
    ///
    /// May return zero frames (if accumulating) or multiple frames
    /// (if enough data for several output frames).
    ///
    /// - Parameter buffer: The raw media buffer to encode.
    /// - Returns: Zero or more encoded frames.
    /// - Throws: ``LiveEncoderError/notConfigured`` if not configured,
    ///   ``LiveEncoderError/encodingFailed(_:)`` on encoding failure,
    ///   ``LiveEncoderError/formatMismatch(_:)`` if the buffer format
    ///   doesn't match configuration.
    func encode(_ buffer: RawMediaBuffer) async throws -> [EncodedFrame]

    /// Flushes any buffered data and returns remaining frames.
    ///
    /// Call this after the last ``encode(_:)`` to drain partial frames
    /// (e.g., the last AAC frame padded with silence).
    ///
    /// - Returns: Remaining encoded frames, possibly empty.
    /// - Throws: ``LiveEncoderError/notConfigured`` if not configured.
    func flush() async throws -> [EncodedFrame]

    /// Tears down the encoder and releases all resources.
    ///
    /// After calling this, the encoder cannot be used again.
    func teardown() async
}
