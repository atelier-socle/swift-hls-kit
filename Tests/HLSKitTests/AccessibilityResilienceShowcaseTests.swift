// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - Accessibility & Resilience Showcase

@Suite("Accessibility & Resilience — Showcase")
struct AccessibilityResilienceShowcaseTests {

    @Test("US broadcast: CEA-708 English + Spanish captions")
    func usBroadcastCaptions() {
        let config = ClosedCaptionConfig.englishSpanish708
        let generator = AccessibilityRenditionGenerator()
        let entries = generator.generateCaptionEntries(config: config)

        #expect(entries.count == 2)
        #expect(entries[0].tag.contains("INSTREAM-ID=\"SERVICE1\""))
        #expect(entries[0].tag.contains("LANGUAGE=\"en\""))
        #expect(entries[1].tag.contains("INSTREAM-ID=\"SERVICE2\""))
        #expect(entries[1].tag.contains("LANGUAGE=\"es\""))

        let errors = config.validate()
        #expect(errors.isEmpty)
    }

    @Test("International stream: WebVTT subtitles in 5 languages")
    func internationalSubtitles() {
        let languages = [
            ("en", "English"), ("fr", "French"), ("de", "German"),
            ("es", "Spanish"), ("ja", "Japanese")
        ]
        let playlists = languages.map { lang, name in
            (
                playlist: LiveSubtitlePlaylist(language: lang, name: name),
                uri: "subs/\(lang).m3u8"
            )
        }
        let generator = AccessibilityRenditionGenerator()
        let entries = generator.generateSubtitleEntries(playlists: playlists)

        #expect(entries.count == 5)
        #expect(entries[0].tag.contains("DEFAULT=YES"))
        for i in 1..<entries.count {
            #expect(entries[i].tag.contains("DEFAULT=NO"))
        }
    }

    @Test("Accessible podcast: audio description + forced subtitles")
    func accessiblePodcast() {
        let adConfig = AudioDescriptionConfig.english
        let subtitlePlaylist = LiveSubtitlePlaylist(
            language: "en", name: "Forced English", forced: true
        )

        let generator = AccessibilityRenditionGenerator()
        let entries = generator.generateAll(
            subtitles: [(playlist: subtitlePlaylist, uri: "subs/forced_en.m3u8")],
            audioDescriptions: [(config: adConfig, uri: "audio/ad/en.m3u8")]
        )

        let subtitleEntries = entries.filter { $0.type == .subtitles }
        let adEntries = entries.filter { $0.type == .audioDescription }
        #expect(subtitleEntries.count == 1)
        #expect(subtitleEntries[0].tag.contains("FORCED=YES"))
        #expect(adEntries.count == 1)
        #expect(adEntries[0].tag.contains("public.accessibility.describes-video"))
    }

