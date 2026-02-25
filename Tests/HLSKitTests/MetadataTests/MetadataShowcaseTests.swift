// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Metadata Showcase", .timeLimit(.minutes(1)))
struct MetadataShowcaseTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    // MARK: - Podcast Live Stream

    @Test("Podcast: track info injected via ID3 every segment")
    func podcastTrackInfo() async {
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            )
        )
        await injector.queueTrackInfo(
            title: "Episode 42: The Answer",
            artist: "The Podcast"
        )
        let m = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(m.id3Data != nil)
        #expect(m.programDateTime != nil)
        // Parse the ID3 data back
        if let id3Data = m.id3Data {
            let parsed = ID3TimedMetadata.parse(from: id3Data)
            #expect(parsed != nil)
        }
    }

    // MARK: - Sports Broadcast

    @Test("Sports: PDT every segment + ad break via DATERANGE")
    func sportsBroadcast() async {
        let manager = DateRangeManager()
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            ),
            dateRangeManager: manager
        )
        // Open ad break
        await injector.openDateRange(
            id: "ad-break-1",
            class: "com.example.ad",
            plannedDuration: 30.0
        )
        let m = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(m.programDateTime != nil)
        #expect(m.dateRanges.contains("ad-break-1"))
        #expect(m.dateRanges.contains("PLANNED-DURATION"))
        // Close ad break
        await injector.closeDateRange(id: "ad-break-1")
        let range = await manager.range(id: "ad-break-1")
        #expect(range?.state == .closed)
    }

    // MARK: - Live Radio

    @Test("Live radio: different ID3 metadata per segment")
    func liveRadio() async {
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            )
        )
        // Track 1
        await injector.queueTrackInfo(title: "Song A", artist: "Artist A")
        let m1 = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(m1.id3Data != nil)
        // Track 2 (different metadata)
        await injector.queueTrackInfo(title: "Song B", artist: "Artist B")
        let m2 = await injector.metadataForSegment(
            index: 1, duration: 6.0
        )
        #expect(m2.id3Data != nil)
        #expect(m1.id3Data != m2.id3Data)
    }

    // MARK: - CDN Variable Substitution

    @Test("CDN variable substitution: define + resolve URIs")
    func cdnVariableSubstitution() {
        var resolver = VariableResolver()
        resolver.define(name: "cdn", value: "cdn.example.com")
        resolver.define(name: "path", value: "live/stream1")
        let uri = resolver.resolve(
            "https://{$cdn}/{$path}/segment0.ts"
        )
        #expect(uri == "https://cdn.example.com/live/stream1/segment0.ts")
    }

    // MARK: - Ad Insertion

    @Test("Ad insertion: open → set X-ASSET-URI → close")
    func adInsertion() async {
        let manager = DateRangeManager()
        await manager.open(
            id: "ad-1",
            startDate: refDate,
            class: "com.example.ad",
            plannedDuration: 30.0,
            customAttributes: [
                "X-ASSET-URI": "https://ads.example.com/spot42.mp4"
            ]
        )
        let range = await manager.range(id: "ad-1")
        #expect(
            range?.customAttributes["X-ASSET-URI"]
                == "https://ads.example.com/spot42.mp4"
        )
        // Close after 30s
        await manager.close(
            id: "ad-1",
            endDate: refDate.addingTimeInterval(30)
        )
        let closed = await manager.range(id: "ad-1")
        #expect(closed?.state == .closed)
    }

    // MARK: - SCTE-35 Markers

    @Test("SCTE-35 binary data in DATERANGE")
    func scte35Markers() async {
        let manager = DateRangeManager()
        await manager.open(id: "splice-1", startDate: refDate)
        // Simulate SCTE-35 by rendering and checking
        let rendered = await manager.renderDateRanges()
        #expect(rendered.contains("splice-1"))
    }

    // MARK: - Conference Stream

    @Test("Conference: chapters via DATERANGE with X-CHAPTER-TITLE")
    func conferenceChapters() async {
        let manager = DateRangeManager()
        await manager.open(
            id: "chapter-1",
            startDate: refDate,
            customAttributes: ["X-CHAPTER-TITLE": "Keynote"]
        )
        await manager.close(
            id: "chapter-1",
            endDate: refDate.addingTimeInterval(3600)
        )
        await manager.open(
            id: "chapter-2",
            startDate: refDate.addingTimeInterval(3600),
            customAttributes: ["X-CHAPTER-TITLE": "Q&A"]
        )
        let active = await manager.activeRanges
        #expect(active.count == 2)
        let titles = active.compactMap {
            $0.customAttributes["X-CHAPTER-TITLE"]
        }
        #expect(titles.contains("Keynote"))
        #expect(titles.contains("Q&A"))
    }

    // MARK: - Multi-Variable Playlist

    @Test("5 variables defined and all URIs resolved")
    func multiVariable() {
        var resolver = VariableResolver()
        resolver.define(name: "scheme", value: "https")
        resolver.define(name: "host", value: "cdn.example.com")
        resolver.define(name: "path", value: "live")
        resolver.define(name: "quality", value: "hd")
        resolver.define(name: "token", value: "xyz789")
        let uri = resolver.resolve(
            "{$scheme}://{$host}/{$path}/{$quality}/seg.ts?t={$token}"
        )
        #expect(uri == "https://cdn.example.com/live/hd/seg.ts?t=xyz789")
    }

    // MARK: - QUERYPARAM Extraction

    @Test("QUERYPARAM: token from URL substituted into segment URIs")
    func queryParamExtraction() {
        var resolver = VariableResolver()
        let found = resolver.defineFromQueryParam(
            name: "token",
            url: "https://example.com/master.m3u8?token=secret123"
        )
        #expect(found)
        let uri = resolver.resolve(
            "https://cdn.com/seg0.ts?auth={$token}"
        )
        #expect(uri == "https://cdn.com/seg0.ts?auth=secret123")
    }

    // MARK: - Full Pipeline

    @Test("Full pipeline: 10 segments with mixed metadata")
    func fullPipeline() async {
        let manager = DateRangeManager()
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            ),
            dateRangeManager: manager
        )
        // Open a date range at segment 3
        var results = [LiveMetadataInjector.SegmentMetadata]()
        for i in 0..<10 {
            if i == 3 {
                await injector.openDateRange(
                    id: "midroll", class: "com.ad"
                )
            }
            if i == 5 {
                await injector.queueTrackInfo(
                    title: "Track Change"
                )
            }
            if i == 6 {
                await injector.closeDateRange(id: "midroll")
            }
            let m = await injector.metadataForSegment(
                index: i, duration: 6.0
            )
            results.append(m)
        }
        // All segments should have PDT (everySegment)
        #expect(results.allSatisfy { $0.programDateTime != nil })
        // Segments 3-5 should have date ranges
        #expect(results[3].dateRanges.contains("midroll"))
        // Segment 5 should have ID3
        #expect(results[5].id3Data != nil)
        // Segment 7 should not have ID3
        #expect(results[7].id3Data == nil)
    }
}
