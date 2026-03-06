// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("VideoLayout Parsing & Generation")
struct VideoLayoutParsingTests {

    // MARK: - Parsing

    @Test("Parse manifest with REQ-VIDEO-LAYOUT CH-STEREO")
    func parseStereoLayout() throws {
        let parser = TagParser()
        let attributes = """
            BANDWIDTH=8000000,RESOLUTION=1920x1080,\
            REQ-VIDEO-LAYOUT="CH-STEREO"
            """
        let variant = try parser.parseStreamInf(attributes)
        #expect(variant.videoLayoutDescriptor != nil)
        #expect(
            variant.videoLayoutDescriptor?.channelLayout == .stereoLeftRight
        )
        #expect(variant.videoLayoutDescriptor?.projection == nil)
    }

    @Test("Parse manifest with REQ-VIDEO-LAYOUT CH-STEREO,PROJ-HEQU")
    func parseStereoHequLayout() throws {
        let parser = TagParser()
        let attributes = """
            BANDWIDTH=12000000,RESOLUTION=3840x2160,\
            REQ-VIDEO-LAYOUT="CH-STEREO,PROJ-HEQU"
            """
        let variant = try parser.parseStreamInf(attributes)
        #expect(
            variant.videoLayoutDescriptor?.channelLayout == .stereoLeftRight
        )
        #expect(
            variant.videoLayoutDescriptor?.projection == .halfEquirectangular
        )
    }

    @Test("Parse manifest without REQ-VIDEO-LAYOUT returns nil")
    func parseWithoutLayout() throws {
        let parser = TagParser()
        let attributes = "BANDWIDTH=2000000,RESOLUTION=1920x1080"
        let variant = try parser.parseStreamInf(attributes)
        #expect(variant.videoLayoutDescriptor == nil)
    }

    // MARK: - Generation

    @Test("Generate manifest with videoLayoutDescriptor emits REQ-VIDEO-LAYOUT")
    func generateWithLayout() {
        let writer = TagWriter()
        let variant = Variant(
            bandwidth: 8_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "stereo/playlist.m3u8",
            videoLayoutDescriptor: .immersive180
        )
        let output = writer.writeStreamInf(variant)
        #expect(output.contains("REQ-VIDEO-LAYOUT=\"CH-STEREO,PROJ-HEQU\""))
    }

    // MARK: - Round-trip

    @Test("Round-trip: parse -> generate -> parse with REQ-VIDEO-LAYOUT")
    func roundTrip() throws {
        let parser = TagParser()
        let writer = TagWriter()

        let original = """
            BANDWIDTH=10000000,RESOLUTION=3840x2160,\
            REQ-VIDEO-LAYOUT="CH-STEREO,PROJ-AIV"
            """
        let variant1 = try parser.parseStreamInf(original)
        var fullVariant = variant1
        fullVariant.uri = "immersive/playlist.m3u8"

        let generated = writer.writeStreamInf(fullVariant)
        #expect(generated.contains("REQ-VIDEO-LAYOUT=\"CH-STEREO,PROJ-AIV\""))

        let attrPart = generated.replacingOccurrences(
            of: "#EXT-X-STREAM-INF:", with: ""
        )
        let variant2 = try parser.parseStreamInf(attrPart)
        #expect(variant2.videoLayoutDescriptor == variant1.videoLayoutDescriptor)
    }
}
