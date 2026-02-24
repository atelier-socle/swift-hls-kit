// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - ParserError

@Suite("Error Showcase — ParserError")
struct ParserErrorShowcase {

    @Test("ParserError — all 11 cases exist and have descriptions")
    func allCases() {
        let errors: [ParserError] = [
            .emptyManifest,
            .missingHeader,
            .ambiguousPlaylistType,
            .missingRequiredTag("EXT-X-TARGETDURATION"),
            .missingRequiredAttribute(tag: "EXT-X-STREAM-INF", attribute: "BANDWIDTH"),
            .invalidAttributeValue(tag: "EXT-X-STREAM-INF", attribute: "BANDWIDTH", value: "abc"),
            .invalidTagFormat(tag: "EXTINF", line: 5),
            .invalidDuration(line: 3),
            .missingURI(afterTag: "EXT-X-STREAM-INF", line: 7),
            .invalidVersion("99"),
            .parsingFailed(reason: "unexpected token", line: 10)
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("ParserError — emptyManifest description")
    func emptyManifest() {
        let e = ParserError.emptyManifest
        #expect(e.errorDescription?.contains("empty") == true)
    }

    @Test("ParserError — missingHeader description")
    func missingHeader() {
        let e = ParserError.missingHeader
        #expect(e.errorDescription?.contains("EXTM3U") == true)
    }

    @Test("ParserError — parsingFailed with and without line")
    func parsingFailed() {
        let withLine = ParserError.parsingFailed(reason: "bad", line: 5)
        let withoutLine = ParserError.parsingFailed(reason: "bad", line: nil)
        #expect(withLine.errorDescription?.contains("line 5") == true)
        #expect(withoutLine.errorDescription?.contains("line") == false)
    }

    @Test("ParserError — Hashable conformance")
    func hashable() {
        let a = ParserError.emptyManifest
        let b = ParserError.emptyManifest
        #expect(a == b)
        let c = ParserError.missingHeader
        #expect(a != c)
    }

    @Test("ParserError — Sendable conformance (compiles)")
    func sendable() {
        let error: any Sendable = ParserError.emptyManifest
        _ = error
    }
}

// MARK: - MP4Error

@Suite("Error Showcase — MP4Error")
struct MP4ErrorShowcase {

    @Test("MP4Error — all 6 cases exist and have descriptions")
    func allCases() {
        let errors: [MP4Error] = [
            .invalidMP4("not ISOBMFF"),
            .missingBox("moov"),
            .invalidBoxData(box: "stts", reason: "truncated"),
            .fileTooLarge(10_000_000_000),
            .unsupportedCodec("vp8"),
            .ioError("permission denied")
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("MP4Error — fileTooLarge includes byte count")
    func fileTooLarge() {
        let e = MP4Error.fileTooLarge(5_000_000)
        #expect(e.errorDescription?.contains("5000000") == true)
    }

    @Test("MP4Error — invalidBoxData includes box name and reason")
    func invalidBoxData() {
        let e = MP4Error.invalidBoxData(box: "stts", reason: "bad entry")
        #expect(e.errorDescription?.contains("stts") == true)
        #expect(e.errorDescription?.contains("bad entry") == true)
    }

    @Test("MP4Error — Hashable conformance")
    func hashable() {
        let a = MP4Error.missingBox("moov")
        let b = MP4Error.missingBox("moov")
        let c = MP4Error.missingBox("trak")
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - TranscodingError

@Suite("Error Showcase — TranscodingError")
struct TranscodingErrorShowcase {

    @Test("TranscodingError — all 10 cases exist and have descriptions")
    func allCases() {
        let errors: [TranscodingError] = [
            .sourceNotFound("/tmp/missing.mp4"),
            .unsupportedSourceFormat("gif"),
            .outputDirectoryError("/root/nope"),
            .codecNotAvailable("av1"),
            .hardwareEncoderNotAvailable("VideoToolbox"),
            .encodingFailed("bitstream error"),
            .decodingFailed("corrupt header"),
            .cancelled,
            .invalidConfig("negative bitrate"),
            .transcoderNotAvailable("FFmpeg")
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("TranscodingError — cancelled has no associated value")
    func cancelled() {
        let e = TranscodingError.cancelled
        #expect(e.errorDescription?.contains("cancelled") == true)
    }

    @Test("TranscodingError — Hashable conformance")
    func hashable() {
        let a = TranscodingError.cancelled
        let b = TranscodingError.cancelled
        #expect(a == b)
        let c = TranscodingError.sourceNotFound("x")
        #expect(a != c)
    }
}

// MARK: - EncryptionError

@Suite("Error Showcase — EncryptionError")
struct EncryptionErrorShowcase {

    @Test("EncryptionError — all 8 cases exist and have descriptions")
    func allCases() {
        let errors: [EncryptionError] = [
            .invalidKeySize(8),
            .invalidIVSize(32),
            .cryptoFailed("CCCrypt returned -1"),
            .randomGenerationFailed("entropy exhausted"),
            .segmentNotFound("seg0.ts"),
            .keyNotFound("/tmp/key.bin"),
            .unsupportedMethod("CHACHA20"),
            .invalidConfig("missing key URL")
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("EncryptionError — invalidKeySize includes byte count")
    func invalidKeySize() {
        let e = EncryptionError.invalidKeySize(8)
        #expect(e.errorDescription?.contains("8") == true)
        #expect(e.errorDescription?.contains("16") == true)
    }

    @Test("EncryptionError — Hashable conformance")
    func hashable() {
        let a = EncryptionError.invalidKeySize(8)
        let b = EncryptionError.invalidKeySize(8)
        let c = EncryptionError.invalidKeySize(32)
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - TransportError

@Suite("Error Showcase — TransportError")
struct TransportErrorShowcase {

    @Test("TransportError — all 5 cases exist and have descriptions")
    func allCases() {
        let errors: [TransportError] = [
            .invalidAVCConfig("missing SPS"),
            .invalidAudioConfig("bad esds"),
            .pesError("payload too large"),
            .packetError("continuity counter mismatch"),
            .unsupportedCodec("vp9")
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
        }
    }

    @Test("TransportError — invalidAVCConfig includes detail")
    func invalidAVCConfig() {
        let e = TransportError.invalidAVCConfig("missing SPS")
        #expect(e.errorDescription?.contains("missing SPS") == true)
    }

    @Test("TransportError — Hashable conformance")
    func hashable() {
        let a = TransportError.pesError("x")
        let b = TransportError.pesError("x")
        let c = TransportError.pesError("y")
        #expect(a == b)
        #expect(a != c)
    }
}

// MARK: - Additional Codec Coverage

@Suite("Error Showcase — Additional Codec Enums")
struct AdditionalCodecShowcase {

    @Test("OutputAudioCodec — all 5 codecs including heAACv2 and flac")
    func allOutputAudioCodecs() {
        #expect(OutputAudioCodec.aac.rawValue == "aac")
        #expect(OutputAudioCodec.heAAC.rawValue == "heAAC")
        #expect(OutputAudioCodec.heAACv2.rawValue == "heAACv2")
        #expect(OutputAudioCodec.flac.rawValue == "flac")
        #expect(OutputAudioCodec.opus.rawValue == "opus")
    }

    @Test("EncryptionMethod — sampleAESCTR raw value")
    func sampleAESCTR() {
        #expect(EncryptionMethod.sampleAESCTR.rawValue == "SAMPLE-AES-CTR")
    }
}
