// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("FileSource")
struct FileSourceTests {

    // MARK: - InputError

    @Test("InputError: invalidInput description")
    func inputErrorInvalidInput() {
        let error = InputError.invalidInput("test message")
        #expect(error.errorDescription?.contains("Invalid input") == true)
        #expect(error.errorDescription?.contains("test message") == true)
    }

    @Test("InputError: noMediaTracks description")
    func inputErrorNoMediaTracks() {
        let error = InputError.noMediaTracks
        #expect(error.errorDescription?.contains("No audio or video tracks") == true)
    }

    @Test("InputError: sampleIndexOutOfBounds description")
    func inputErrorSampleIndexOutOfBounds() {
        let error = InputError.sampleIndexOutOfBounds(index: 10, total: 5)
        #expect(error.errorDescription?.contains("10") == true)
        #expect(error.errorDescription?.contains("5") == true)
    }

    @Test("InputError: sourceExhausted description")
    func inputErrorSourceExhausted() {
        let error = InputError.sourceExhausted
        #expect(error.errorDescription?.contains("finished producing") == true)
    }

    @Test("InputError: ioError description")
    func inputErrorIOError() {
        let error = InputError.ioError("disk full")
        #expect(error.errorDescription?.contains("I/O error") == true)
        #expect(error.errorDescription?.contains("disk full") == true)
    }

    @Test("InputError: Equatable conformance")
    func inputErrorEquatable() {
        let error1 = InputError.invalidInput("test")
        let error2 = InputError.invalidInput("test")
        let error3 = InputError.invalidInput("other")
        #expect(error1 == error2)
        #expect(error1 != error3)
    }

    @Test("InputError: Hashable conformance")
    func inputErrorHashable() {
        var set = Set<InputError>()
        set.insert(.noMediaTracks)
        set.insert(.noMediaTracks)
        set.insert(.sourceExhausted)
        #expect(set.count == 2)
    }

    // MARK: - MediaSourceConfiguration

    @Test("MediaSourceConfiguration: default values")
    func mediaSourceConfigurationDefaults() {
        let config = MediaSourceConfiguration()
        #expect(config.preferredBufferSize == nil)
        #expect(!config.loop)
        #expect(config.maxDuration == nil)
        #expect(config.startTime == 0)
    }

    @Test("MediaSourceConfiguration: custom values")
    func mediaSourceConfigurationCustom() {
        let config = MediaSourceConfiguration(
            preferredBufferSize: 1024,
            loop: true,
            maxDuration: 60.0,
            startTime: 10.0
        )
        #expect(config.preferredBufferSize == 1024)
        #expect(config.loop)
        #expect(config.maxDuration == 60.0)
        #expect(config.startTime == 10.0)
    }

    @Test("MediaSourceConfiguration: Sendable conformance")
    func mediaSourceConfigurationSendable() async {
        let config = MediaSourceConfiguration(loop: true)
        await Task {
            #expect(config.loop)
        }.value
    }
}

// MARK: - FileSource Actor Tests

@Suite("FileSource Actor")
struct FileSourceActorTests {

    @Test("FileSource: throws for non-existent file")
    func fileSourceNonExistent() async throws {
        let url = URL(fileURLWithPath: "/nonexistent/path/video.mp4")
        do {
            _ = try FileSource(url: url)
            Issue.record("Expected error for non-existent file")
        } catch {
            #expect(error is CocoaError)
        }
    }
}
