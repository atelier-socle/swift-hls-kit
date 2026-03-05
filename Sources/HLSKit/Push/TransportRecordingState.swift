// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Recording state reported by transports that support local recording.
///
/// Transport libraries that support local stream recording
/// (swift-rtmp-kit, swift-icecast-kit) report this state so that
/// ``LivePipeline`` can monitor recording progress.
public struct TransportRecordingState: Sendable, Equatable {

    /// Whether recording is currently active.
    public let isRecording: Bool

    /// Total bytes written to the recording file.
    public let bytesWritten: Int64

    /// Duration of the current recording.
    public let duration: TimeInterval

    /// Path to the current recording file, if any.
    public let currentFilePath: String?

    /// Creates a new recording state.
    ///
    /// - Parameters:
    ///   - isRecording: Whether recording is currently active.
    ///   - bytesWritten: Total bytes written.
    ///   - duration: Duration of the current recording.
    ///   - currentFilePath: Path to the recording file.
    public init(
        isRecording: Bool,
        bytesWritten: Int64,
        duration: TimeInterval,
        currentFilePath: String?
    ) {
        self.isRecording = isRecording
        self.bytesWritten = bytesWritten
        self.duration = duration
        self.currentFilePath = currentFilePath
    }
}
