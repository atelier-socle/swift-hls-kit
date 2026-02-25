// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("BlockingPlaylistRequest", .timeLimit(.minutes(1)))
struct BlockingPlaylistRequestTests {

    // MARK: - Initialization

    @Test("Create with MSN only")
    func createWithMSNOnly() {
        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 47
        )
        #expect(request.mediaSequenceNumber == 47)
        #expect(request.partIndex == nil)
        #expect(request.skipRequest == nil)
    }

    @Test("Create with MSN and partIndex")
    func createWithPartIndex() {
        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 47,
            partIndex: 3
        )
        #expect(request.mediaSequenceNumber == 47)
        #expect(request.partIndex == 3)
        #expect(request.skipRequest == nil)
    }

    @Test("Create with MSN, partIndex, and skipRequest")
    func createWithAllFields() {
        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 47,
            partIndex: 3,
            skipRequest: .yes
        )
        #expect(request.mediaSequenceNumber == 47)
        #expect(request.partIndex == 3)
        #expect(request.skipRequest == .yes)
    }

    // MARK: - fromQueryParameters

    @Test("fromQueryParameters with valid _HLS_msn")
    func fromParamsValidMSN() {
        let request = BlockingPlaylistRequest.fromQueryParameters(
            ["_HLS_msn": "47"]
        )
        let result = try? #require(request)
        #expect(result?.mediaSequenceNumber == 47)
        #expect(result?.partIndex == nil)
        #expect(result?.skipRequest == nil)
    }

    @Test("fromQueryParameters with _HLS_msn and _HLS_part")
    func fromParamsWithPart() {
        let request = BlockingPlaylistRequest.fromQueryParameters(
            ["_HLS_msn": "47", "_HLS_part": "3"]
        )
        let result = try? #require(request)
        #expect(result?.mediaSequenceNumber == 47)
        #expect(result?.partIndex == 3)
    }

    @Test("fromQueryParameters with _HLS_skip=YES")
    func fromParamsWithSkip() {
        let request = BlockingPlaylistRequest.fromQueryParameters(
            ["_HLS_msn": "47", "_HLS_skip": "YES"]
        )
        let result = try? #require(request)
        #expect(result?.skipRequest == .yes)
    }

    @Test("fromQueryParameters returns nil without _HLS_msn")
    func fromParamsMissing() {
        let request = BlockingPlaylistRequest.fromQueryParameters(
            ["_HLS_part": "3"]
        )
        #expect(request == nil)
    }

    @Test("fromQueryParameters returns nil with non-integer _HLS_msn")
    func fromParamsInvalidMSN() {
        let request = BlockingPlaylistRequest.fromQueryParameters(
            ["_HLS_msn": "abc"]
        )
        #expect(request == nil)
    }

    // MARK: - Hashable

    @Test("Hashable: same values produce same hash")
    func hashable() {
        let a = BlockingPlaylistRequest(
            mediaSequenceNumber: 47, partIndex: 3
        )
        let b = BlockingPlaylistRequest(
            mediaSequenceNumber: 47, partIndex: 3
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Hashable: different values produce different hash")
    func hashableDifferent() {
        let a = BlockingPlaylistRequest(
            mediaSequenceNumber: 47, partIndex: 3
        )
        let b = BlockingPlaylistRequest(
            mediaSequenceNumber: 48, partIndex: 3
        )
        #expect(a != b)
    }
}
