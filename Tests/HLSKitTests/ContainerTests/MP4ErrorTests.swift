// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("MP4Error")
struct MP4ErrorTests {

    @Test("All cases have non-empty errorDescription")
    func allErrorDescriptions() throws {
        let cases: [MP4Error] = [
            .invalidMP4("test"),
            .missingBox("moov"),
            .invalidBoxData(box: "mvhd", reason: "bad"),
            .fileTooLarge(1_000_000_000),
            .unsupportedCodec("xyz"),
            .ioError("disk full")
        ]
        for error in cases {
            let desc = error.errorDescription
            let unwrapped = try #require(desc)
            #expect(!unwrapped.isEmpty)
        }
    }

    @Test("Hashable conformance")
    func hashable() {
        let a = MP4Error.missingBox("moov")
        let b = MP4Error.missingBox("moov")
        let c = MP4Error.missingBox("trak")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("BinaryReaderError — errorDescription")
    func binaryReaderErrorDescription() {
        let eod = BinaryReaderError.endOfData(
            needed: 4, available: 0
        )
        #expect(eod.errorDescription != nil)
        let inv = BinaryReaderError.invalidData("bad FourCC")
        #expect(inv.errorDescription != nil)
    }
}