    @Test("Multi-CDN failover: primary + 2 backups per variant")
    func multiCDNFailover() {
        let config = RedundantStreamConfig(backups: [
            .init(
                primaryURI: "https://cdn-a.com/1080p.m3u8",
                backupURIs: [
                    "https://cdn-b.com/1080p.m3u8",
                    "https://cdn-c.com/1080p.m3u8"
                ]
            ),
            .init(
                primaryURI: "https://cdn-a.com/720p.m3u8",
                backupURIs: [
                    "https://cdn-b.com/720p.m3u8",
                    "https://cdn-c.com/720p.m3u8"
                ]
            )
        ])

        #expect(config.totalBackupURIs == 4)
        #expect(config.validate().isEmpty)

        var manager = FailoverManager(config: config)
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        #expect(
            manager.activeURI(for: "https://cdn-a.com/1080p.m3u8")
                == "https://cdn-b.com/1080p.m3u8"
        )

        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        #expect(
            manager.activeURI(for: "https://cdn-a.com/1080p.m3u8")
                == "https://cdn-c.com/1080p.m3u8"
        )
    }

    @Test("Content steering: dynamic CDN switching with JSON manifest")
    func contentSteering() {
        let config = ContentSteeringConfig(
            serverURI: "https://steering.example.com/manifest",
            pathways: ["CDN-A", "CDN-B", "CDN-C"],
            defaultPathway: "CDN-A",
            pollingInterval: 15
        )

        let tag = config.steeringTag()
        #expect(tag.contains("SERVER-URI=\"https://steering.example.com/manifest\""))
        #expect(tag.contains("PATHWAY-ID=\"CDN-A\""))

        let manifest = config.steeringManifest(
            pathwayPriority: ["CDN-B", "CDN-A", "CDN-C"]
        )
        #expect(manifest.contains("\"VERSION\":1"))
        #expect(manifest.contains("\"TTL\":15"))
        #expect(manifest.contains("\"CDN-B\""))

        #expect(config.validate().isEmpty)
    }

    @Test("Gap signaling: 3 consecutive gaps trigger alert")
    func gapSignaling() {
        var handler = GapHandler(maxConsecutiveGaps: 3)
        handler.markGap(at: 10)
        handler.markGap(at: 11)
        #expect(!handler.hasConsecutiveGapAlert(currentIndex: 11))

        handler.markGap(at: 12)
        #expect(handler.hasConsecutiveGapAlert(currentIndex: 12))

        var segments = (0..<15).map { Segment(duration: 6, uri: "seg_\($0).ts") }
        handler.applyToSegments(&segments)
        #expect(segments[10].isGap)
        #expect(segments[11].isGap)
        #expect(segments[12].isGap)
        #expect(!segments[9].isGap)
    }

    @Test("Session data: stream metadata for UI display")
    func sessionData() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.title", value: "Live Concert 2026"),
            .init(dataID: "com.example.artist", value: "The Band"),
            .init(
                dataID: "com.example.title",
                value: "Concert en direct 2026",
                language: "fr"
            )
        ])

        let tags = config.generateTags()
        #expect(tags.count == 3)
        #expect(tags[0].contains("\"Live Concert 2026\""))
        #expect(tags[2].contains("LANGUAGE=\"fr\""))
    }

    @Test("Complete accessibility: captions + subtitles + audio description")
    func completeAccessibility() {
        let generator = AccessibilityRenditionGenerator()
        let subtitleEN = LiveSubtitlePlaylist(language: "en", name: "English")
        let subtitleFR = LiveSubtitlePlaylist(language: "fr", name: "French")

        let entries = generator.generateAll(
            captions: .broadcast708,
            subtitles: [
                (playlist: subtitleEN, uri: "subs/en.m3u8"),
                (playlist: subtitleFR, uri: "subs/fr.m3u8")
            ],
            audioDescriptions: [
                (config: .english, uri: "ad/en.m3u8"),
                (config: .french, uri: "ad/fr.m3u8")
            ]
        )

        let captions = entries.filter { $0.type == .closedCaptions }
        let subs = entries.filter { $0.type == .subtitles }
        let ads = entries.filter { $0.type == .audioDescription }
        #expect(captions.count == 3)
        #expect(subs.count == 2)
        #expect(ads.count == 2)
        #expect(entries.count == 7)
    }

    @Test("Resilient live stream: redundancy + steering + gap handling")
    func resilientLiveStream() {
        let redundant = RedundantStreamConfig(backups: [
            .init(
                primaryURI: "https://cdn-a.com/live.m3u8",
                backupURIs: ["https://cdn-b.com/live.m3u8"]
            )
        ])

        let steering = ContentSteeringConfig(
            serverURI: "https://steering.example.com/live",
            pathways: ["CDN-A", "CDN-B"],
            defaultPathway: "CDN-A"
        )

        var gapHandler = GapHandler(maxConsecutiveGaps: 5)
        gapHandler.markGap(at: 100)

        #expect(redundant.validate().isEmpty)
        #expect(steering.validate().isEmpty)
        #expect(gapHandler.gapCount == 1)

        var manager = FailoverManager(config: redundant)
        manager.reportFailure(for: "https://cdn-a.com/live.m3u8")
        #expect(
            manager.activeURI(for: "https://cdn-a.com/live.m3u8")
                == "https://cdn-b.com/live.m3u8"
        )

        let steeringTag = steering.steeringTag()
        #expect(steeringTag.contains("CONTENT-STEERING"))
    }

    @Test("Round-trip: config → generate → validate → render")
    func roundTrip() async {
        let captionConfig = ClosedCaptionConfig.broadcast708
        #expect(captionConfig.validate().isEmpty)

        let generator = AccessibilityRenditionGenerator()
        let captionEntries = generator.generateCaptionEntries(config: captionConfig)
        #expect(captionEntries.count == 3)

        let writer = LiveWebVTTWriter(segmentDuration: 6.0)
        await writer.addCue(WebVTTCue(startTime: 0.5, endTime: 3.0, text: "Welcome"))
        await writer.addCue(WebVTTCue(startTime: 3.5, endTime: 5.5, text: "to the show"))
        let vtt = await writer.renderSegment()
        #expect(vtt.hasPrefix("WEBVTT\n"))
        #expect(vtt.contains("Welcome"))
        #expect(vtt.contains("to the show"))

        var playlist = LiveSubtitlePlaylist(language: "en", name: "English")
        playlist.addSegment(uri: "sub_0.vtt", duration: 6.0)
        let m3u8 = playlist.render()
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("sub_0.vtt"))

        let validationErrors = generator.validateVariantCaptions(
            closedCaptionsAttr: "cc",
            config: captionConfig
        )
        #expect(validationErrors.isEmpty)
    }
}
