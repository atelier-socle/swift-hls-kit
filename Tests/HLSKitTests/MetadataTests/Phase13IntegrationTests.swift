// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Phase 13 Integration", .timeLimit(.minutes(1)))
struct Phase13IntegrationTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    // MARK: - Full Metadata Pipeline

    @Test("Full pipeline: PDT + DateRange + ID3 + SCTE-35 → valid output")
    func fullPipeline() async {
        let dateRangeMgr = DateRangeManager()
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            ),
            dateRangeManager: dateRangeMgr
        )
        // Add a SCTE-35 date range
        let scte = SCTE35Marker.spliceInsert(
            eventId: 42, duration: 30.0, outOfNetwork: true
        )
        await dateRangeMgr.open(
            id: "ad-break",
            startDate: refDate,
            class: "com.example.ad",
            customAttributes: scte.dateRangeAttributes()
        )
        // Add ID3
        await injector.queueTrackInfo(title: "Live Show")
        let metadata = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(metadata.programDateTime != nil)
        #expect(metadata.dateRanges.contains("ad-break"))
        #expect(metadata.dateRanges.contains("SCTE35"))
        #expect(metadata.id3Data != nil)
    }

    // MARK: - Variable Substitution + Interstitial

    @Test("Variable substitution in interstitial asset URI")
    func variableSubInAssetURI() {
        var resolver = VariableResolver()
        resolver.define(name: "cdn_base", value: "https://cdn.example.com")
        let resolved = resolver.resolve(
            "{$cdn_base}/ads/preroll.m3u8"
        )
        let ad = HLSInterstitial(
            id: "preroll",
            startDate: refDate,
            assetURI: resolved
        )
        if case .uri(let uri) = ad.asset {
            #expect(uri == "https://cdn.example.com/ads/preroll.m3u8")
        } else {
            Issue.record("Expected .uri asset")
        }
    }

    // MARK: - SCTE-35 → Interstitial Pipeline

    @Test("SCTE-35 → schedule ad → daterange in output")
    func scte35ToInterstitial() async {
        let scte = SCTE35Marker.spliceInsert(
            eventId: 100, duration: 30.0
        )
        let manager = InterstitialManager()
        await manager.scheduleFromSCTE35(
            scte,
            at: refDate,
            id: "midroll-100",
            assetURI: "https://ads.example.com/mid.m3u8"
        )
        let output = await manager.renderInterstitials()
        #expect(output.contains("midroll-100"))
        #expect(output.contains("#EXT-X-DATERANGE:"))
    }

    // MARK: - DateRangeManager + InterstitialManager

    @Test("Interstitials appear in DateRangeManager output")
    func interstitialsInDateRanges() async {
        let dateRangeMgr = DateRangeManager()
        let intMgr = InterstitialManager(dateRangeManager: dateRangeMgr)
        await intMgr.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        let output = await dateRangeMgr.renderDateRanges()
        #expect(output.contains("ad-1"))
    }

    // MARK: - LiveMetadataInjector with Interstitials

    @Test("LiveMetadataInjector includes interstitials in metadata")
    func injectorWithInterstitials() async {
        let dateRangeMgr = DateRangeManager()
        let intMgr = InterstitialManager(dateRangeManager: dateRangeMgr)
        await intMgr.scheduleAd(
            id: "preroll",
            at: refDate,
            assetURI: "https://ads.example.com/preroll.m3u8"
        )
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            ),
            dateRangeManager: dateRangeMgr,
            interstitialManager: intMgr
        )
        let metadata = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(metadata.interstitials.contains("preroll"))
    }

    // MARK: - ID3 + SCTE-35

    @Test("ID3 metadata + SCTE-35 in same segment")
    func id3AndScte35() async {
        let dateRangeMgr = DateRangeManager()
        let scte = SCTE35Marker.spliceInsert(eventId: 1, duration: 15.0)
        await dateRangeMgr.open(
            id: "splice",
            startDate: refDate,
            customAttributes: scte.dateRangeAttributes()
        )
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            ),
            dateRangeManager: dateRangeMgr
        )
        await injector.queueTrackInfo(title: "News Flash")
        let metadata = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(metadata.dateRanges.contains("SCTE35"))
        #expect(metadata.id3Data != nil)
    }

    // MARK: - PDT Across Interstitial Boundary

    @Test("ProgramDateTime sync across interstitial boundary")
    func pdtAcrossBoundary() async {
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            )
        )
        let m0 = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        let m1 = await injector.metadataForSegment(
            index: 1, duration: 6.0
        )
        #expect(m0.programDateTime != nil)
        #expect(m1.programDateTime != nil)
        #expect(m0.programDateTime != m1.programDateTime)
    }

    // MARK: - Multiple SCTE-35 Events

    @Test("Multiple SCTE-35 events tracked as separate interstitials")
    func multipleSCTE35() async {
        let manager = InterstitialManager()
        for i in 0..<3 {
            let scte = SCTE35Marker.spliceInsert(
                eventId: UInt32(i), duration: 15.0
            )
            await manager.scheduleFromSCTE35(
                scte,
                at: refDate.addingTimeInterval(TimeInterval(i * 600)),
                id: "splice-\(i)",
                assetURI: "https://ads.example.com/ad\(i).m3u8"
            )
        }
        let all = await manager.interstitials
        #expect(all.count == 3)
    }

    // MARK: - Open → Close Ad Break

    @Test("Open ad break → close → DATERANGE has end date")
    func openCloseCycle() async {
        let dateRangeMgr = DateRangeManager()
        let intMgr = InterstitialManager(dateRangeManager: dateRangeMgr)
        await intMgr.scheduleAd(
            id: "mid",
            at: refDate,
            assetURI: "https://ads.example.com/mid.m3u8",
            duration: 30.0
        )
        await intMgr.complete(id: "mid")
        let range = await dateRangeMgr.range(id: "mid")
        #expect(range?.state == .closed)
        #expect(range?.endDate != nil)
    }

    // MARK: - Variable Substitution in Interstitial URIs

    @Test("Variable substitution resolves in interstitial asset URIs")
    func variableSubstitutionInURIs() {
        var resolver = VariableResolver()
        resolver.define(name: "ad_server", value: "ads.example.com")
        resolver.define(name: "campaign", value: "summer2026")
        let uri = resolver.resolve(
            "https://{$ad_server}/campaigns/{$campaign}/ad.m3u8"
        )
        #expect(
            uri
                == "https://ads.example.com/campaigns/summer2026/ad.m3u8"
        )
    }
}
