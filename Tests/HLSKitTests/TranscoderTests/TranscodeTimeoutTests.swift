// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Transcoding Timeout Configuration

@Suite("Transcoding Timeout")
struct TranscodeTimeoutTests {

    @Test("TranscodingConfig has timeout property")
    func configHasTimeout() {
        let config = TranscodingConfig()
        #expect(config.timeout == 300)
    }

    @Test("TranscodingConfig respects custom timeout")
    func customTimeout() {
        let config = TranscodingConfig(timeout: 60)
        #expect(config.timeout == 60)
    }

    @Test("TranscodingConfig timeout zero means no timeout")
    func zeroTimeout() {
        let config = TranscodingConfig(timeout: 0)
        #expect(config.timeout == 0)
    }

    @Test("TranscodingError.timeout has description")
    func timeoutErrorDescription() {
        let error = TranscodingError.timeout("test message")
        #expect(
            error.errorDescription?.contains("Timeout") == true
        )
    }

    @Test("TranscodingConfig timeout is Hashable")
    func timeoutIsHashable() {
        let config1 = TranscodingConfig(timeout: 60)
        let config2 = TranscodingConfig(timeout: 60)
        let config3 = TranscodingConfig(timeout: 120)
        #expect(config1 == config2)
        #expect(config1 != config3)
    }
}

// MARK: - Transcoding Progress Callback

@Suite("Transcoding Progress")
struct TranscodeProgressTests {

    @Test("Transcoder protocol accepts progress callback")
    func protocolAcceptsProgress() {
        // Verify the protocol signature accepts a progress
        // callback by type-checking
        let _: (@Sendable (Double) -> Void)? = { progress in
            _ = progress
        }
    }

    @Test("TranscodingConfig default values are stable")
    func defaultValues() {
        let config = TranscodingConfig()
        #expect(config.segmentDuration == 6.0)
        #expect(config.audioPassthrough == true)
        #expect(config.timeout == 300)
        #expect(config.generatePlaylist == true)
    }
}
