// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Full Pipeline Showcase — Manifest

@Suite("Full Pipeline Showcase — Manifest Round-Trip & Validation")
struct FullPipelineManifestShowcaseTests {

    @Test("Build multivariant manifest with variables, spatial variants, subtitles — round-trip")
    func buildAndParseMultivariantManifest() throws {
        let playlist = buildFullPlaylist()
        let m3u8 = ManifestGenerator().generateMaster(playlist)

        let reparsed = try ManifestParser().parse(m3u8)

        guard case .master(let result) = reparsed else {
            Issue.record("Expected .master manifest after round-trip")
            return
        }
        #expect(result.variants.count == 3)
        #expect(result.renditions.count == 2)
        #expect(result.independentSegments == true)
    }

    @Test("Parse generated manifest — verify definitions, supplementalCodecs, videoLayoutDescriptor")
    func parseGeneratedManifestDetails() throws {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(
                    bandwidth: 15_000_000,
                    resolution: Resolution(width: 3840, height: 2160),
                    uri: "spatial/4k.m3u8",
                    codecs: "hvc1.2.4.L153.B0",
                    supplementalCodecs: "dvh1.20.09/db4h",
                    videoLayoutDescriptor: .immersive180
                )
            ],
            definitions: [
                VariableDefinition(name: "token", value: "abc123")
            ]
        )

        let m3u8 = ManifestGenerator().generateMaster(playlist)
        let result = try ManifestParser().parse(m3u8)

        guard case .master(let parsed) = result else {
            Issue.record("Expected .master manifest")
            return
        }

        #expect(parsed.definitions.count == 1)
        #expect(parsed.definitions[0].name == "token")
        #expect(parsed.definitions[0].value == "abc123")

        #expect(parsed.variants[0].supplementalCodecs == "dvh1.20.09/db4h")

        let layout = parsed.variants[0].videoLayoutDescriptor
        #expect(layout?.channelLayout == .stereoLeftRight)
        #expect(layout?.projection == .halfEquirectangular)
    }

    @Test("Validate generated manifest — verify zero errors")
    func validateGeneratedManifest() throws {
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 10_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "spatial/1080p.m3u8",
                    codecs: "hvc1.2.4.L123.B0",
                    videoLayoutDescriptor: .stereo
                ),
                Variant(
                    bandwidth: 4_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "video/1080p_2d.m3u8",
                    codecs: "avc1.640028,mp4a.40.2"
                )
            ],
            independentSegments: true
        )

        let m3u8 = ManifestGenerator().generateMaster(playlist)
        let report = try HLSValidator().validateString(m3u8)
        #expect(report.errors.isEmpty)
    }

    @Test("Multi-destination health dashboard — RTMP healthy, SRT degraded, Icecast failed")
    func multiDestinationHealthDashboard() {
        let now = Date()

        let rtmpHealth = TransportDestinationHealth(
            label: "Twitch",
            transportType: "RTMP",
            quality: TransportQuality(
                score: 0.95,
                grade: .excellent,
                recommendation: nil,
                timestamp: now
            ),
            connectionState: .connected,
            statistics: TransportStatisticsSnapshot(
                bytesSent: 50_000_000,
                duration: 3600,
                currentBitrate: 4_000_000,
                peakBitrate: 4_500_000,
                reconnectionCount: 0,
                timestamp: now
            )
        )

        let srtHealth = TransportDestinationHealth(
            label: "SRT-Backup",
            transportType: "SRT",
            quality: TransportQuality(
                score: 0.5,
                grade: .fair,
                recommendation: "Reduce bitrate",
                timestamp: now
            ),
            connectionState: .connected,
            statistics: nil
        )

        let icecastHealth = TransportDestinationHealth(
            label: "Icecast",
            transportType: "Icecast",
            quality: nil,
            connectionState: .failed,
            statistics: nil
        )

        let dashboard = TransportHealthDashboard(
            destinations: [rtmpHealth, srtHealth, icecastHealth]
        )

        #expect(dashboard.healthyCount == 1)
        #expect(dashboard.degradedCount == 1)
        #expect(dashboard.failedCount == 1)
        #expect(dashboard.overallGrade == .critical)
        #expect(dashboard.destinations.count == 3)
    }

    // MARK: - Helpers

    private func buildFullPlaylist() -> MasterPlaylist {
        MasterPlaylist(
            version: .v8,
            variants: [
                Variant(
                    bandwidth: 15_000_000,
                    resolution: Resolution(width: 3840, height: 2160),
                    uri: "spatial/4k_dv.m3u8",
                    codecs: "hvc1.2.4.L153.B0",
                    subtitles: "subs",
                    videoRange: .pq,
                    supplementalCodecs: "dvh1.20.09/db4h",
                    videoLayoutDescriptor: .immersive180
                ),
                Variant(
                    bandwidth: 10_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "spatial/1080p.m3u8",
                    codecs: "hvc1.2.4.L123.B0",
                    subtitles: "subs",
                    videoLayoutDescriptor: .stereo
                ),
                Variant(
                    bandwidth: 4_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "video/1080p_2d.m3u8",
                    codecs: "avc1.640028,mp4a.40.2",
                    subtitles: "subs"
                )
            ],
            renditions: [
                Rendition(
                    type: .subtitles,
                    groupId: "subs",
                    name: "English",
                    uri: "subtitles/en.m3u8",
                    language: "en",
                    isDefault: true,
                    autoselect: true,
                    codec: SubtitleCodec.imsc1.rawValue
                ),
                Rendition(
                    type: .subtitles,
                    groupId: "subs",
                    name: "French",
                    uri: "subtitles/fr.m3u8",
                    language: "fr",
                    codec: SubtitleCodec.imsc1.rawValue
                )
            ],
            independentSegments: true,
            definitions: [
                VariableDefinition(name: "cdn", value: "https://cdn.example.com")
            ]
        )
    }
}

