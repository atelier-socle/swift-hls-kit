// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Encodes a media stream at multiple quality levels simultaneously.
///
/// Manages N ``LiveEncoder`` instances, one per ``QualityPreset``.
/// Each encoder receives the same input buffers and produces
/// independent compressed frame streams.
///
/// ## Usage
/// ```swift
/// let multi = MultiBitrateEncoder { VideoEncoder() }
/// try await multi.configure(presets: [.p360, .p720, .p1080])
/// for await buffer in videoSource {
///     let framesByPreset = try await multi.encode(buffer)
///     for (preset, frames) in framesByPreset {
///         // Feed frames to per-preset segmenter...
///     }
/// }
/// let remaining = try await multi.flushAll()
/// await multi.teardownAll()
/// ```
///
/// ## Generic Encoder
/// The encoder type is generic, allowing platform-specific selection:
/// ```swift
/// // Apple platforms
/// let multi = MultiBitrateEncoder { VideoEncoder() }
/// // Linux
/// let multi = MultiBitrateEncoder { FFmpegVideoEncoder() }
/// ```
public actor MultiBitrateEncoder<Encoder: LiveEncoder> {

    // MARK: - State

    private var encoders: [QualityPreset: Encoder] = [:]
    private let makeEncoder: @Sendable () -> Encoder
    private var isConfigured = false
    private var isTornDown = false

    /// Creates a multi-bitrate encoder with the given factory.
    ///
    /// - Parameter makeEncoder: A closure that creates a new
    ///   encoder instance. Called once per quality preset.
    public init(
        makeEncoder: @Sendable @escaping () -> Encoder
    ) {
        self.makeEncoder = makeEncoder
    }

    // MARK: - Configuration

    /// Configure encoders for the given quality presets.
    ///
    /// Creates one ``LiveEncoder`` per preset, configured with
    /// appropriate bitrate, resolution, and codec settings
    /// derived from the preset.
    ///
    /// - Parameters:
    ///   - presets: Quality presets to encode.
    ///   - baseConfig: Base encoder configuration. Video settings
    ///     are overridden per-preset; audio settings are shared.
    /// - Throws: ``LiveEncoderError`` if any encoder fails.
    public func configure(
        presets: [QualityPreset],
        baseConfig: LiveEncoderConfiguration = LiveEncoderConfiguration(
            videoCodec: .h264,
            keyframeInterval: 6.0
        )
    ) async throws {
        guard !presets.isEmpty else {
            throw LiveEncoderError.unsupportedConfiguration(
                "At least one preset required"
            )
        }

        // Tear down any existing encoders
        await teardownAll()
        isTornDown = false

        for preset in presets {
            let encoder = makeEncoder()
            let config = baseConfig.withVideoOverrides(
                videoBitrate: preset.videoBitrate,
                qualityPreset: preset
            )
            try await encoder.configure(config)
            encoders[preset] = encoder
        }
        isConfigured = true
    }

    // MARK: - Encoding

    /// Encode a buffer at all configured quality levels.
    ///
    /// Feeds the same buffer to all encoders concurrently
    /// using a task group.
    ///
    /// - Parameter buffer: Raw media buffer from a source.
    /// - Returns: Dictionary mapping each preset to its frames.
    public func encode(
        _ buffer: RawMediaBuffer
    ) async throws -> [QualityPreset: [EncodedFrame]] {
        guard !isTornDown else {
            throw LiveEncoderError.tornDown
        }
        guard isConfigured else {
            throw LiveEncoderError.notConfigured
        }

        var results: [QualityPreset: [EncodedFrame]] = [:]

        try await withThrowingTaskGroup(
            of: (QualityPreset, [EncodedFrame]).self
        ) { group in
            for (preset, encoder) in encoders {
                group.addTask {
                    let frames = try await encoder.encode(
                        buffer
                    )
                    return (preset, frames)
                }
            }
            for try await (preset, frames) in group {
                results[preset] = frames
            }
        }

        return results
    }

    // MARK: - Flush & Teardown

    /// Flush all encoders and collect remaining frames.
    ///
    /// - Returns: Dictionary mapping each preset to remaining frames.
    public func flushAll() async throws -> [QualityPreset: [EncodedFrame]] {
        guard isConfigured else { return [:] }
        guard !isTornDown else { return [:] }

        var results: [QualityPreset: [EncodedFrame]] = [:]
        for (preset, encoder) in encoders {
            let frames = try await encoder.flush()
            results[preset] = frames
        }
        return results
    }

    /// Tear down all encoders and release resources.
    public func teardownAll() async {
        for (_, encoder) in encoders {
            await encoder.teardown()
        }
        encoders.removeAll()
        isTornDown = true
        isConfigured = false
    }
}
