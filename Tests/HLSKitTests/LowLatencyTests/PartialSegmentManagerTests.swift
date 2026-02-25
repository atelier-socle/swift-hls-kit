// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PartialSegmentManager", .timeLimit(.minutes(1)))
struct PartialSegmentManagerTests {

    // MARK: - Basic Operations

    @Test("Add partial returns correct partial")
    func addPartial() async throws {
        let manager = PartialSegmentManager()
        let partial = try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        #expect(partial.duration == 0.33)
        #expect(partial.isIndependent == true)
        #expect(partial.segmentIndex == 0)
        #expect(partial.partialIndex == 0)
    }

    @Test("Add multiple partials increments index")
    func addMultiple() async throws {
        let manager = PartialSegmentManager()
        let p0 = try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        let p1 = try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        let p2 = try await manager.addPartial(
            duration: 0.34, isIndependent: false
        )

        #expect(p0.partialIndex == 0)
        #expect(p1.partialIndex == 1)
        #expect(p2.partialIndex == 2)
        let count = await manager.currentPartialCount
        #expect(count == 3)
    }

    @Test("Count reflects current partials")
    func counts() async throws {
        let manager = PartialSegmentManager()
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )

        let current = await manager.currentPartialCount
        let total = await manager.totalPartialCount
        #expect(current == 2)
        #expect(total == 2)
    }

    // MARK: - First Partial Independence

    @Test("First partial must be independent")
    func firstPartialMustBeIndependent() async {
        let manager = PartialSegmentManager()
        await #expect(
            throws: LLHLSError.firstPartialMustBeIndependent
        ) {
            try await manager.addPartial(
                duration: 0.33, isIndependent: false
            )
        }
    }

    @Test("Second partial can be non-independent")
    func secondPartialCanBeDependent() async throws {
        let manager = PartialSegmentManager()
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        let p2 = try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        #expect(p2.isIndependent == false)
    }

    // MARK: - Complete Segment

    @Test("Complete segment returns partials")
    func completeSegment() async throws {
        let manager = PartialSegmentManager()
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )

        let completed = await manager.completeSegment()
        #expect(completed.count == 2)
        #expect(completed[0].partialIndex == 0)
        #expect(completed[1].partialIndex == 1)
    }

    @Test("Segment index advances after completion")
    func segmentIndexAdvances() async throws {
        let manager = PartialSegmentManager()
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment()

        let idx = await manager.activeSegmentIndex
        #expect(idx == 1)

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        let p = await manager.currentPartialCount
        #expect(p == 1)
    }

    @Test("Current partials empty after completion")
    func currentEmptyAfterComplete() async throws {
        let manager = PartialSegmentManager()
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment()

        let count = await manager.currentPartialCount
        #expect(count == 0)
    }

    // MARK: - Retention & Eviction

    @Test("Retained segments keep partials")
    func retainedPartials() async throws {
        let manager = PartialSegmentManager(
            maxRetainedSegments: 2
        )

        // Segment 0
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment()

        // Segment 1
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment()

        let rendering = await manager.partialsForRendering()
        #expect(rendering.count == 2)
    }

    @Test("Eviction removes oldest segment partials")
    func eviction() async throws {
        let manager = PartialSegmentManager(
            maxRetainedSegments: 2
        )

        for i in 0..<4 {
            try await manager.addPartial(
                duration: 0.33,
                uri: "seg\(i).0.mp4",
                isIndependent: true
            )
            _ = await manager.completeSegment()
        }

        let rendering = await manager.partialsForRendering()
        // Only segments 2 and 3 retained
        #expect(rendering.count == 2)
        #expect(rendering[0].segmentIndex == 2)
        #expect(rendering[1].segmentIndex == 3)
    }

    // MARK: - Rendering

    @Test("partialsForRendering includes current segment")
    func renderingIncludesCurrent() async throws {
        let manager = PartialSegmentManager(
            maxRetainedSegments: 2
        )

        // Complete segment 0
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment()

        // Start segment 1 (incomplete)
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )

        let rendering = await manager.partialsForRendering()
        // Segment 0 retained + segment 1 in-progress
        #expect(rendering.count == 2)
        #expect(rendering[1].segmentIndex == 1)
        #expect(rendering[1].partials.count == 2)
    }

    // MARK: - Preload Hint

    @Test("Preload hint points to next partial")
    func preloadHint() async throws {
        let manager = PartialSegmentManager()
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let hint = await manager.currentPreloadHint()
        #expect(hint?.type == .part)
        #expect(hint?.uri == "seg0.1.mp4")
    }

    @Test("Preload hint for first partial of new segment")
    func preloadHintNewSegment() async throws {
        let manager = PartialSegmentManager()
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment()

        let hint = await manager.currentPreloadHint()
        #expect(hint?.uri == "seg1.0.mp4")
    }

    @Test("Preload hint nil when ended")
    func preloadHintNilWhenEnded() async {
        let manager = PartialSegmentManager()
        await manager.end()

        let hint = await manager.currentPreloadHint()
        #expect(hint == nil)
    }

    // MARK: - Auto-generated URI

    @Test("URI auto-generated from template")
    func autoURI() async throws {
        let manager = PartialSegmentManager(
            uriTemplate: "part-{segment}-{part}.{ext}",
            fileExtension: "m4s"
        )
        let partial = try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        #expect(partial.uri == "part-0-0.m4s")
    }

    @Test("Custom URI overrides template")
    func customURI() async throws {
        let manager = PartialSegmentManager()
        let partial = try await manager.addPartial(
            duration: 0.33, uri: "custom.mp4",
            isIndependent: true
        )
        #expect(partial.uri == "custom.mp4")
    }

    // MARK: - Stream End

    @Test("Add partial after end throws")
    func addAfterEnd() async {
        let manager = PartialSegmentManager()
        await manager.end()

        await #expect(throws: LLHLSError.streamAlreadyEnded) {
            try await manager.addPartial(
                duration: 0.33, isIndependent: true
            )
        }
    }

    // MARK: - Edge: Complete with zero partials

    @Test("Complete segment with zero partials")
    func completeEmpty() async {
        let manager = PartialSegmentManager()
        let completed = await manager.completeSegment()
        #expect(completed.isEmpty)
        let idx = await manager.activeSegmentIndex
        #expect(idx == 1)
    }

    // MARK: - Multi-segment Lifecycle

    @Test("Multiple segment lifecycle")
    func multiSegmentLifecycle() async throws {
        let manager = PartialSegmentManager(
            maxRetainedSegments: 2
        )

        for seg in 0..<5 {
            for part in 0..<3 {
                try await manager.addPartial(
                    duration: 0.33,
                    isIndependent: part == 0
                )
            }
            _ = await manager.completeSegment()

            let idx = await manager.activeSegmentIndex
            #expect(idx == seg + 1)
        }

        let total = await manager.totalPartialCount
        // 2 retained segments × 3 partials = 6
        #expect(total == 6)
    }
}
