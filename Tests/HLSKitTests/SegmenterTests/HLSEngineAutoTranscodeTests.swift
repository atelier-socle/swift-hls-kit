// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - ISOBMFF Detection

@Suite("HLSEngine ISOBMFF Detection")
struct ISOBMFFDetectionTests {

    @Test("mp4 is ISOBMFF")
    func mp4() {
        let url = URL(fileURLWithPath: "/tmp/test.mp4")
        #expect(HLSEngine.isISOBMFF(url))
    }

    @Test("m4a is ISOBMFF")
    func m4a() {
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        #expect(HLSEngine.isISOBMFF(url))
    }

    @Test("m4v is ISOBMFF")
    func m4v() {
        let url = URL(fileURLWithPath: "/tmp/test.m4v")
        #expect(HLSEngine.isISOBMFF(url))
    }

    @Test("mov is ISOBMFF")
    func mov() {
        let url = URL(fileURLWithPath: "/tmp/test.mov")
        #expect(HLSEngine.isISOBMFF(url))
    }

    @Test("mp3 is not ISOBMFF")
    func mp3() {
        let url = URL(fileURLWithPath: "/tmp/test.mp3")
        #expect(!HLSEngine.isISOBMFF(url))
    }

    @Test("wav is not ISOBMFF")
    func wav() {
        let url = URL(fileURLWithPath: "/tmp/test.wav")
        #expect(!HLSEngine.isISOBMFF(url))
    }

    @Test("flac is not ISOBMFF")
    func flac() {
        let url = URL(fileURLWithPath: "/tmp/test.flac")
        #expect(!HLSEngine.isISOBMFF(url))
    }

    @Test("aac is not ISOBMFF")
    func aac() {
        let url = URL(fileURLWithPath: "/tmp/test.aac")
        #expect(!HLSEngine.isISOBMFF(url))
    }

    @Test("ogg is not ISOBMFF")
    func ogg() {
        let url = URL(fileURLWithPath: "/tmp/test.ogg")
        #expect(!HLSEngine.isISOBMFF(url))
    }

    @Test("aiff is not ISOBMFF")
    func aiff() {
        let url = URL(fileURLWithPath: "/tmp/test.aiff")
        #expect(!HLSEngine.isISOBMFF(url))
    }

    @Test("case insensitive — MP4 uppercase")
    func caseInsensitive() {
        let url = URL(fileURLWithPath: "/tmp/test.MP4")
        #expect(HLSEngine.isISOBMFF(url))
    }

    @Test("case insensitive — M4A mixed case")
    func caseInsensitiveMixed() {
        let url = URL(fileURLWithPath: "/tmp/test.M4a")
        #expect(HLSEngine.isISOBMFF(url))
    }
}

// MARK: - ISOBMFF Segmentation Path

@Suite("HLSEngine URL Segmentation — ISOBMFF Direct Path")
struct ISOBMFFSegmentationTests {

    #if canImport(AVFoundation) && !os(watchOS)

        @Test("ISOBMFF file segments directly via URL")
        func isobmffDirect() async throws {
            let data = MP4TestDataBuilder.segmentableMP4WithData()
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "hls_test_\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir, withIntermediateDirectories: true
            )
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            let mp4File = tempDir.appendingPathComponent("test.mp4")
            try data.write(to: mp4File)

            let engine = HLSEngine()
            let result = try await engine.segmentToDirectory(
                url: mp4File,
                outputDirectory: tempDir
            )
            #expect(!result.initSegment.isEmpty)
            #expect(result.segmentCount > 0)
            #expect(result.playlist != nil)
        }

        @Test("ISOBMFF m4a segments directly via URL")
        func m4aDirect() async throws {
            let data = MP4TestDataBuilder.segmentableMP4WithData()
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "hls_test_\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir, withIntermediateDirectories: true
            )
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            let m4aFile = tempDir.appendingPathComponent("test.m4a")
            try data.write(to: m4aFile)

            let engine = HLSEngine()
            let result = try await engine.segmentToDirectory(
                url: m4aFile,
                outputDirectory: tempDir
            )
            #expect(!result.initSegment.isEmpty)
            #expect(result.segmentCount > 0)
        }

    #endif
}

// MARK: - Auto-Transcode Path

