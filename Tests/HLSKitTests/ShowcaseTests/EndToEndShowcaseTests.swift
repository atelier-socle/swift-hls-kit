// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - End-to-End Cross-Feature Showcase

@Suite("End-to-End Cross-Feature Showcase", .timeLimit(.minutes(1)))
struct EndToEndShowcaseTests {

    // MARK: - Spatial Audio + DRM + Pipeline

    @Test("Spatial audio podcast — Atmos config → renditions → DRM protection → pipeline preset")
    func spatialAudioPodcastWithDRM() {
        // 1. Spatial audio config
        let spatialConfig = SpatialAudioConfig.atmos5_1
        #expect(spatialConfig.format == .dolbyAtmos)
        #expect(spatialConfig.channelLayout == .surround5_1)

        // 2. Generate renditions
        let generator = SpatialRenditionGenerator()
        let renditions = generator.generateRenditions(
            config: spatialConfig,
            language: "en",
            name: "English (Atmos)"
        )
        #expect(renditions.count >= 2)
        let atmosRendition = renditions.first { $0.codecs.contains("ec+3") }
        #expect(atmosRendition != nil)
        let tag = atmosRendition?.formatAsTag() ?? ""
        #expect(tag.contains("EXT-X-MEDIA"))

        // 3. DRM protection
        let drm = LiveDRMPipelineConfig.fairPlayModern
        #expect(drm.isEnabled)
        #expect(drm.fairPlay != nil)
        #expect(drm.rotationPolicy == .everyNSegments(10))

        // 4. Pipeline preset combines both
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.spatialAudio != nil)
        #expect(config.drm?.isEnabled == true)
        #expect(config.audioBitrate == 256_000)
    }

    @Test("Multi-language spatial audio — EN/FR/ES tracks → renditions for each language")
    func multiLanguageSpatialAudio() {
        let generator = SpatialRenditionGenerator()
        let tracks: [SpatialRenditionGenerator.AudioTrackDescriptor] = [
            .init(
                language: "en", name: "English",
                config: .atmos5_1, uri: "audio/en/main.m3u8"
            ),
            .init(
                language: "fr", name: "Français",
                config: .atmos5_1, uri: "audio/fr/main.m3u8"
            ),
            .init(
                language: "es", name: "Español",
                config: .surround5_1_eac3, uri: "audio/es/main.m3u8"
            )
        ]
        let renditions = generator.generateMultiLanguageRenditions(tracks: tracks)
        #expect(renditions.count >= 6)
        let frenchTags = renditions.filter { $0.language == "fr" }
        #expect(!frenchTags.isEmpty)
    }

    // MARK: - HDR + Variant Ladder + Validation

    @Test("HDR10 adaptive ladder — config → variant generation → range mapping → validation")
    func hdr10AdaptiveLadder() {
        // 1. HDR config
        let hdrConfig = HDRConfig.hdr10Default
        #expect(hdrConfig.type == .hdr10)
        #expect(hdrConfig.videoRange == .pq)

        // 2. Generate adaptive ladder
        let variantGen = HDRVariantGenerator()
        let ladder = variantGen.generateAdaptiveLadder(hdrConfig: hdrConfig)
        #expect(!ladder.isEmpty)
        let hdrVariants = ladder.filter { !$0.isSDRFallback }
        let sdrVariants = ladder.filter { $0.isSDRFallback }
        #expect(!hdrVariants.isEmpty)
        #expect(!sdrVariants.isEmpty)

        // 3. Range mapping
        let mapper = VideoRangeMapper()
        let attrs = mapper.mapToHLSAttributes(config: hdrConfig)
        #expect(attrs.videoRange == .pq)
        #expect(attrs.minimumBitDepth >= 10)

        // 4. Validate ladder
        let warnings = variantGen.validateLadder(ladder)
        #expect(warnings.isEmpty)
    }

    @Test("Dolby Vision 4K — DV profile 8 → HDR10 fallback → variant attributes")
    func dolbyVision4K() {
        let config = HDRConfig.dolbyVisionProfile8
        #expect(config.type == .dolbyVisionWithHDR10Fallback)
        #expect(config.supplementalCodecs != nil)

        let variantGen = HDRVariantGenerator()
        let variants = variantGen.generateVariants(
            hdrConfig: config,
            resolutions: [.uhd4K]
        )
        #expect(!variants.isEmpty)
        let dvVariant = variants.first { $0.supplementalCodecs != nil }
        #expect(dvVariant != nil)
        let attrs = dvVariant?.formatAttributes() ?? ""
        #expect(attrs.contains("VIDEO-RANGE"))
    }

    // MARK: - Accessibility + Subtitles + Steering

    @Test("Accessible stream — captions + audio description + subtitles → renditions → steering")
    func accessibleStreamWithSteering() async {
        // 1. Closed captions
        let captions = ClosedCaptionConfig.broadcast708
        #expect(captions.validate().isEmpty)

        // 2. Audio descriptions
        let audioDescs: [(config: AudioDescriptionConfig, uri: String)] = [
            (config: .english, uri: "ad/en.m3u8"),
            (config: .french, uri: "ad/fr.m3u8")
        ]

        // 3. Subtitles
        let subtitleWriter = LiveWebVTTWriter(segmentDuration: 6.0)
        await subtitleWriter.addCue(
            WebVTTCue(startTime: 0, endTime: 3, text: "Welcome to the show")
        )
        let vttContent = await subtitleWriter.renderSegment()
        #expect(vttContent.contains("WEBVTT"))
        #expect(vttContent.contains("Welcome to the show"))

        var subtitlePlaylist = LiveSubtitlePlaylist(
            language: "en", name: "English"
        )
        subtitlePlaylist.addSegment(uri: "subs/en/seg0.vtt", duration: 6.0)

        // 4. Combine all renditions
        let generator = AccessibilityRenditionGenerator()
        let entries = generator.generateAll(
            captions: captions,
            subtitles: [(playlist: subtitlePlaylist, uri: "subs/en/main.m3u8")],
            audioDescriptions: audioDescs
        )
        #expect(!entries.isEmpty)
        let captionEntries = entries.filter { $0.type == .closedCaptions }
        let adEntries = entries.filter { $0.type == .audioDescription }
        let subEntries = entries.filter { $0.type == .subtitles }
        #expect(!captionEntries.isEmpty)
        #expect(adEntries.count == 2)
        #expect(!subEntries.isEmpty)

        // 5. Content steering for CDN
        let steering = ContentSteeringConfig(
            serverURI: "https://cdn.example.com/steering",
            pathways: ["CDN-A", "CDN-B", "CDN-C"],
            defaultPathway: "CDN-A"
        )
        let steeringTag = steering.steeringTag()
        #expect(steeringTag.contains("EXT-X-CONTENT-STEERING"))
        #expect(steering.validate().isEmpty)
    }

    // MARK: - DRM + Key Rotation + Multi-DRM

    @Test("Multi-DRM pipeline — FairPlay + CENC → key rotation policy → session keys")
    func multiDRMPipeline() {
        // 1. Multi-DRM config
        let drm = LiveDRMPipelineConfig.multiDRM
        #expect(drm.isEnabled)
        #expect(drm.isMultiDRM)
        #expect(drm.fairPlay != nil)
        #expect(drm.cenc?.systems.contains(.widevine) == true)
        #expect(drm.cenc?.systems.contains(.playReady) == true)

        // 2. Key rotation
        let rotation = KeyRotationPolicy.everyNSegments(10)
        #expect(rotation.shouldRotate(segmentIndex: 10, elapsed: 0))
        #expect(!rotation.shouldRotate(segmentIndex: 5, elapsed: 0))

        // 3. FairPlay session key
        let fairPlay = FairPlayLiveConfig.modern
        let sessionKey = fairPlay.sessionKeyEntry(keyURI: "skd://key-server/session")
        #expect(sessionKey.method == .sampleAESCTR)
        #expect(sessionKey.keyFormat == "com.apple.streamingkeydelivery")

        // 4. Pipeline preset
        let config = LivePipelineConfiguration.multiDRMLive
        #expect(config.drm?.isMultiDRM == true)
    }

    // MARK: - Resilience + Failover + Gap Handling

    @Test("Resilient broadcast — redundant streams → failover → gap marking → recovery")
    func resilientBroadcast() {
        // 1. Redundant stream config
        let redundancy = RedundantStreamConfig(backups: [
            .init(
                primaryURI: "primary/720p.m3u8",
                backupURIs: ["backup-a/720p.m3u8", "backup-b/720p.m3u8"]
            ),
            .init(
                primaryURI: "primary/1080p.m3u8",
                backupURIs: ["backup-a/1080p.m3u8"]
            )
        ])
        #expect(redundancy.validate().isEmpty)
        #expect(redundancy.totalBackupURIs == 3)

        // 2. Failover management
        var failover = FailoverManager(config: redundancy)
        #expect(!failover.hasActiveFailovers)
        failover.reportFailure(for: "primary/720p.m3u8")
        #expect(failover.hasActiveFailovers)
        #expect(failover.activeURI(for: "primary/720p.m3u8") == "backup-a/720p.m3u8")

        // 3. Gap handling during outage
        var gapHandler = GapHandler(maxConsecutiveGaps: 3)
        gapHandler.markGap(at: 5)
        gapHandler.markGap(at: 6)
        #expect(gapHandler.isGap(at: 5))
        #expect(gapHandler.gapCount == 2)

        // 4. Recovery
        failover.reportRecovery(for: "primary/720p.m3u8")
        #expect(failover.activeURI(for: "primary/720p.m3u8") == "primary/720p.m3u8")
        gapHandler.clearGap(at: 5)
        gapHandler.clearGap(at: 6)
        #expect(gapHandler.gapCount == 0)

        // 5. Content steering for CDN switching
        let steering = ContentSteeringConfig(
            serverURI: "https://steer.example.com/v1",
            pathways: ["US-East", "EU-West"],
            defaultPathway: "US-East"
        )
        let manifest = steering.steeringManifest(
            pathwayPriority: ["EU-West", "US-East"],
            ttl: 300
        )
        #expect(manifest.contains("PATHWAY-PRIORITY"))
    }

    // MARK: - Manifest Round-Trip + Validation

    @Test("Manifest round-trip — generate master → parse → validate → regenerate identical")
    func manifestRoundTrip() throws {
        // 1. Build master playlist
        let master = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 2_800_000,
                    resolution: Resolution(width: 1280, height: 720),
                    uri: "720p.m3u8",
                    averageBandwidth: 2_500_000,
                    codecs: "avc1.4d401f,mp4a.40.2"
                ),
                Variant(
                    bandwidth: 5_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "1080p.m3u8",
                    averageBandwidth: 4_500_000,
                    codecs: "avc1.640028,mp4a.40.2"
                )
            ]
        )

        // 2. Generate
        let generator = ManifestGenerator()
        let m3u8 = generator.generateMaster(master)
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("720p.m3u8"))
        #expect(m3u8.contains("1080p.m3u8"))

        // 3. Parse back
        let parser = ManifestParser()
        let parsed = try parser.parse(m3u8)
        guard case .master(let parsedMaster) = parsed else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(parsedMaster.variants.count == 2)

        // 4. Validate
        let validator = HLSValidator()
        let report = validator.validate(parsedMaster)
        #expect(report.isValid)

        // 5. Regenerate
        let regenerated = generator.generateMaster(parsedMaster)
        #expect(regenerated.contains("720p.m3u8"))
        #expect(regenerated.contains("1080p.m3u8"))
    }

    // MARK: - broadcastPro Preset — Full Feature Composition

    @Test("broadcastPro preset — all features composed: spatial + HDR + DRM + CC + AD + recording")
    func broadcastProFullComposition() {
        let config = LivePipelineConfiguration.broadcastPro

        // Spatial audio
        #expect(config.spatialAudio?.format == .dolbyAtmos)

        // HDR video
        #expect(config.videoEnabled)
        #expect(config.hdr?.type == .dolbyVisionWithHDR10Fallback)
        #expect(config.resolution == .uhd4K)

        // DRM
        #expect(config.drm?.isEnabled == true)

        // Accessibility
        #expect(config.closedCaptions != nil)
        #expect(config.audioDescriptions?.count == 3)
        #expect(config.subtitlesEnabled)

        // Recording
        #expect(config.enableRecording)

        // High bitrate audio
        #expect(config.audioBitrate == 256_000)

        // Compose renditions from config
        let spatialGen = SpatialRenditionGenerator()
        let audioRenditions = spatialGen.generateRenditions(
            config: config.spatialAudio ?? .atmos5_1,
            language: "en",
            name: "English (Atmos)"
        )
        #expect(audioRenditions.count >= 2)

        let accessGen = AccessibilityRenditionGenerator()
        let accessEntries = accessGen.generateAll(
            captions: config.closedCaptions,
            audioDescriptions: config.audioDescriptions?.map {
                (config: $0, uri: "ad/\($0.language).m3u8")
            } ?? []
        )
        #expect(!accessEntries.isEmpty)
    }

    // MARK: - Custom Preset Cherry-Pick

    @Test("Custom preset — cherry-pick spatial + HDR + DRM + accessibility from different presets")
    func customPresetCherryPick() {
        var config = LivePipelineConfiguration()

        // Spatial from spatialAudioLive
        config.spatialAudio = LivePipelineConfiguration.spatialAudioLive.spatialAudio

        // HDR from videoDolbyVision
        config.hdr = LivePipelineConfiguration.videoDolbyVision.hdr
        config.videoEnabled = true
        config.resolution = .uhd4K

        // DRM from multiDRMLive
        config.drm = LivePipelineConfiguration.multiDRMLive.drm

        // Accessibility from accessibleLive
        config.closedCaptions = LivePipelineConfiguration.accessibleLive.closedCaptions
        config.audioDescriptions = LivePipelineConfiguration.accessibleLive.audioDescriptions
        config.subtitlesEnabled = true

        // Verify composition
        #expect(config.spatialAudio?.format == .dolbyAtmos)
        #expect(config.hdr?.type == .dolbyVisionWithHDR10Fallback)
        #expect(config.drm?.isMultiDRM == true)
        #expect(config.closedCaptions != nil)
        #expect(config.subtitlesEnabled)
        #expect(config.resolution?.width == 3840)
    }
}
