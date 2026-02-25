// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Protocol for recording storage operations.
///
/// Allows dependency injection for testing without actual file I/O.
/// In production, implement with `FileManager`-based storage.
/// In tests, use an in-memory mock conforming to this protocol.
///
/// ```swift
/// // Production usage:
/// let storage = FileRecordingStorage(basePath: "/recordings/stream-42")
/// let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
///
/// // Test usage:
/// let storage = MockRecordingStorage()
/// let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
/// ```
public protocol RecordingStorage: Sendable {

    /// Write segment data to storage.
    ///
    /// - Parameters:
    ///   - data: Segment binary data.
    ///   - filename: Target filename (e.g., "seg42.ts").
    ///   - directory: Target directory path.
    func writeSegment(
        data: Data,
        filename: String,
        directory: String
    ) async throws

    /// Write playlist text to storage.
    ///
    /// - Parameters:
    ///   - content: M3U8 playlist content.
    ///   - filename: Target filename (e.g., "playlist.m3u8").
    ///   - directory: Target directory path.
    func writePlaylist(
        content: String,
        filename: String,
        directory: String
    ) async throws

    /// Write chapter data to storage.
    ///
    /// - Parameters:
    ///   - content: Chapter JSON or VTT content.
    ///   - filename: Target filename.
    ///   - directory: Target directory path.
    func writeChapters(
        content: String,
        filename: String,
        directory: String
    ) async throws

    /// List files in a directory.
    ///
    /// - Parameter directory: The directory to list.
    /// - Returns: Filenames present in the directory.
    func listFiles(in directory: String) async throws -> [String]

    /// Check if a file exists.
    ///
    /// - Parameters:
    ///   - filename: The filename to check.
    ///   - directory: The directory containing the file.
    /// - Returns: Whether the file exists.
    func fileExists(filename: String, directory: String) async -> Bool

    /// Total bytes written across all operations.
    var totalBytesWritten: Int { get async }
}
