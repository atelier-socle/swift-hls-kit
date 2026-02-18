// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    @preconcurrency import AVFoundation
    import CoreMedia

    /// Abstracts reading sample buffers from a media track.
    ///
    /// Implemented by `AVAssetReaderTrackOutput` in production
    /// and mock types in tests.
    ///
    /// - SeeAlso: ``SampleWriting``, ``TranscodingSession``
    protocol SampleReading {
        /// Read the next sample buffer from the source.
        ///
        /// - Returns: Next sample buffer, or `nil` when exhausted.
        func copyNextSampleBuffer() -> CMSampleBuffer?
    }

    /// Abstracts writing sample buffers to an output track.
    ///
    /// Implemented by `AVAssetWriterInput` in production
    /// and mock types in tests.
    ///
    /// - SeeAlso: ``SampleReading``, ``TranscodingSession``
    protocol SampleWriting {
        /// Whether the writer can accept more data.
        var isReadyForMoreMediaData: Bool { get }

        /// Append a sample buffer to the output.
        ///
        /// - Parameter sampleBuffer: The sample to write.
        /// - Returns: `true` if the append succeeded.
        func append(_ sampleBuffer: CMSampleBuffer) -> Bool

        /// Signal that no more samples will be written.
        func markAsFinished()
    }

    // MARK: - AVFoundation Conformances

    extension AVAssetReaderTrackOutput: SampleReading {}
    extension AVAssetWriterInput: SampleWriting {}

#endif
