// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Video Projection Showcase

@Suite("Video Projection Showcase — Layout Descriptors & Projection Specifiers")
struct ProjectionShowcaseTests {

    // MARK: - VideoProjection Cases

    @Test("VideoProjection raw values — all five projection types")
    func videoProjectionRawValues() {
        #expect(VideoProjection.rectilinear.rawValue == "PROJ-RECT")
        #expect(VideoProjection.equirectangular.rawValue == "PROJ-EQUI")
        #expect(VideoProjection.halfEquirectangular.rawValue == "PROJ-HEQU")
        #expect(VideoProjection.primary.rawValue == "PROJ-PRIM")
        #expect(VideoProjection.appleImmersiveVideo.rawValue == "PROJ-AIV")

        #expect(VideoProjection.allCases.count == 5)
    }

    // MARK: - VideoLayoutDescriptor Presets

    @Test("VideoLayoutDescriptor presets — stereo, mono, video360, immersive180, appleImmersive")
    func videoLayoutPresets() {
        let stereo = VideoLayoutDescriptor.stereo
        #expect(stereo.channelLayout == .stereoLeftRight)
        #expect(stereo.projection == nil)
        #expect(stereo.attributeValue == "CH-STEREO")

        let mono = VideoLayoutDescriptor.mono
        #expect(mono.channelLayout == .mono)
        #expect(mono.projection == nil)
        #expect(mono.attributeValue == "CH-MONO")

        let video360 = VideoLayoutDescriptor.video360
        #expect(video360.channelLayout == nil)
        #expect(video360.projection == .equirectangular)
        #expect(video360.attributeValue == "PROJ-EQUI")

        let immersive180 = VideoLayoutDescriptor.immersive180
        #expect(immersive180.channelLayout == .stereoLeftRight)
        #expect(immersive180.projection == .halfEquirectangular)
        #expect(immersive180.attributeValue == "CH-STEREO,PROJ-HEQU")

        let appleImmersive = VideoLayoutDescriptor.appleImmersive
        #expect(appleImmersive.channelLayout == .stereoLeftRight)
        #expect(appleImmersive.projection == .appleImmersiveVideo)
        #expect(appleImmersive.attributeValue == "CH-STEREO,PROJ-AIV")
    }

    // MARK: - Parsing

    @Test("VideoLayoutDescriptor.parse — combined channel layout and projection")
    func parseLayoutDescriptor() {
        let stereoHequ = VideoLayoutDescriptor.parse("CH-STEREO,PROJ-HEQU")
        #expect(stereoHequ.channelLayout == .stereoLeftRight)
        #expect(stereoHequ.projection == .halfEquirectangular)

        let stereoOnly = VideoLayoutDescriptor.parse("CH-STEREO")
        #expect(stereoOnly.channelLayout == .stereoLeftRight)
        #expect(stereoOnly.projection == nil)

        let projOnly = VideoLayoutDescriptor.parse("PROJ-EQUI")
        #expect(projOnly.channelLayout == nil)
        #expect(projOnly.projection == .equirectangular)

        let aiv = VideoLayoutDescriptor.parse("CH-STEREO,PROJ-AIV")
        #expect(aiv.channelLayout == .stereoLeftRight)
        #expect(aiv.projection == .appleImmersiveVideo)
    }

    @Test("VideoLayoutDescriptor.attributeValue — verify round-trip string format")
    func attributeValueRoundTrip() {
        let descriptor = VideoLayoutDescriptor(
            channelLayout: .stereoLeftRight,
            projection: .halfEquirectangular
        )
        let attributeValue = descriptor.attributeValue
        #expect(attributeValue == "CH-STEREO,PROJ-HEQU")

        let reparsed = VideoLayoutDescriptor.parse(attributeValue)
        #expect(reparsed == descriptor)
    }

    // MARK: - Manifest Integration

    @Test("Parse manifest with REQ-VIDEO-LAYOUT — verify variant.videoLayoutDescriptor")
    func parseManifestWithVideoLayout() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-STREAM-INF:BANDWIDTH=10000000,\
            CODECS="hvc1.2.4.L123.B0",\
            RESOLUTION=1920x1080,\
            REQ-VIDEO-LAYOUT="CH-STEREO"
            spatial/1080p_stereo.m3u8
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }
        #expect(playlist.variants.count == 1)

        let layout = playlist.variants[0].videoLayoutDescriptor
        #expect(layout?.channelLayout == .stereoLeftRight)
    }

    @Test("Full Vision Pro manifest — stereo + supplemental codecs + projection")
    func fullVisionProManifest() {
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 15_000_000,
                    resolution: Resolution(width: 3840, height: 2160),
                    uri: "spatial/4k_dv.m3u8",
                    codecs: "hvc1.2.4.L153.B0",
                    videoRange: .pq,
                    supplementalCodecs: "dvh1.20.09/db4h",
                    videoLayoutDescriptor: .immersive180
                ),
                Variant(
                    bandwidth: 10_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "spatial/1080p_stereo.m3u8",
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

        let generator = ManifestGenerator()
        let output = generator.generateMaster(playlist)

        // Verify spatial variant attributes
        #expect(output.contains("SUPPLEMENTAL-CODECS=\"dvh1.20.09/db4h\""))
        #expect(output.contains("REQ-VIDEO-LAYOUT=\"CH-STEREO,PROJ-HEQU\""))
        #expect(output.contains("VIDEO-RANGE=PQ"))

        // Verify stereo variant
        #expect(output.contains("REQ-VIDEO-LAYOUT=\"CH-STEREO\""))

        // Verify 2D fallback exists
        #expect(output.contains("video/1080p_2d.m3u8"))

        // Verify it is a valid playlist
        #expect(output.contains("#EXTM3U"))
        #expect(output.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
    }
}
