// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import AVFoundation
    import Foundation

    /// Creates synthetic audio files for transcoding integration tests.
    ///
    /// Generates short sine wave audio files using AVAudioEngine,
    /// providing real AVAsset-compatible media without bundling
    /// test fixtures.
    enum SyntheticAudioHelper {

        /// Create a short WAV audio file with a sine wave tone.
        ///
        /// - Parameters:
        ///   - url: File URL where the WAV file will be written.
        ///   - duration: Duration in seconds (default 1.0).
        ///   - sampleRate: Sample rate in Hz (default 44100).
        ///   - frequency: Sine wave frequency in Hz (default 440).
        /// - Throws: If the file cannot be created or written.
        static func createAudioFile(
            at url: URL,
            duration: Double = 1.0,
            sampleRate: Double = 44100,
            frequency: Double = 440.0
        ) throws {
            let frameCount = AVAudioFrameCount(
                sampleRate * duration
            )
            guard
                let format = AVAudioFormat(
                    standardFormatWithSampleRate: sampleRate,
                    channels: 1
                )
            else {
                throw SyntheticAudioError.formatCreationFailed
            }
            guard
                let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    frameCapacity: frameCount
                )
            else {
                throw SyntheticAudioError.bufferCreationFailed
            }

            buffer.frameLength = frameCount

            guard let channelData = buffer.floatChannelData
            else {
                throw SyntheticAudioError.bufferCreationFailed
            }
            let samples = channelData[0]

            for frame in 0..<Int(frameCount) {
                let phase =
                    2.0 * Double.pi * frequency
                    * Double(frame) / sampleRate
                samples[frame] = Float(sin(phase)) * 0.5
            }

            let audioFile = try AVAudioFile(
                forWriting: url,
                settings: format.settings
            )
            try audioFile.write(from: buffer)
        }

        /// Errors from synthetic audio file creation.
        enum SyntheticAudioError: Error {
            case formatCreationFailed
            case bufferCreationFailed
        }
    }

#endif
