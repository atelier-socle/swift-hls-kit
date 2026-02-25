// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("InterstitialManager", .timeLimit(.minutes(1)))
struct InterstitialManagerTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    // MARK: - Scheduling

    @Test("scheduleAd adds interstitial")
    func scheduleAd() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            duration: 30.0
        )
        let all = await manager.interstitials
        #expect(all.count == 1)
        #expect(all.first?.id == "ad-1")
    }

    @Test("scheduleAd with skipControl stores skip attributes")
    func scheduleAdWithSkip() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            skipControl: HLSInterstitial.SkipControl(skipAfter: 5.0)
        )
        let ad = await manager.interstitial(id: "ad-1")
        #expect(ad?.skipControl?.skipAfter == 5.0)
    }

    @Test("scheduleAd with preload stores preload config")
    func scheduleAdWithPreload() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            preload: HLSInterstitial.PreloadConfig(
                preloadURI: "https://ads.example.com/preload.m3u8"
            )
        )
        let ad = await manager.interstitial(id: "ad-1")
        #expect(ad?.preload?.preloadURI != nil)
    }

    @Test("scheduleFromSCTE35 creates interstitial with SCTE-35")
    func scheduleFromSCTE35() async {
        let marker = SCTE35Marker.spliceInsert(
            eventId: 42, duration: 30.0
        )
        let manager = InterstitialManager()
        await manager.scheduleFromSCTE35(
            marker,
            at: refDate,
            id: "mid-42",
            assetURI: "https://ads.example.com/mid.m3u8"
        )
        let ad = await manager.interstitial(id: "mid-42")
        #expect(ad != nil)
        #expect(ad?.scte35?.eventId == 42)
    }

    @Test("scheduleBumper creates non-skippable interstitial")
    func scheduleBumper() async {
        let manager = InterstitialManager()
        await manager.scheduleBumper(
            id: "bumper-1",
            at: refDate,
            assetURI: "https://cdn.example.com/bumper.m3u8",
            duration: 5.0
        )
        let bumper = await manager.interstitial(id: "bumper-1")
        #expect(bumper != nil)
        #expect(bumper?.restrictions.contains(.jump) == true)
        #expect(bumper?.restrictions.contains(.seek) == true)
        #expect(bumper?.duration == 5.0)
    }

    // MARK: - Completion & Cancellation

    @Test("complete moves to completedInterstitials")
    func completeAd() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        await manager.complete(id: "ad-1")
        let completed = await manager.completedInterstitials
        #expect(completed.count == 1)
        let active = await manager.activeInterstitials
        #expect(active.isEmpty)
    }

    @Test("cancel removes from interstitials")
    func cancelAd() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        await manager.cancel(id: "ad-1")
        let all = await manager.interstitials
        #expect(all.isEmpty)
    }

    // MARK: - Query

    @Test("interstitial(id:) returns correct one")
    func queryById() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        let result = await manager.interstitial(id: "ad-1")
        #expect(result?.id == "ad-1")
    }

    @Test("interstitial(id:) unknown returns nil")
    func queryUnknown() async {
        let manager = InterstitialManager()
        let result = await manager.interstitial(id: "nope")
        #expect(result == nil)
    }

    @Test("upcoming(after:) filters by date")
    func upcomingAfter() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "past",
            at: refDate,
            assetURI: "https://ads.example.com/past.m3u8"
        )
        await manager.scheduleAd(
            id: "future",
            at: refDate.addingTimeInterval(3600),
            assetURI: "https://ads.example.com/future.m3u8"
        )
        let upcoming = await manager.upcoming(
            after: refDate.addingTimeInterval(1800)
        )
        #expect(upcoming.count == 1)
        #expect(upcoming.first?.id == "future")
    }

    // MARK: - Rendering

    @Test("renderInterstitials produces valid M3U8 DATERANGE lines")
    func renderInterstitials() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            duration: 30.0
        )
        let output = await manager.renderInterstitials()
        #expect(output.contains("#EXT-X-DATERANGE:"))
        #expect(output.contains("ad-1"))
    }

    @Test("activeInterstitials filters started but not completed")
    func activeFilter() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/a.m3u8"
        )
        await manager.scheduleAd(
            id: "ad-2",
            at: refDate,
            assetURI: "https://ads.example.com/b.m3u8"
        )
        await manager.complete(id: "ad-1")
        let active = await manager.activeInterstitials
        #expect(active.count == 1)
        #expect(active.first?.id == "ad-2")
    }

    @Test("Multiple interstitials tracked independently")
    func multipleIndependent() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "pre",
            at: refDate,
            assetURI: "https://ads.example.com/pre.m3u8"
        )
        await manager.scheduleAd(
            id: "mid",
            at: refDate.addingTimeInterval(1800),
            assetURI: "https://ads.example.com/mid.m3u8"
        )
        let all = await manager.interstitials
        #expect(all.count == 2)
    }

    // MARK: - Reset

    @Test("reset clears all state")
    func reset() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        await manager.reset()
        let all = await manager.interstitials
        #expect(all.isEmpty)
        let completed = await manager.completedInterstitials
        #expect(completed.isEmpty)
    }

    // MARK: - DateRangeManager Integration

    @Test("Integration: interstitials sync with DateRangeManager")
    func dateRangeSync() async {
        let dateRangeMgr = DateRangeManager()
        let manager = InterstitialManager(
            dateRangeManager: dateRangeMgr
        )
        await manager.scheduleAd(
            id: "ad-1",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        let range = await dateRangeMgr.range(id: "ad-1")
        #expect(range != nil)
        #expect(range?.state == .open)
    }
}
