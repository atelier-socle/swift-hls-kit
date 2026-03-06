// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(VideoToolbox)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("MVHEVCEncoder")
    struct MVHEVCEncoderTests {

        // MARK: - Error Cases

        @Test("MVHEVCEncoderError encodingNotAvailable equality")
        func errorEncodingNotAvailable() {
            let a = MVHEVCEncoderError.encodingNotAvailable
            let b = MVHEVCEncoderError.encodingNotAvailable
            #expect(a == b)
        }

        @Test("MVHEVCEncoderError encodingFailed with message")
        func errorEncodingFailed() {
            let error = MVHEVCEncoderError.encodingFailed("hardware error")
            if case let .encodingFailed(message) = error {
                #expect(message == "hardware error")
            } else {
                Issue.record("Expected encodingFailed case")
            }
        }

        @Test("MVHEVCEncoderError invalidInput with message")
        func errorInvalidInput() {
            let error = MVHEVCEncoderError.invalidInput("empty buffer")
            if case let .invalidInput(message) = error {
                #expect(message == "empty buffer")
            } else {
                Issue.record("Expected invalidInput case")
            }
        }

        // MARK: - Mock Conformance

        @Test("Mock encoder conforms to protocol")
        func mockConformance() {
            let mock = MockMVHEVCEncoder()
            #expect(!mock.isAvailable)
        }
    }

    /// Test mock for MVHEVCEncoder protocol.
    private struct MockMVHEVCEncoder: MVHEVCEncoder {
        var isAvailable: Bool { false }

        func encode(leftEye: Data, rightEye: Data) throws -> Data {
            throw MVHEVCEncoderError.encodingNotAvailable
        }

        func encode(spatialSample: Data) throws -> Data {
            throw MVHEVCEncoderError.encodingNotAvailable
        }
    }

#endif
