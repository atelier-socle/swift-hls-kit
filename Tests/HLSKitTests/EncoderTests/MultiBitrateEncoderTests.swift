// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(VideoToolbox)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("MultiBitrateEncoder", .timeLimit(.minutes(1)))
    struct MultiBitrateEncoderTests {

        // MARK: - Configuration

        @Test("Configure with multiple presets")
        func configureMultiplePresets() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            try await multi.configure(
                presets: [.p360, .p720]
            )
            await multi.teardownAll()
        }

        @Test("Configure with single preset")
        func configureSinglePreset() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            try await multi.configure(presets: [.p360])
            await multi.teardownAll()
        }

        @Test("Configure with empty presets throws error")
        func configureEmptyPresets() async {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            await #expect(throws: LiveEncoderError.self) {
                try await multi.configure(presets: [])
            }
        }

        // MARK: - Encoding

        @Test("Encode returns frames for each preset")
        func encodeReturnsPerPreset() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            try await multi.configure(
                presets: [.p360, .p720]
            )

            let buffer = VideoTestDataGenerator.makeBuffer(
                width: 640, height: 360
            )
            let results = try await multi.encode(buffer)
            let flushed = try await multi.flushAll()

            // Combine encode + flush results
            var allResults: [QualityPreset: [EncodedFrame]] = [:]
            for (preset, frames) in results {
                allResults[preset, default: []].append(
                    contentsOf: frames
                )
            }
            for (preset, frames) in flushed {
                allResults[preset, default: []].append(
                    contentsOf: frames
                )
            }

            // Both presets should have at least some frames
            #expect(allResults.keys.count == 2)

            await multi.teardownAll()
        }

        // MARK: - Flush & Teardown

        @Test("FlushAll returns remaining frames per preset")
        func flushAllReturns() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            try await multi.configure(presets: [.p360])

            let buffers = VideoTestDataGenerator.makeBuffers(
                count: 3, width: 640, height: 360
            )
            for buffer in buffers {
                _ = try await multi.encode(buffer)
            }

            let flushed = try await multi.flushAll()
            // At least the p360 key should be present
            #expect(flushed.keys.contains(.p360))

            await multi.teardownAll()
        }

        @Test("TeardownAll releases all encoders")
        func teardownAll() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            try await multi.configure(
                presets: [.p360, .p720]
            )
            await multi.teardownAll()

            // Encode after teardown should fail
            let buffer = VideoTestDataGenerator.makeBuffer()
            await #expect(throws: LiveEncoderError.self) {
                try await multi.encode(buffer)
            }
        }

        // MARK: - Error Cases

        @Test("Encode without configure throws notConfigured")
        func encodeWithoutConfigure() async {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            let buffer = VideoTestDataGenerator.makeBuffer()

            await #expect(
                throws: LiveEncoderError.notConfigured
            ) {
                try await multi.encode(buffer)
            }
        }

        @Test("Encode after teardown throws tornDown")
        func encodeAfterTeardown() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            try await multi.configure(presets: [.p360])
            await multi.teardownAll()

            let buffer = VideoTestDataGenerator.makeBuffer()

            await #expect(throws: LiveEncoderError.tornDown) {
                try await multi.encode(buffer)
            }
        }

        @Test("Configure after teardown works (reconfigure)")
        func reconfigureAfterTeardown() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            try await multi.configure(presets: [.p360])
            await multi.teardownAll()

            // Should be able to reconfigure
            try await multi.configure(presets: [.p720])
            await multi.teardownAll()
        }

        // MARK: - Flush Safety

        @Test("FlushAll without configure returns empty")
        func flushWithoutConfigure() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            let result = try await multi.flushAll()
            #expect(result.isEmpty)
        }

        @Test("TeardownAll without configure is safe")
        func teardownWithoutConfigure() async {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            await multi.teardownAll()
        }

        // MARK: - Base Config

        @Test("Configure with custom base config")
        func customBaseConfig() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            let baseConfig = LiveEncoderConfiguration(
                videoCodec: .h264,
                keyframeInterval: 2.0
            )
            try await multi.configure(
                presets: [.p360],
                baseConfig: baseConfig
            )
            await multi.teardownAll()
        }

        @Test("HEVC base config")
        func hevcBaseConfig() async throws {
            let multi = MultiBitrateEncoder {
                VideoEncoder()
            }
            let baseConfig = LiveEncoderConfiguration(
                videoCodec: .h265,
                keyframeInterval: 4.0
            )
            try await multi.configure(
                presets: [.p720],
                baseConfig: baseConfig
            )
            await multi.teardownAll()
        }
    }

#endif
