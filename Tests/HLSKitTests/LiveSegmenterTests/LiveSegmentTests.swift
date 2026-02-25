// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LiveSegment", .timeLimit(.minutes(1)))
struct LiveSegmentTests {

    @Test("Creation with all properties")
    func fullCreation() {
        let date = Date()
        let segment = LiveSegment(
            index: 3,
            data: Data(repeating: 0xAA, count: 1000),
            duration: 6.023,
            timestamp: MediaTimestamp(seconds: 18.0),
            isIndependent: true,
            byteRange: 0..<1000,
            discontinuity: true,
            isGap: false,
            programDateTime: date,
            filename: "segment_3.m4s",
            frameCount: 180,
            codecs: [.h264, .aac]
        )

        #expect(segment.index == 3)
        #expect(segment.data.count == 1000)
        #expect(segment.duration == 6.023)
        #expect(segment.timestamp.seconds == 18.0)
        #expect(segment.isIndependent)
        #expect(segment.byteRange == 0..<1000)
        #expect(segment.discontinuity)
        #expect(!segment.isGap)
        #expect(segment.programDateTime == date)
        #expect(segment.filename == "segment_3.m4s")
        #expect(segment.frameCount == 180)
        #expect(segment.codecs.contains(.h264))
        #expect(segment.codecs.contains(.aac))
    }

    @Test("Default values")
    func defaultValues() {
        let segment = LiveSegment(
            index: 0,
            data: Data(),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: true,
            filename: "segment_0.m4s",
            frameCount: 0,
            codecs: []
        )

        #expect(segment.byteRange == nil)
        #expect(!segment.discontinuity)
        #expect(!segment.isGap)
        #expect(segment.programDateTime == nil)
    }

    @Test("Identifiable conformance (id = index)")
    func identifiable() {
        let segment = LiveSegment(
            index: 42,
            data: Data(),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: true,
            filename: "segment_42.m4s",
            frameCount: 0,
            codecs: []
        )
        #expect(segment.id == 42)
        #expect(segment.id == segment.index)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = LiveSegment(
            index: 0,
            data: Data([1, 2, 3]),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: true,
            filename: "segment_0.m4s",
            frameCount: 10,
            codecs: [.aac]
        )
        let b = LiveSegment(
            index: 0,
            data: Data([1, 2, 3]),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: true,
            filename: "segment_0.m4s",
            frameCount: 10,
            codecs: [.aac]
        )
        let c = LiveSegment(
            index: 1,
            data: Data([1, 2, 3]),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: true,
            filename: "segment_1.m4s",
            frameCount: 10,
            codecs: [.aac]
        )
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Codecs set tracking")
    func codecsTracking() {
        let audioOnly = LiveSegment(
            index: 0,
            data: Data(),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: true,
            filename: "seg_0.m4s",
            frameCount: 1,
            codecs: [.aac]
        )
        #expect(audioOnly.codecs == [.aac])

        let muxed = LiveSegment(
            index: 1,
            data: Data(),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: true,
            filename: "seg_1.m4s",
            frameCount: 2,
            codecs: [.h264, .aac]
        )
        #expect(muxed.codecs.count == 2)
    }

    @Test("Gap segment")
    func gapSegment() {
        let segment = LiveSegment(
            index: 5,
            data: Data(),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: false,
            isGap: true,
            filename: "segment_5.m4s",
            frameCount: 0,
            codecs: []
        )
        #expect(segment.isGap)
        #expect(!segment.isIndependent)
    }
}
