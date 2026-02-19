// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Variant Tests

@Suite("Variant Model")
struct VariantTests {

    @Test("Variant with all fields")
    func fullVariant() {
        let variant = Variant(
            bandwidth: 2_800_000,
            resolution: .p720,
            uri: "720p/playlist.m3u8",
            averageBandwidth: 2_500_000,
            codecs: "avc1.4d401f,mp4a.40.2",
            frameRate: 30.0,
            hdcpLevel: HDCPLevel.none,
            audio: "audio-group",
            video: "video-group",
            subtitles: "subs",
            closedCaptions: .groupId("cc")
        )

        #expect(variant.bandwidth == 2_800_000)
        #expect(variant.resolution == .p720)
        #expect(variant.uri == "720p/playlist.m3u8")
        #expect(variant.averageBandwidth == 2_500_000)
        #expect(variant.codecs == "avc1.4d401f,mp4a.40.2")
        #expect(variant.frameRate == 30.0)
        #expect(variant.hdcpLevel == HDCPLevel.none)
        #expect(variant.audio == "audio-group")
    }

    @Test("Variant with minimal fields")
    func minimalVariant() {
        let variant = Variant(bandwidth: 800_000, uri: "480p/playlist.m3u8")
        #expect(variant.bandwidth == 800_000)
        #expect(variant.uri == "480p/playlist.m3u8")
        #expect(variant.resolution == nil)
        #expect(variant.codecs == nil)
    }
}

// MARK: - Rendition Tests

@Suite("Rendition Model")
struct RenditionTests {

    @Test("Audio rendition with all fields")
    func audioRendition() {
        let rendition = Rendition(
            type: .audio,
            groupId: "audio-en",
            name: "English",
            uri: "audio/en/playlist.m3u8",
            language: "en",
            isDefault: true,
            autoselect: true,
            channels: "2"
        )

        #expect(rendition.type == .audio)
        #expect(rendition.groupId == "audio-en")
        #expect(rendition.name == "English")
        #expect(rendition.language == "en")
        #expect(rendition.isDefault == true)
        #expect(rendition.autoselect == true)
        #expect(rendition.channels == "2")
    }
}

// MARK: - MasterPlaylist Tests

@Suite("MasterPlaylist Model")
struct MasterPlaylistTests {

    @Test("MasterPlaylist with variants")
    func masterWithVariants() {
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(bandwidth: 800_000, resolution: .p480, uri: "480p/playlist.m3u8"),
                Variant(bandwidth: 2_800_000, resolution: .p720, uri: "720p/playlist.m3u8"),
                Variant(bandwidth: 5_000_000, resolution: .p1080, uri: "1080p/playlist.m3u8")
            ],
            independentSegments: true
        )

        #expect(playlist.version == .v7)
        #expect(playlist.variants.count == 3)
        #expect(playlist.independentSegments == true)
    }

    @Test("Empty master playlist")
    func emptyMaster() {
        let playlist = MasterPlaylist()
        #expect(playlist.variants.isEmpty)
        #expect(playlist.renditions.isEmpty)
        #expect(playlist.sessionData.isEmpty)
        #expect(playlist.version == nil)
    }
}

// MARK: - MediaPlaylist Tests

@Suite("MediaPlaylist Model")
struct MediaPlaylistTests {

    @Test("MediaPlaylist with segments")
    func mediaWithSegments() {
        let playlist = MediaPlaylist(
            version: .v3,
            targetDuration: 10,
            playlistType: .vod,
            hasEndList: true,
            segments: [
                Segment(duration: 9.009, uri: "segment001.ts"),
                Segment(duration: 9.009, uri: "segment002.ts"),
                Segment(duration: 3.003, uri: "segment003.ts")
            ]
        )

        #expect(playlist.version == .v3)
        #expect(playlist.targetDuration == 10)
        #expect(playlist.playlistType == .vod)
        #expect(playlist.hasEndList == true)
        #expect(playlist.segments.count == 3)
    }

    @Test("Default media playlist values")
    func defaultValues() {
        let playlist = MediaPlaylist()
        #expect(playlist.targetDuration == 10)
        #expect(playlist.mediaSequence == 0)
        #expect(playlist.discontinuitySequence == 0)
        #expect(playlist.playlistType == nil)
        #expect(playlist.hasEndList == false)
        #expect(playlist.segments.isEmpty)
    }
}

// MARK: - DateRange Tests

@Suite("DateRange Model")
struct DateRangeTests {

    @Test("DateRange with all fields")
    func fullDateRange() {
        let now = Date()
        let dateRange = DateRange(
            id: "ad-break-1",
            startDate: now,
            classAttribute: "com.example.ad",
            duration: 30.0,
            plannedDuration: 30.0,
            clientAttributes: ["X-COM-EXAMPLE-AD-ID": "12345"]
        )

        #expect(dateRange.id == "ad-break-1")
        #expect(dateRange.startDate == now)
        #expect(dateRange.classAttribute == "com.example.ad")
        #expect(dateRange.duration == 30.0)
        #expect(dateRange.clientAttributes["X-COM-EXAMPLE-AD-ID"] == "12345")
    }
}

// MARK: - SessionData Tests

@Suite("SessionData Model")
struct SessionDataTests {

    @Test("SessionData with inline value")
    func inlineValue() {
        let data = SessionData(
            dataId: "com.example.title",
            value: "My Podcast",
            language: "en"
        )

        #expect(data.dataId == "com.example.title")
        #expect(data.value == "My Podcast")
        #expect(data.uri == nil)
        #expect(data.language == "en")
    }

    @Test("SessionData with URI")
    func uriValue() {
        let data = SessionData(
            dataId: "com.example.metadata",
            uri: "metadata.json"
        )

        #expect(data.value == nil)
        #expect(data.uri == "metadata.json")
    }
}

// MARK: - ContentSteering Tests

@Suite("ContentSteering Model")
struct ContentSteeringTests {

    @Test("ContentSteering with pathway")
    func withPathway() {
        let steering = ContentSteering(
            serverUri: "https://cdn.example.com/steering",
            pathwayId: "CDN-A"
        )

        #expect(steering.serverUri == "https://cdn.example.com/steering")
        #expect(steering.pathwayId == "CDN-A")
    }
}

// MARK: - HDCPLevel Tests

@Suite("HDCPLevel Enum")
struct HDCPLevelTests {

    @Test("All HDCP levels have correct raw values")
    func rawValues() {
        #expect(HDCPLevel.type0.rawValue == "TYPE-0")
        #expect(HDCPLevel.type1.rawValue == "TYPE-1")
        #expect(HDCPLevel.none.rawValue == "NONE")
    }

    @Test("HDCPLevel has 3 cases")
    func allCases() {
        #expect(HDCPLevel.allCases.count == 3)
    }
}

// MARK: - ClosedCaptionsValue Tests

@Suite("ClosedCaptionsValue Enum")
struct ClosedCaptionsValueTests {

    @Test("ClosedCaptionsValue group ID")
    func groupId() {
        let value = ClosedCaptionsValue.groupId("cc")
        if case .groupId(let id) = value {
            #expect(id == "cc")
        } else {
            Issue.record("Expected groupId case")
        }
    }

    @Test("ClosedCaptionsValue none")
    func noneCase() {
        let value = ClosedCaptionsValue.none
        if case .none = value {
            // Pass
        } else {
            Issue.record("Expected none case")
        }
    }
}
