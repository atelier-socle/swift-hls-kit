// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("IMSC1Segmenter — fMP4 Segment Generation")
struct IMSC1SegmenterTests {

    let segmenter = IMSC1Segmenter()

    // MARK: - Init Segment

    @Test("Init segment is non-empty")
    func initSegmentNonEmpty() {
        let data = segmenter.createInitSegment()
        #expect(data.count > 0)
    }

    @Test("Init segment starts with ftyp box")
    func initSegmentFtyp() {
        let data = segmenter.createInitSegment()
        let fourCC = String(
            data: data[4..<8],
            encoding: .ascii
        )
        #expect(fourCC == "ftyp")
    }

    @Test("Init segment contains moov box")
    func initSegmentMoov() {
        let data = segmenter.createInitSegment()
        #expect(containsBox(data, type: "moov"))
    }

    @Test("Init segment contains stpp sample entry")
    func initSegmentStpp() {
        let data = segmenter.createInitSegment()
        #expect(containsBox(data, type: "stpp"))
    }

    @Test("Init segment contains subt handler")
    func initSegmentSubtHandler() {
        let data = segmenter.createInitSegment()
        #expect(containsBox(data, type: "hdlr"))
        let subtBytes = Data("subt".utf8)
        #expect(containsBytes(data, bytes: subtBytes))
    }

    @Test("Init segment contains nmhd (null media header)")
    func initSegmentNmhd() {
        let data = segmenter.createInitSegment()
        #expect(containsBox(data, type: "nmhd"))
    }

    @Test("Init segment with custom language and timescale")
    func initSegmentCustomParams() {
        let data = segmenter.createInitSegment(
            language: "fra", timescale: 90000
        )
        #expect(data.count > 0)
        #expect(containsBox(data, type: "mdhd"))
    }

    // MARK: - Media Segment

    @Test("Media segment is non-empty")
    func mediaSegmentNonEmpty() {
        let doc = IMSC1Document(
            language: "en",
            subtitles: [
                IMSC1Subtitle(
                    begin: 0, end: 2, text: "Hello"
                )
            ]
        )
        let data = segmenter.createMediaSegment(
            document: doc,
            sequenceNumber: 1,
            baseDecodeTime: 0,
            duration: 6000
        )
        #expect(data.count > 0)
    }

    @Test("Media segment contains moof and mdat boxes")
    func mediaSegmentMoofMdat() {
        let doc = IMSC1Document(
            language: "en",
            subtitles: [
                IMSC1Subtitle(
                    begin: 0, end: 2, text: "Test"
                )
            ]
        )
        let data = segmenter.createMediaSegment(
            document: doc,
            sequenceNumber: 1,
            baseDecodeTime: 0,
            duration: 6000
        )
        #expect(containsBox(data, type: "moof"))
        #expect(containsBox(data, type: "mdat"))
    }

    @Test("Media segment mdat contains TTML XML")
    func mediaSegmentMdatContent() {
        let doc = IMSC1Document(
            language: "en",
            subtitles: [
                IMSC1Subtitle(
                    begin: 0, end: 2, text: "In mdat"
                )
            ]
        )
        let data = segmenter.createMediaSegment(
            document: doc,
            sequenceNumber: 1,
            baseDecodeTime: 0,
            duration: 6000
        )
        let str = String(data: data, encoding: .utf8) ?? ""
        #expect(str.contains("In mdat"))
        #expect(str.contains("<tt"))
    }

    @Test("Sequential media segments have different sequence numbers")
    func sequentialSegments() {
        let doc = IMSC1Document(
            language: "en",
            subtitles: [
                IMSC1Subtitle(
                    begin: 0, end: 2, text: "Seq"
                )
            ]
        )
        let seg1 = segmenter.createMediaSegment(
            document: doc, sequenceNumber: 1,
            baseDecodeTime: 0, duration: 6000
        )
        let seg2 = segmenter.createMediaSegment(
            document: doc, sequenceNumber: 2,
            baseDecodeTime: 6000, duration: 6000
        )
        #expect(seg1 != seg2)
    }

    @Test("Init and media segments form valid stream")
    func initPlusMediaValid() {
        let initSeg = segmenter.createInitSegment(
            language: "eng"
        )
        let doc = IMSC1Document(
            language: "en",
            subtitles: [
                IMSC1Subtitle(
                    begin: 0, end: 6, text: "Stream test"
                )
            ]
        )
        let mediaSeg = segmenter.createMediaSegment(
            document: doc, sequenceNumber: 1,
            baseDecodeTime: 0, duration: 6000
        )
        // Verify both segments are valid box containers
        #expect(containsBox(initSeg, type: "ftyp"))
        #expect(containsBox(initSeg, type: "moov"))
        #expect(containsBox(mediaSeg, type: "moof"))
        #expect(containsBox(mediaSeg, type: "mdat"))
    }

    // MARK: - Helpers

    private func containsBox(
        _ data: Data, type: String
    ) -> Bool {
        let typeBytes = Data(type.utf8)
        guard typeBytes.count == 4 else { return false }
        for i in 4..<(data.count - 3)
        where data[i] == typeBytes[0]
            && data[i + 1] == typeBytes[1]
            && data[i + 2] == typeBytes[2]
            && data[i + 3] == typeBytes[3]
        {
            return true
        }
        return false
    }

    private func containsBytes(
        _ data: Data, bytes: Data
    ) -> Bool {
        guard bytes.count <= data.count else { return false }
        for i in 0...(data.count - bytes.count)
        where data[i..<(i + bytes.count)] == bytes {
            return true
        }
        return false
    }
}
