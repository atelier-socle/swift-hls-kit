// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HLSInterstitial", .timeLimit(.minutes(1)))
struct HLSInterstitialTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    // MARK: - Initialization

    @Test("Init with assetURI → asset is .uri")
    func initWithURI() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        if case .uri(let uri) = ad.asset {
            #expect(uri == "https://ads.example.com/ad.m3u8")
        } else {
            Issue.record("Expected .uri asset")
        }
    }

    @Test("Init with assetListURI → asset is .list")
    func initWithList() {
        let ad = HLSInterstitial(
            id: "pod-1",
            startDate: refDate,
            assetListURI: "https://ads.example.com/pod.json"
        )
        if case .list(let uri) = ad.asset {
            #expect(uri == "https://ads.example.com/pod.json")
        } else {
            Issue.record("Expected .list asset")
        }
    }

    @Test("Restrictions stored correctly")
    func restrictions() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            restrictions: [.jump, .seek]
        )
        #expect(ad.restrictions.contains(.jump))
        #expect(ad.restrictions.contains(.seek))
        #expect(ad.restrictions.count == 2)
    }

    @Test("ResumeMode.liveEdge is default")
    func defaultResumeMode() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        #expect(ad.resumeMode == .liveEdge)
    }

    @Test("ResumeMode.offset stores resumeOffset")
    func resumeOffset() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            resumeMode: .offset(10.0)
        )
        #expect(ad.resumeOffset == 10.0)
    }

    // MARK: - DateRange Conversion

    @Test("toManagedDateRange preserves id and startDate")
    func toManagedDateRangeBasic() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        let managed = ad.toManagedDateRange()
        #expect(managed.id == "ad-1")
        #expect(managed.startDate == refDate)
    }

    @Test("toManagedDateRange includes X-ASSET-URI")
    func toManagedDateRangeURI() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        let managed = ad.toManagedDateRange()
        #expect(
            managed.customAttributes["X-ASSET-URI"]
                == "https://ads.example.com/ad.m3u8"
        )
    }

    @Test("toManagedDateRange includes X-ASSET-LIST for list")
    func toManagedDateRangeList() {
        let ad = HLSInterstitial(
            id: "pod-1",
            startDate: refDate,
            assetListURI: "https://ads.example.com/pod.json"
        )
        let managed = ad.toManagedDateRange()
        #expect(
            managed.customAttributes["X-ASSET-LIST"]
                == "https://ads.example.com/pod.json"
        )
    }

    @Test("toManagedDateRange includes X-RESTRICT with JUMP,SEEK")
    func toManagedDateRangeRestrictions() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            restrictions: [.jump, .seek]
        )
        let managed = ad.toManagedDateRange()
        let restrict = managed.customAttributes["X-RESTRICT"] ?? ""
        #expect(restrict.contains("JUMP"))
        #expect(restrict.contains("SEEK"))
    }

    @Test("toManagedDateRange includes X-RESUME-OFFSET")
    func toManagedDateRangeResumeOffset() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            resumeMode: .offset(10.0)
        )
        let managed = ad.toManagedDateRange()
        #expect(managed.customAttributes["X-RESUME-OFFSET"] == "10.0")
    }

    // MARK: - Rendering

    @Test("renderTag produces valid EXT-X-DATERANGE line")
    func renderTag() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            duration: 30.0,
            restrictions: [.jump, .seek]
        )
        let tag = ad.renderTag()
        #expect(tag.contains("#EXT-X-DATERANGE:"))
        #expect(tag.contains("ID=\"ad-1\""))
        #expect(tag.contains("X-ASSET-URI"))
    }

    // MARK: - WWDC 2025

    @Test("SkipControl: skipAfter in output")
    func skipControl() {
        var ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        ad.skipControl = HLSInterstitial.SkipControl(skipAfter: 5.0)
        let managed = ad.toManagedDateRange()
        #expect(managed.customAttributes["X-SKIP-AFTER"] == "5.0")
    }

    @Test("SkipControl: buttonStart in output")
    func skipButtonStart() {
        var ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        ad.skipControl = HLSInterstitial.SkipControl(
            skipAfter: 5.0, buttonStart: 2.0
        )
        let managed = ad.toManagedDateRange()
        #expect(managed.customAttributes["X-SKIP-BUTTON-START"] == "2.0")
    }

    @Test("PreloadConfig: preloadURI in output")
    func preloadConfig() {
        var ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        ad.preload = HLSInterstitial.PreloadConfig(
            preloadURI: "https://ads.example.com/preload.m3u8"
        )
        let managed = ad.toManagedDateRange()
        #expect(
            managed.customAttributes["X-com.apple.hls.preload"]
                == "https://ads.example.com/preload.m3u8"
        )
    }

    // MARK: - Duration & PlannedDuration

    @Test("Duration in output")
    func durationInOutput() {
        let ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            duration: 30.0
        )
        let tag = ad.renderTag()
        #expect(tag.contains("DURATION"))
    }

    @Test("PlannedDuration in output")
    func plannedDurationInOutput() {
        var ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        ad.plannedDuration = 60.0
        let tag = ad.renderTag()
        #expect(tag.contains("PLANNED-DURATION"))
    }

    // MARK: - SCTE-35

    @Test("SCTE-35 marker in output")
    func scte35InOutput() {
        var ad = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        ad.scte35 = SCTE35Marker.spliceInsert(
            eventId: 42, duration: 30.0, outOfNetwork: true
        )
        let tag = ad.renderTag()
        #expect(tag.contains("SCTE35-OUT"))
    }

    // MARK: - Parsing

    @Test("fromDateRange round-trip")
    func fromDateRangeRoundTrip() {
        var original = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            duration: 30.0,
            restrictions: [.jump, .seek]
        )
        original.skipControl = HLSInterstitial.SkipControl(
            skipAfter: 5.0, buttonStart: 2.0
        )
        let managed = original.toManagedDateRange()
        let parsed = HLSInterstitial.fromDateRange(managed)
        #expect(parsed != nil)
        #expect(parsed?.id == "ad-1")
        #expect(parsed?.restrictions.contains(.jump) == true)
        #expect(parsed?.skipControl?.skipAfter == 5.0)
    }

    @Test("fromDateRange with non-interstitial returns nil")
    func fromDateRangeNonInterstitial() {
        let range = DateRangeManager.ManagedDateRange(
            id: "chapter-1",
            startDate: refDate,
            endDate: nil,
            duration: nil,
            plannedDuration: nil,
            classAttribute: "com.chapter",
            endOnNext: false,
            customAttributes: [:],
            scte35Cmd: nil,
            scte35Out: nil,
            scte35In: nil,
            state: .open
        )
        let result = HLSInterstitial.fromDateRange(range)
        #expect(result == nil)
    }

    // MARK: - SCTE-35 Return (outOfNetwork=false)

    @Test("SCTE-35 return marker produces SCTE35-IN")
    func scte35ReturnInOutput() {
        var ad = HLSInterstitial(
            id: "ad-return",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        ad.scte35 = SCTE35Marker.spliceInsert(
            eventId: 42, outOfNetwork: false
        )
        let managed = ad.toManagedDateRange()
        #expect(managed.scte35In != nil)
        #expect(managed.scte35Out == nil)
    }

    // MARK: - fromDateRange: Asset List Round-Trip

    @Test("fromDateRange with asset list round-trip")
    func fromDateRangeAssetList() {
        let original = HLSInterstitial(
            id: "pod-1",
            startDate: refDate,
            assetListURI: "https://ads.example.com/pod.json",
            duration: 60.0
        )
        let managed = original.toManagedDateRange()
        let parsed = HLSInterstitial.fromDateRange(managed)
        #expect(parsed != nil)
        if case .list(let uri) = parsed?.asset {
            #expect(uri == "https://ads.example.com/pod.json")
        } else {
            Issue.record("Expected .list asset")
        }
    }

    // MARK: - fromDateRange: Resume Offset Round-Trip

    @Test("fromDateRange with resume offset round-trip")
    func fromDateRangeResumeOffset() {
        let original = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8",
            resumeMode: .offset(15.0)
        )
        let managed = original.toManagedDateRange()
        let parsed = HLSInterstitial.fromDateRange(managed)
        #expect(parsed?.resumeOffset == 15.0)
        #expect(parsed?.resumeMode == .offset(15.0))
    }

    // MARK: - fromDateRange: Preload Round-Trip

    @Test("fromDateRange with preload config round-trip")
    func fromDateRangePreload() {
        var original = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        original.preload = HLSInterstitial.PreloadConfig(
            preloadURI: "https://ads.example.com/preload.m3u8",
            preloadAhead: 10.0
        )
        let managed = original.toManagedDateRange()
        let parsed = HLSInterstitial.fromDateRange(managed)
        #expect(parsed?.preload?.preloadURI != nil)
        #expect(parsed?.preload?.preloadAhead == 10.0)
    }

    // MARK: - Equatable

    @Test("Equatable: same interstitials are equal")
    func equatable() {
        let a = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        let b = HLSInterstitial(
            id: "ad-1",
            startDate: refDate,
            assetURI: "https://ads.example.com/ad.m3u8"
        )
        #expect(a == b)
    }
}
