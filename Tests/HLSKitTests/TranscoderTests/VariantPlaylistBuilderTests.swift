// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("VariantPlaylistBuilder")
struct VariantPlaylistBuilderTests {

    // MARK: - Build from Presets

    @Test("Build master playlist from presets")
    func buildFromPresets() {
        let builder = VariantPlaylistBuilder()
        let m3u8 = builder.buildMasterPlaylist(
            presets: QualityPreset.standardLadder,
            videoCodec: .h264,
            config: TranscodingConfig()
        )
        #expect(m3u8.contains("#EXTM3U"))
        #expect(
            m3u8.contains("#EXT-X-STREAM-INF:")
        )
    }

    @Test("Playlist is parseable by ManifestParser")
    func parseable() throws {
        let builder = VariantPlaylistBuilder()
        let m3u8 = builder.buildMasterPlaylist(
            presets: [.p720, .p1080],
            videoCodec: .h264,
            config: TranscodingConfig()
        )
        let manifest = try ManifestParser().parse(m3u8)
        guard case .master(let master) = manifest else {
            #expect(
                Bool(false), "Expected master playlist"
            )
            return
        }
        #expect(master.variants.count == 2)
    }

    @Test("Variants in bandwidth-ascending order")
    func bandwidthOrder() throws {
        let builder = VariantPlaylistBuilder()
        let m3u8 = builder.buildMasterPlaylist(
            presets: [.p1080, .p360, .p720],
            videoCodec: .h264,
            config: TranscodingConfig()
        )
        let manifest = try ManifestParser().parse(m3u8)
        guard case .master(let master) = manifest else {
            #expect(
                Bool(false), "Expected master playlist"
            )
            return
        }
        let bandwidths = master.variants.map(\.bandwidth)
        #expect(bandwidths == bandwidths.sorted())
    }

    @Test("Each variant has CODECS and BANDWIDTH")
    func variantAttributes() throws {
        let builder = VariantPlaylistBuilder()
        let m3u8 = builder.buildMasterPlaylist(
            presets: [.p720],
            videoCodec: .h264,
            config: TranscodingConfig()
        )
        let manifest = try ManifestParser().parse(m3u8)
        guard case .master(let master) = manifest else {
            #expect(
                Bool(false), "Expected master playlist"
            )
            return
        }
        let variant = try #require(master.variants.first)
        #expect(variant.bandwidth > 0)
        #expect(variant.codecs != nil)
        #expect(variant.resolution != nil)
    }

    @Test("Each variant has RESOLUTION")
    func variantResolution() throws {
        let builder = VariantPlaylistBuilder()
        let m3u8 = builder.buildMasterPlaylist(
            presets: [.p1080],
            videoCodec: .h264,
            config: TranscodingConfig()
        )
        let manifest = try ManifestParser().parse(m3u8)
        guard case .master(let master) = manifest else {
            #expect(
                Bool(false), "Expected master playlist"
            )
            return
        }
        let variant = try #require(master.variants.first)
        #expect(variant.resolution == .p1080)
    }

    @Test("Audio-only variant has no resolution")
    func audioOnlyVariant() throws {
        let builder = VariantPlaylistBuilder()
        let m3u8 = builder.buildMasterPlaylist(
            presets: [.audioOnly, .p720],
            videoCodec: .h264,
            config: TranscodingConfig()
        )
        let manifest = try ManifestParser().parse(m3u8)
        guard case .master(let master) = manifest else {
            #expect(
                Bool(false), "Expected master playlist"
            )
            return
        }
        let audioVariant = master.variants.first {
            $0.resolution == nil
        }
        #expect(audioVariant != nil)
    }

    @Test("H.265 codec strings")
    func h265CodecStrings() throws {
        let builder = VariantPlaylistBuilder()
        let m3u8 = builder.buildMasterPlaylist(
            presets: [.p720],
            videoCodec: .h265,
            config: TranscodingConfig()
        )
        #expect(m3u8.contains("hvc1."))
    }

    // MARK: - Build from Results

    @Test("Build from transcoding results")
    func buildFromResults() {
        let builder = VariantPlaylistBuilder()
        let results = [
            TranscodingResult(
                preset: .p720,
                outputDirectory: URL(
                    fileURLWithPath: "/out/720p"
                ),
                transcodingDuration: 5.0,
                sourceDuration: 30.0,
                outputSize: 10_000_000
            ),
            TranscodingResult(
                preset: .p1080,
                outputDirectory: URL(
                    fileURLWithPath: "/out/1080p"
                ),
                transcodingDuration: 8.0,
                sourceDuration: 30.0,
                outputSize: 20_000_000
            )
        ]
        let config = TranscodingConfig()
        let m3u8 = builder.buildMasterPlaylist(
            variants: results, config: config
        )
        #expect(m3u8.contains("#EXTM3U"))
        #expect(
            m3u8.contains("720p/playlist.m3u8")
        )
        #expect(
            m3u8.contains("1080p/playlist.m3u8")
        )
    }

    @Test("Master playlist has independent segments")
    func independentSegments() {
        let builder = VariantPlaylistBuilder()
        let m3u8 = builder.buildMasterPlaylist(
            presets: [.p720],
            videoCodec: .h264,
            config: TranscodingConfig()
        )
        #expect(
            m3u8.contains("#EXT-X-INDEPENDENT-SEGMENTS")
        )
    }
}
