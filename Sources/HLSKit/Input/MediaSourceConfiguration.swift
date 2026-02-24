// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration hints for media sources.
///
/// Provides optional parameters that sources can use to optimize their behavior.
public struct MediaSourceConfiguration: Sendable {

    /// Preferred buffer size in samples (for audio) or frames (for video).
    /// Sources may use this as a hint for chunking.
    public var preferredBufferSize: Int?

    /// Whether to loop the source (useful for testing with FileSource).
    public var loop: Bool

    /// Maximum duration to read (useful for trimming).
    public var maxDuration: TimeInterval?

    /// Start time offset (for seeking into a file).
    public var startTime: TimeInterval

    /// Creates a media source configuration.
    ///
    /// - Parameters:
    ///   - preferredBufferSize: Optional preferred buffer size.
    ///   - loop: Whether to loop the source. Default is false.
    ///   - maxDuration: Optional maximum duration to read.
    ///   - startTime: Start time offset. Default is 0.
    public init(
        preferredBufferSize: Int? = nil,
        loop: Bool = false,
        maxDuration: TimeInterval? = nil,
        startTime: TimeInterval = 0
    ) {
        self.preferredBufferSize = preferredBufferSize
        self.loop = loop
        self.maxDuration = maxDuration
        self.startTime = startTime
    }
}
