// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Metadata Injection Showcase", .timeLimit(.minutes(1)))
struct MetadataInjectionShowcaseTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    // MARK: - Live Sports Broadcast

    @Test("Sports: SCTE-35 ad insertions at halftime and timeouts")
    func sportsSCTE35() async {
        let manager = InterstitialManager()
        let halftime = SCTE35Marker.spliceInsert(
            eventId: 1, duration: 120.0, outOfNetwork: true
        )
        await manager.scheduleFromSCTE35(
            halftime,
            at: refDate.addingTimeInterval(2700),
            id: "halftime",
            assetURI: "https://ads.example.com/halftime-pod.m3u8"
        )
        let timeout = SCTE35Marker.spliceInsert(
            eventId: 2, duration: 30.0, outOfNetwork: true
        )
        await manager.scheduleFromSCTE35(
            timeout,
            at: refDate.addingTimeInterval(900),
            id: "timeout-1",
            assetURI: "https://ads.example.com/timeout.m3u8"
        )
        let all = await manager.interstitials
        #expect(all.count == 2)
        let output = await manager.renderInterstitials()
        #expect(output.contains("halftime"))
        #expect(output.contains("timeout-1"))
    }

    // MARK: - Streaming Radio

    @Test("Radio: ID3 track metadata + DATERANGE chapters")
    func streamingRadio() async {
        let dateRangeMgr = DateRangeManager()
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            ),
            dateRangeManager: dateRangeMgr
        )
        await dateRangeMgr.open(
            id: "show-1",
            startDate: refDate,
            customAttributes: ["X-SHOW-TITLE": "Morning Drive"]
        )
        await injector.queueTrackInfo(
            title: "Summer Breeze", artist: "Seals & Crofts"
        )
        let m = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(m.id3Data != nil)
        #expect(m.dateRanges.contains("show-1"))
    }

    // MARK: - News Broadcast

    @Test("News: bumper interstitials between segments")
    func newsBumpers() async {
        let manager = InterstitialManager()
        await manager.scheduleBumper(
            id: "bumper-in",
            at: refDate,
            assetURI: "https://cdn.example.com/bumper-in.m3u8",
            duration: 3.0
        )
        await manager.scheduleBumper(
            id: "bumper-out",
            at: refDate.addingTimeInterval(1800),
            assetURI: "https://cdn.example.com/bumper-out.m3u8",
            duration: 3.0
        )
        let all = await manager.interstitials
        #expect(all.count == 2)
        for bumper in all {
            #expect(bumper.restrictions.contains(.jump))
            #expect(bumper.restrictions.contains(.seek))
        }
    }

    // MARK: - Ad Pod

    @Test("Ad pod: asset list with multiple ads")
    func adPod() async {
        let manager = InterstitialManager()
        await manager.scheduleFromSCTE35(
            SCTE35Marker.spliceInsert(eventId: 10, duration: 60.0),
            at: refDate,
            id: "pod-1",
            assetListURI: "https://ads.example.com/pod.json"
        )
        let ad = await manager.interstitial(id: "pod-1")
        #expect(ad != nil)
        if case .list(let uri) = ad?.asset {
            #expect(uri == "https://ads.example.com/pod.json")
        } else {
            Issue.record("Expected .list asset")
        }
    }

    // MARK: - WWDC 2025 Skip Button

    @Test("Skip button: ad with skip available after 5 seconds")
    func skipButton() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "skippable-ad",
            at: refDate,
            assetURI: "https://ads.example.com/skippable.m3u8",
            duration: 30.0,
            skipControl: HLSInterstitial.SkipControl(
                skipAfter: 5.0, buttonStart: 0.0
            )
        )
        let ad = await manager.interstitial(id: "skippable-ad")
        #expect(ad?.skipControl?.skipAfter == 5.0)
        #expect(ad?.skipControl?.buttonStart == 0.0)
    }

    // MARK: - WWDC 2025 Preload

    @Test("Preload: interstitial with preload hint")
    func preloadHint() async {
        let manager = InterstitialManager()
        await manager.scheduleAd(
            id: "preload-ad",
            at: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            preload: HLSInterstitial.PreloadConfig(
                preloadURI: "https://ads.example.com/preload.m3u8",
                preloadAhead: 10.0
            )
        )
        let ad = await manager.interstitial(id: "preload-ad")
        #expect(ad?.preload?.preloadURI != nil)
        #expect(ad?.preload?.preloadAhead == 10.0)
    }

    // MARK: - Server-Side Ad Insertion

    @Test("SSAI: splice_insert → ad break → splice return")
    func serverSideAdInsertion() async {
        let dateRangeMgr = DateRangeManager()
        let spliceOut = SCTE35Marker.spliceInsert(
            eventId: 50, duration: 30.0, outOfNetwork: true
        )
        await dateRangeMgr.open(
            id: "ssai-out",
            startDate: refDate,
            class: "com.example.ad",
            customAttributes: spliceOut.dateRangeAttributes()
        )
        let outRange = await dateRangeMgr.range(id: "ssai-out")
        #expect(outRange?.customAttributes["SCTE35-OUT"] != nil)
        let spliceIn = SCTE35Marker.spliceInsert(
            eventId: 50, outOfNetwork: false
        )
        #expect(spliceIn.dateRangeAttributes()["SCTE35-IN"] != nil)
    }

    // MARK: - Dynamic Ad Insertion

    @Test("DAI: mid-roll SCTE-35 → interstitial with asset list")
    func dynamicAdInsertion() async {
        let manager = InterstitialManager()
        let scte = SCTE35Marker.spliceInsert(
            eventId: 77, duration: 45.0
        )
        await manager.scheduleFromSCTE35(
            scte,
            at: refDate.addingTimeInterval(1200),
            id: "dai-midroll",
            assetListURI: "https://dai.example.com/assets.json"
        )
        let ad = await manager.interstitial(id: "dai-midroll")
        #expect(ad?.scte35?.eventId == 77)
        if case .list = ad?.asset {
            // correct
        } else {
            Issue.record("Expected .list asset")
        }
    }

    // MARK: - Conference Live Stream

    @Test("Conference: DATERANGE chapters + PDT every segment")
    func conferenceLiveStream() async {
        let dateRangeMgr = DateRangeManager()
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            ),
            dateRangeManager: dateRangeMgr
        )
        await dateRangeMgr.open(
            id: "keynote",
            startDate: refDate,
            customAttributes: ["X-TITLE": "Keynote"]
        )
        var results = [LiveMetadataInjector.SegmentMetadata]()
        for i in 0..<5 {
            let m = await injector.metadataForSegment(
                index: i, duration: 6.0
            )
            results.append(m)
        }
        #expect(results.allSatisfy { $0.programDateTime != nil })
        #expect(results[0].dateRanges.contains("keynote"))
    }

    // MARK: - Podcast Live Recording

    @Test("Podcast: ID3 metadata with title/artist + chapters")
    func podcastLiveRecording() async {
        let dateRangeMgr = DateRangeManager()
        let injector = LiveMetadataInjector(
            dateTimeSync: ProgramDateTimeSync(
                streamStartDate: refDate,
                interval: .everySegment
            ),
            dateRangeManager: dateRangeMgr
        )
        await dateRangeMgr.open(
            id: "ch-1",
            startDate: refDate,
            customAttributes: ["X-CHAPTER": "Introduction"]
        )
        await injector.queueTrackInfo(
            title: "Podcast Live Ep.100", artist: "The Host"
        )
        let m = await injector.metadataForSegment(
            index: 0, duration: 6.0
        )
        #expect(m.id3Data != nil)
        #expect(m.dateRanges.contains("ch-1"))
    }

    // MARK: - SCTE-35 Binary Round-Trip

    @Test("SCTE-35 binary round-trip: create → serialize → hex → parse")
    func scte35RoundTrip() {
        let original = SCTE35Marker.spliceInsert(
            eventId: 12345, duration: 30.0, outOfNetwork: true
        )
        let hex = original.serializeHex()
        let parsed = SCTE35Marker.parseHex(hex)
        #expect(parsed != nil)
        #expect(parsed?.eventId == 12345)
        #expect(parsed?.outOfNetwork == true)
        let seconds = parsed?.breakDuration?.seconds ?? 0
        #expect(abs(seconds - 30.0) < 0.001)
    }

    // MARK: - Multi-Ad-Break

    @Test("Multi-ad-break: 3 SCTE-35 events during 1 hour stream")
    func multiAdBreak() async {
        let manager = InterstitialManager()
        for i in 0..<3 {
            let scte = SCTE35Marker.spliceInsert(
                eventId: UInt32(i + 1), duration: 30.0
            )
            await manager.scheduleFromSCTE35(
                scte,
                at: refDate.addingTimeInterval(TimeInterval(i + 1) * 900),
                id: "break-\(i + 1)",
                assetURI: "https://ads.example.com/ad\(i + 1).m3u8"
            )
        }
        let all = await manager.interstitials
        #expect(all.count == 3)
        await manager.complete(id: "break-1")
        let active = await manager.activeInterstitials
        #expect(active.count == 2)
    }

    // MARK: - Restrictions

    @Test("Restrictions: JUMP prevents skip, SEEK prevents seek")
    func restrictionsVerify() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            restrictions: [.jump, .seek]
        )
        let tag = ad.renderTag()
        #expect(tag.contains("X-RESTRICT"))
        #expect(tag.contains("JUMP"))
        #expect(tag.contains("SEEK"))
    }

    // MARK: - Zero-Duration Cue

    @Test("Zero-duration interstitial: cue point only")
    func zeroDurationCue() {
        var cue = HLSInterstitial(
            id: "cue-1", startDate: refDate, assetURI: ""
        )
        cue.isCue = true
        cue.duration = 0
        let managed = cue.toManagedDateRange()
        #expect(managed.duration == 0)
        #expect(managed.id == "cue-1")
    }
}
