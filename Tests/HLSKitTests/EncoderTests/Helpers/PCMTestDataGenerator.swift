// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Generates synthetic PCM audio data for encoder tests.
///
/// Produces sine wave data in Int16 or Float32 format, suitable for
/// feeding into ``AudioEncoder`` or ``FFmpegAudioEncoder`` test cases.
struct PCMTestDataGenerator {

    /// Sample rate in Hz.
    let sampleRate: Double

    /// Number of channels.
    let channels: Int

    /// Frequency of the generated sine wave in Hz.
    let frequency: Double

    /// Amplitude (0.0 to 1.0).
    let amplitude: Double

    /// Creates a PCM test data generator.
    ///
    /// - Parameters:
    ///   - sampleRate: Sample rate in Hz. Default is 44100.
    ///   - channels: Number of channels. Default is 1 (mono).
    ///   - frequency: Sine wave frequency in Hz. Default is 440 (A4).
    ///   - amplitude: Amplitude from 0.0 to 1.0. Default is 0.8.
    init(
        sampleRate: Double = 44_100,
        channels: Int = 1,
        frequency: Double = 440.0,
        amplitude: Double = 0.8
    ) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.frequency = frequency
        self.amplitude = amplitude
    }

    // MARK: - Int16 Generation

    /// Generates signed 16-bit integer PCM data.
    ///
    /// - Parameter sampleCount: Number of samples per channel.
    /// - Returns: Interleaved Int16 PCM data.
    func generateInt16(sampleCount: Int) -> Data {
        var data = Data(capacity: sampleCount * channels * 2)

        for sampleIndex in 0..<sampleCount {
            let time = Double(sampleIndex) / sampleRate
            let value = amplitude * sin(2.0 * .pi * frequency * time)
            let int16Value = Int16(
                clamping: Int(value * Double(Int16.max))
            )

            // Write same value to all channels (interleaved)
            for _ in 0..<channels {
                withUnsafeBytes(of: int16Value.littleEndian) { bytes in
                    data.append(contentsOf: bytes)
                }
            }
        }

        return data
    }

    /// Generates signed 16-bit integer PCM data for a given duration.
    ///
    /// - Parameter duration: Duration in seconds.
    /// - Returns: Interleaved Int16 PCM data.
    func generateInt16(duration: Double) -> Data {
        let sampleCount = Int(sampleRate * duration)
        return generateInt16(sampleCount: sampleCount)
    }

    // MARK: - Float32 Generation

    /// Generates 32-bit float PCM data.
    ///
    /// - Parameter sampleCount: Number of samples per channel.
    /// - Returns: Interleaved Float32 PCM data.
    func generateFloat32(sampleCount: Int) -> Data {
        var data = Data(capacity: sampleCount * channels * 4)

        for sampleIndex in 0..<sampleCount {
            let time = Double(sampleIndex) / sampleRate
            let value = Float(
                amplitude * sin(2.0 * .pi * frequency * time)
            )

            for _ in 0..<channels {
                withUnsafeBytes(of: value.bitPattern.littleEndian) { bytes in
                    data.append(contentsOf: bytes)
                }
            }
        }

        return data
    }

    /// Generates 32-bit float PCM data for a given duration.
    ///
    /// - Parameter duration: Duration in seconds.
    /// - Returns: Interleaved Float32 PCM data.
    func generateFloat32(duration: Double) -> Data {
        let sampleCount = Int(sampleRate * duration)
        return generateFloat32(sampleCount: sampleCount)
    }

    // MARK: - Buffer Convenience

    /// Creates a ``RawMediaBuffer`` with Int16 PCM data.
    ///
    /// - Parameters:
    ///   - sampleCount: Number of samples per channel.
    ///   - timestamp: Presentation timestamp. Default is zero.
    /// - Returns: A raw media buffer containing the generated PCM data.
    func makeBuffer(
        sampleCount: Int,
        timestamp: MediaTimestamp = .zero
    ) -> RawMediaBuffer {
        let data = generateInt16(sampleCount: sampleCount)
        let duration = Double(sampleCount) / sampleRate

        return RawMediaBuffer(
            data: data,
            timestamp: timestamp,
            duration: MediaTimestamp(seconds: duration),
            isKeyframe: true,
            mediaType: .audio,
            formatInfo: .audio(
                sampleRate: sampleRate,
                channels: channels,
                bitsPerSample: 16
            )
        )
    }

    /// Creates a ``RawMediaBuffer`` with Int16 PCM data for a duration.
    ///
    /// - Parameters:
    ///   - duration: Duration in seconds.
    ///   - timestamp: Presentation timestamp. Default is zero.
    /// - Returns: A raw media buffer containing the generated PCM data.
    func makeBuffer(
        duration: Double,
        timestamp: MediaTimestamp = .zero
    ) -> RawMediaBuffer {
        let sampleCount = Int(sampleRate * duration)
        return makeBuffer(
            sampleCount: sampleCount, timestamp: timestamp
        )
    }

    /// Creates a ``RawMediaBuffer`` with Float32 PCM data.
    ///
    /// - Parameters:
    ///   - sampleCount: Number of samples per channel.
    ///   - timestamp: Presentation timestamp. Default is zero.
    /// - Returns: A raw media buffer containing Float32 PCM data.
    func makeFloat32Buffer(
        sampleCount: Int,
        timestamp: MediaTimestamp = .zero
    ) -> RawMediaBuffer {
        let data = generateFloat32(sampleCount: sampleCount)
        let duration = Double(sampleCount) / sampleRate

        return RawMediaBuffer(
            data: data,
            timestamp: timestamp,
            duration: MediaTimestamp(seconds: duration),
            isKeyframe: true,
            mediaType: .audio,
            formatInfo: .audio(
                sampleRate: sampleRate,
                channels: channels,
                bitsPerSample: 32,
                isFloat: true
            )
        )
    }
}