// MARK: - Full Pipeline Showcase — Packages & Events

@Suite("Full Pipeline Showcase — Complete Packages & Pipeline Events")
struct FullPipelinePackagesShowcaseTests {

    @Test("Complete Apple Vision Pro package — MV-HEVC init + manifest with stereoscopic + DV")
    func completeVisionProPackage() {
        let packager = MVHEVCPackager()
        let vps = Data([0x40, 0x01, 0x0C, 0x01, 0xFF, 0xFF])
        let sps = buildMinimalSPS()
        let pps = Data([0x44, 0x01, 0xC1, 0x73, 0xD0, 0x89])
        let parameterSets = HEVCParameterSets(
            vps: vps, sps: sps, pps: pps
        )

        let config = SpatialVideoConfiguration.dolbyVisionStereo
        let initSegment = packager.createInitSegment(
            configuration: config,
            parameterSets: parameterSets
        )
        #expect(initSegment.count > 0)

        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 15_000_000,
                    resolution: Resolution(width: 3840, height: 2160),
                    uri: "spatial/4k_dv.m3u8",
                    codecs: config.baseLayerCodec,
                    videoRange: .pq,
                    supplementalCodecs: config.supplementalCodecs,
                    videoLayoutDescriptor: VideoLayoutDescriptor(
                        channelLayout: config.channelLayout
                    )
                )
            ],
            independentSegments: true
        )

        let m3u8 = ManifestGenerator().generateMaster(playlist)
        #expect(m3u8.contains("SUPPLEMENTAL-CODECS=\"dvh1.20.09/db4h\""))
        #expect(m3u8.contains("REQ-VIDEO-LAYOUT=\"CH-STEREO\""))
        #expect(m3u8.contains("VIDEO-RANGE=PQ"))
    }

    @Test("Traditional broadcast package — RTMP config + encryption key")
    func traditionalBroadcastPackage() {
        let rtmpConfig = RTMPPusherConfiguration.twitch(
            streamKey: "live_secret_key_12345"
        )
        #expect(rtmpConfig.serverURL == "rtmps://live.twitch.tv/app")
        #expect(rtmpConfig.streamKey == "live_secret_key_12345")
        #expect(
            rtmpConfig.fullURL
                == "rtmps://live.twitch.tv/app/live_secret_key_12345"
        )

        let key = EncryptionKey(
            method: .aes128,
            uri: "https://keys.example.com/key1"
        )
        let playlist = MediaPlaylist(
            version: .v3,
            targetDuration: 6,
            hasEndList: false,
            segments: [
                Segment(
                    duration: 6.0,
                    uri: "segment001.ts",
                    key: key
                ),
                Segment(
                    duration: 6.0,
                    uri: "segment002.ts",
                    key: key
                )
            ]
        )

        let m3u8 = ManifestGenerator().generateMedia(playlist)
        #expect(m3u8.contains("METHOD=AES-128"))
        #expect(m3u8.contains("URI=\"https://keys.example.com/key1\""))
        #expect(m3u8.contains("segment001.ts"))
    }

    @Test("LivePipelineConfiguration with transportPolicy, spatialVideo preset, subtitles")
    func pipelineConfigurationCombined() {
        var config = LivePipelineConfiguration.spatialVideo(
            channelLayout: .stereoLeftRight,
            dolbyVision: true
        )
        config.subtitlesEnabled = true
        config.transportPolicy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: true,
            minimumQualityGrade: .fair,
            abrResponsiveness: .responsive
        )

        #expect(config.videoEnabled == true)
        #expect(config.subtitlesEnabled == true)
        #expect(config.transportPolicy?.autoAdjustBitrate == true)
        #expect(config.transportPolicy?.minimumQualityGrade == .fair)
        #expect(config.transportPolicy?.abrResponsiveness == .responsive)
        #expect(config.videoBitrate == 15_000_000)

        let validationError = config.validate()
        #expect(validationError == nil)
    }

    @Test("Pipeline event flow — transport quality degrades, recommendation, bitrate adjusted")
    func pipelineEventFlow() {
        let now = Date()

        let degradedQuality = TransportQuality(
            score: 0.4,
            grade: .poor,
            recommendation: "Reduce bitrate to 2 Mbps",
            timestamp: now
        )
        #expect(degradedQuality.grade == .poor)
        #expect(degradedQuality.score == 0.4)

        let recommendation = TransportBitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentEstimatedBitrate: 3_500_000,
            direction: .decrease,
            reason: "Network congestion detected",
            confidence: 0.85,
            timestamp: now
        )
        #expect(recommendation.direction == .decrease)
        #expect(recommendation.recommendedBitrate == 2_000_000)
        #expect(recommendation.confidence == 0.85)

        let policy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: true,
            minimumQualityGrade: .poor,
            abrResponsiveness: .responsive
        )
        #expect(policy.autoAdjustBitrate == true)
        #expect(degradedQuality.grade >= policy.minimumQualityGrade)

        let improvedQuality = TransportQuality(
            score: 0.8,
            grade: .good,
            recommendation: nil,
            timestamp: now
        )
        #expect(improvedQuality.grade == .good)
        #expect(improvedQuality.score > degradedQuality.score)

        let maintainRec = TransportBitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentEstimatedBitrate: 2_500_000,
            direction: .maintain,
            reason: "Conditions stable after adjustment",
            confidence: 0.9,
            timestamp: now
        )
        #expect(maintainRec.direction == .maintain)
    }

    // MARK: - Helpers

    private func buildMinimalSPS() -> Data {
        var sps = Data()
        sps.append(contentsOf: [0x42, 0x01])
        sps.append(0x01)
        sps.append(0x02)
        sps.append(contentsOf: [0x20, 0x00, 0x00, 0x00])
        sps.append(contentsOf: [0x90, 0x00, 0x00, 0x00, 0x00, 0x00])
        sps.append(123)
        return sps
    }
}
