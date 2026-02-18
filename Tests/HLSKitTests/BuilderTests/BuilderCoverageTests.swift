// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - MasterPlaylistBuilder Coverage

@Suite("MasterPlaylistBuilder — Coverage")
struct MasterPlaylistBuilderCoverageTests {

    @Test("buildOptional — some value")
    func buildOptionalSome() {
        let includeAudio = true
        let playlist = MasterPlaylist {
            Variant(bandwidth: 800_000, uri: "v.m3u8")
            if includeAudio {
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "English", uri: "en.m3u8"
                )
            }
        }
        #expect(playlist.renditions.count == 1)
    }

    @Test("buildOptional — nil value")
    func buildOptionalNil() {
        let includeAudio = false
        let playlist = MasterPlaylist {
            Variant(bandwidth: 800_000, uri: "v.m3u8")
            if includeAudio {
                Rendition(
                    type: .audio, groupId: "audio",
                    name: "English", uri: "en.m3u8"
                )
            }
        }
        #expect(playlist.renditions.isEmpty)
    }

    @Test("buildEither — first branch")
    func buildEitherFirst() {
        let useHighRes = true
        let playlist = MasterPlaylist {
            if useHighRes {
                Variant(
                    bandwidth: 5_000_000,
                    resolution: .p1080,
                    uri: "1080.m3u8"
                )
            } else {
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480.m3u8"
                )
            }
        }
        #expect(playlist.variants[0].bandwidth == 5_000_000)
    }

    @Test("buildEither — second branch")
    func buildEitherSecond() {
        let useHighRes = false
        let playlist = MasterPlaylist {
            if useHighRes {
                Variant(
                    bandwidth: 5_000_000,
                    resolution: .p1080,
                    uri: "1080.m3u8"
                )
            } else {
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480.m3u8"
                )
            }
        }
        #expect(playlist.variants[0].bandwidth == 800_000)
    }

    @Test("buildArray — for loop")
    func buildArray() {
        let bandwidths = [800_000, 2_800_000, 5_000_000]
        let playlist = MasterPlaylist {
            for bw in bandwidths {
                Variant(bandwidth: bw, uri: "\(bw).m3u8")
            }
        }
        #expect(playlist.variants.count == 3)
    }

    @Test("Builder with IFrameVariant")
    func builderIFrameVariant() {
        let playlist = MasterPlaylist {
            Variant(bandwidth: 800_000, uri: "v.m3u8")
            IFrameVariant(
                bandwidth: 200_000, uri: "iframe.m3u8"
            )
        }
        #expect(playlist.iFrameVariants.count == 1)
    }

    @Test("Builder with SessionData")
    func builderSessionData() {
        let playlist = MasterPlaylist {
            Variant(bandwidth: 800_000, uri: "v.m3u8")
            SessionData(
                dataId: "com.example.title",
                value: "Title"
            )
        }
        #expect(playlist.sessionData.count == 1)
    }

    @Test("Builder with ContentSteering")
    func builderContentSteering() {
        let playlist = MasterPlaylist {
            Variant(bandwidth: 800_000, uri: "v.m3u8")
            ContentSteering(
                serverUri: "https://example.com/steering"
            )
        }
        #expect(playlist.contentSteering != nil)
    }

    @Test("Builder empty content")
    func builderEmpty() {
        let playlist = MasterPlaylist {}
        #expect(playlist.variants.isEmpty)
    }
}

// MARK: - MediaPlaylistBuilder Coverage

@Suite("MediaPlaylistBuilder — Coverage")
struct MediaPlaylistBuilderCoverageTests {

    @Test("buildOptional — some value")
    func buildOptionalSome() {
        let includeExtra = true
        let playlist = MediaPlaylist(targetDuration: 6) {
            Segment(duration: 6.006, uri: "seg1.ts")
            if includeExtra {
                Segment(duration: 5.5, uri: "seg2.ts")
            }
        }
        #expect(playlist.segments.count == 2)
    }

    @Test("buildOptional — nil value")
    func buildOptionalNil() {
        let includeExtra = false
        let playlist = MediaPlaylist(targetDuration: 6) {
            Segment(duration: 6.006, uri: "seg1.ts")
            if includeExtra {
                Segment(duration: 5.5, uri: "seg2.ts")
            }
        }
        #expect(playlist.segments.count == 1)
    }

    @Test("buildEither — first branch")
    func buildEitherFirst() {
        let useLong = true
        let playlist = MediaPlaylist(targetDuration: 10) {
            if useLong {
                Segment(duration: 10.0, uri: "long.ts")
            } else {
                Segment(duration: 4.0, uri: "short.ts")
            }
        }
        #expect(playlist.segments[0].duration == 10.0)
    }

    @Test("buildEither — second branch")
    func buildEitherSecond() {
        let useLong = false
        let playlist = MediaPlaylist(targetDuration: 10) {
            if useLong {
                Segment(duration: 10.0, uri: "long.ts")
            } else {
                Segment(duration: 4.0, uri: "short.ts")
            }
        }
        #expect(playlist.segments[0].duration == 4.0)
    }

    @Test("buildArray — for loop")
    func buildArray() {
        let uris = ["seg1.ts", "seg2.ts", "seg3.ts"]
        let playlist = MediaPlaylist(targetDuration: 6) {
            for uri in uris {
                Segment(duration: 6.006, uri: uri)
            }
        }
        #expect(playlist.segments.count == 3)
    }

    @Test("Builder with DateRange")
    func builderDateRange() {
        let date = Date(timeIntervalSince1970: 1_771_322_430)
        let playlist = MediaPlaylist(targetDuration: 6) {
            Segment(duration: 6.006, uri: "seg.ts")
            DateRange(id: "ad", startDate: date, duration: 30.0)
        }
        #expect(playlist.dateRanges.count == 1)
        #expect(playlist.segments.count == 1)
    }

    @Test("Builder with version parameter")
    func builderWithVersion() {
        let playlist = MediaPlaylist(
            targetDuration: 6, version: .v7
        ) {
            Segment(duration: 6.006, uri: "seg.ts")
        }
        #expect(playlist.version == .v7)
    }

    @Test("Builder empty content")
    func builderEmpty() {
        let playlist = MediaPlaylist(targetDuration: 6) {}
        #expect(playlist.segments.isEmpty)
    }
}