#if canImport(AVFoundation) && !os(watchOS)

    @Suite("HLSEngine URL Segmentation — Auto-Transcode Path")
    struct AutoTranscodeSegmentationTests {

        @Test(
            "non-ISOBMFF WAV auto-transcodes then segments",
            .timeLimit(.minutes(1))
        )
        func wavAutoTranscode() async throws {
            if ProcessInfo.processInfo.environment["CI"] != nil {
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "hls_test_\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir, withIntermediateDirectories: true
            )
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            let wavFile = tempDir.appendingPathComponent("test.wav")
            try WAVFixtureBuilder.createWAV(
                at: wavFile, duration: 2.0
            )

            let engine = HLSEngine()
            let result = try await engine.segmentToDirectory(
                url: wavFile,
                outputDirectory: tempDir
            )
            #expect(result.segmentCount > 0)
            #expect(result.playlist != nil)

            // Verify temp file cleaned up
            let tempM4A =
                tempDir
                .appendingPathComponent("_temp_transcode.m4a")
            #expect(
                !FileManager.default.fileExists(
                    atPath: tempM4A.path
                )
            )
        }

        @Test(
            "non-ISOBMFF AIFF auto-transcodes then segments",
            .timeLimit(.minutes(1))
        )
        func aiffAutoTranscode() async throws {
            if ProcessInfo.processInfo.environment["CI"] != nil {
                return
            }

            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "hls_test_\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir, withIntermediateDirectories: true
            )
            defer {
                try? FileManager.default.removeItem(at: tempDir)
            }

            let aiffFile =
                tempDir
                .appendingPathComponent("test.aiff")
            try WAVFixtureBuilder.createAIFF(
                at: aiffFile, duration: 2.0
            )

            let engine = HLSEngine()
            let result = try await engine.segmentToDirectory(
                url: aiffFile,
                outputDirectory: tempDir
            )
            #expect(result.segmentCount > 0)
            #expect(result.playlist != nil)
        }
    }

    // MARK: - Audio Fixture Builders

    /// Creates minimal audio fixtures for auto-transcode testing.
    enum WAVFixtureBuilder {

        /// Create a PCM WAV file with a 440 Hz sine wave.
        ///
        /// - Parameters:
        ///   - url: Output file URL.
        ///   - duration: Duration in seconds.
        static func createWAV(
            at url: URL, duration: Double
        ) throws {
            let sampleRate: UInt32 = 44100
            let channels: UInt16 = 1
            let bitsPerSample: UInt16 = 16
            let totalSamples = Int(
                Double(sampleRate) * duration
            )
            let bytesPerSample =
                Int(channels)
                * Int(bitsPerSample / 8)
            let dataSize = UInt32(totalSamples * bytesPerSample)

            var data = Data(capacity: 44 + Int(dataSize))

            // RIFF header
            data.append(contentsOf: [0x52, 0x49, 0x46, 0x46])
            appendLittleEndian(&data, value: 36 + dataSize)
            data.append(contentsOf: [0x57, 0x41, 0x56, 0x45])

            // fmt chunk
            data.append(contentsOf: [0x66, 0x6D, 0x74, 0x20])
            appendLittleEndian(&data, value: UInt32(16))
            appendLittleEndian(&data, value: UInt16(1))
            appendLittleEndian(&data, value: channels)
            appendLittleEndian(&data, value: sampleRate)
            let byteRate =
                sampleRate * UInt32(channels)
                * UInt32(bitsPerSample / 8)
            appendLittleEndian(&data, value: byteRate)
            let blockAlign = channels * (bitsPerSample / 8)
            appendLittleEndian(&data, value: blockAlign)
            appendLittleEndian(&data, value: bitsPerSample)

            // data chunk
            data.append(contentsOf: [0x64, 0x61, 0x74, 0x61])
            appendLittleEndian(&data, value: dataSize)

            for i in 0..<totalSamples {
                let phase =
                    2.0 * Double.pi * 440.0
                    * Double(i) / Double(sampleRate)
                let sample = Int16(sin(phase) * 16000)
                appendLittleEndian(&data, value: sample)
            }

            try data.write(to: url)
        }

        /// Create a PCM AIFF file with a 440 Hz sine wave.
        ///
        /// - Parameters:
        ///   - url: Output file URL.
        ///   - duration: Duration in seconds.
        static func createAIFF(
            at url: URL, duration: Double
        ) throws {
            let sampleRate: Double = 44100
            let channels: Int16 = 1
            let bitsPerSample: Int16 = 16
            let totalSamples = Int(sampleRate * duration)
            let dataSize =
                totalSamples * Int(channels)
                * Int(bitsPerSample / 8)

            var data = Data(capacity: 54 + dataSize)

            // FORM header
            data.append(contentsOf: [0x46, 0x4F, 0x52, 0x4D])
            appendBigEndian(
                &data, value: UInt32(46 + dataSize)
            )
            data.append(contentsOf: [0x41, 0x49, 0x46, 0x46])

            // COMM chunk
            data.append(contentsOf: [0x43, 0x4F, 0x4D, 0x4D])
            appendBigEndian(&data, value: UInt32(18))
            appendBigEndian(&data, value: channels)
            appendBigEndian(
                &data, value: UInt32(totalSamples)
            )
            appendBigEndian(&data, value: bitsPerSample)
            appendExtended(&data, value: sampleRate)

            // SSND chunk
            data.append(contentsOf: [0x53, 0x53, 0x4E, 0x44])
            appendBigEndian(
                &data, value: UInt32(8 + dataSize)
            )
            appendBigEndian(&data, value: UInt32(0))
            appendBigEndian(&data, value: UInt32(0))

            for i in 0..<totalSamples {
                let phase =
                    2.0 * Double.pi * 440.0
                    * Double(i) / sampleRate
                let sample = Int16(sin(phase) * 16000)
                appendBigEndian(&data, value: sample)
            }

            try data.write(to: url)
        }

        // MARK: - Binary Helpers

        private static func appendLittleEndian<T: FixedWidthInteger>(
            _ data: inout Data, value: T
        ) {
            withUnsafeBytes(of: value.littleEndian) {
                data.append(contentsOf: $0)
            }
        }

        private static func appendBigEndian<T: FixedWidthInteger>(
            _ data: inout Data, value: T
        ) {
            withUnsafeBytes(of: value.bigEndian) {
                data.append(contentsOf: $0)
            }
        }

        /// Encode a Double as 80-bit IEEE 754 extended.
        private static func appendExtended(
            _ data: inout Data, value: Double
        ) {
            var bytes = [UInt8](repeating: 0, count: 10)
            var val = value
            var exponent: Int16 = 16383 + 63
            if val > 0 {
                while val < Double(Int64(1) << 63) {
                    val *= 2
                    exponent -= 1
                }
                exponent += 1
            }
            let mantissa = UInt64(val)
            bytes[0] = UInt8((exponent >> 8) & 0xFF)
            bytes[1] = UInt8(exponent & 0xFF)
            for i in 0..<8 {
                bytes[2 + i] = UInt8(
                    (mantissa >> (56 - i * 8)) & 0xFF
                )
            }
            data.append(contentsOf: bytes)
        }
    }

#endif
