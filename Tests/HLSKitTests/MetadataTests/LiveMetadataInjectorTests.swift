// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LiveMetadataInjector", .timeLimit(.minutes(1)))
struct LiveMetadataInjectorTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    // MARK: - Segment Metadata

    @Test("metadataForSegment includes programDateTime when needed")
    func includesPDT() async {
        let sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        let injector = LiveMetadataInjector(dateTimeSync: sync)
        let metadata = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(metadata.programDateTime != nil)
        #expect(
            metadata.programDateTime?.hasPrefix(
                "#EXT-X-PROGRAM-DATE-TIME:"
            ) == true
        )
    }

    @Test("metadataForSegment includes dateRanges when active")
    func includesDateRanges() async {
        let sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        let manager = DateRangeManager()
        await manager.open(
            id: "ad-1", startDate: refDate, class: "com.ad"
        )
        let injector = LiveMetadataInjector(
            dateTimeSync: sync,
            dateRangeManager: manager
        )
        let metadata = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(metadata.dateRanges.contains("#EXT-X-DATERANGE:"))
    }

    @Test("metadataForSegment includes id3Data when queued")
    func includesID3() async {
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .onDiscontinuity
            )
        )
        var id3 = ID3TimedMetadata()
        id3.addTextFrame(.title, value: "Track Title")
        await injector.queueID3(id3)
        let metadata = await injector.metadataForSegment(
            index: 1, duration: 6.0
        )
        #expect(metadata.id3Data != nil)
    }

    @Test("queueID3 consumed after metadataForSegment")
    func id3ConsumedAfterUse() async {
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .onDiscontinuity
            )
        )
        var id3 = ID3TimedMetadata()
        id3.addTextFrame(.title, value: "Test")
        await injector.queueID3(id3)
        // First call consumes
        let m1 = await injector.metadataForSegment(
            index: 1, duration: 6.0
        )
        #expect(m1.id3Data != nil)
        // Second call has none
        let m2 = await injector.metadataForSegment(
            index: 2, duration: 6.0
        )
        #expect(m2.id3Data == nil)
    }

    @Test("queueTrackInfo creates ID3 with TIT2/TPE1/TALB")
    func queueTrackInfo() async {
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .onDiscontinuity
            )
        )
        await injector.queueTrackInfo(
            title: "My Track",
            artist: "My Artist",
            album: "My Album"
        )
        let pending = await injector.pendingID3
        #expect(pending.count == 1)
        let frameIDs = pending.first?.frames.map(\.id)
        #expect(frameIDs?.contains("TIT2") == true)
        #expect(frameIDs?.contains("TPE1") == true)
        #expect(frameIDs?.contains("TALB") == true)
    }

    // MARK: - Date Range Shortcuts

    @Test("openDateRange delegates to DateRangeManager")
    func openDateRange() async {
        let manager = DateRangeManager()
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(streamStartDate: refDate),
            dateRangeManager: manager
        )
        await injector.openDateRange(id: "ad-1", class: "com.ad")
        let range = await manager.range(id: "ad-1")
        #expect(range != nil)
        #expect(range?.classAttribute == "com.ad")
    }

    @Test("closeDateRange delegates to DateRangeManager")
    func closeDateRange() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad-1", startDate: refDate)
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(streamStartDate: refDate),
            dateRangeManager: manager
        )
        await injector.closeDateRange(id: "ad-1")
        let range = await manager.range(id: "ad-1")
        #expect(range?.state == .closed)
    }

    // MARK: - hasMetadata

    @Test("hasMetadata true when programDateTime present")
    func hasMetadataPDT() async {
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            )
        )
        let metadata = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(metadata.hasMetadata)
    }

    @Test("hasMetadata false when empty")
    func hasMetadataFalse() async {
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .onDiscontinuity
            )
        )
        // Index 1, not discontinuity → no PDT; no date ranges; no ID3
        let metadata = await injector.metadataForSegment(
            index: 1, duration: 6.0
        )
        #expect(!metadata.hasMetadata)
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func resetClears() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad-1", startDate: refDate)
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(streamStartDate: refDate),
            dateRangeManager: manager
        )
        var id3 = ID3TimedMetadata()
        id3.addTextFrame(.title, value: "Test")
        await injector.queueID3(id3)
        await injector.reset()
        let pending = await injector.pendingID3
        #expect(pending.isEmpty)
        let ranges = await manager.allRanges
        #expect(ranges.isEmpty)
    }
}
