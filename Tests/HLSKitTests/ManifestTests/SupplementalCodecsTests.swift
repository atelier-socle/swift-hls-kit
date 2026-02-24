// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SUPPLEMENTAL-CODECS")
struct SupplementalCodecsTests {

    // MARK: - Variant Property

    @Test("Variant: supplementalCodecs property exists")
    func variantSupplementalCodecsProperty() {
        let variant = Variant(
            bandwidth: 8_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "dolby/playlist.m3u8",
            supplementalCodecs: "dvh1.05.06"
        )
        #expect(variant.supplementalCodecs == "dvh1.05.06")
    }

    @Test("Variant: supplementalCodecs nil by default")
    func variantSupplementalCodecsNilDefault() {
        let variant = Variant(
            bandwidth: 2_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "video/playlist.m3u8"
        )
        #expect(variant.supplementalCodecs == nil)
    }

    // MARK: - Common Codec Strings

    @Test("Dolby Vision Profile 5 codec string")
    func dolbyVisionProfile5() {
        let codecString = "dvh1.05.06"
        let variant = Variant(
            bandwidth: 8_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "dv/playlist.m3u8",
            supplementalCodecs: codecString
        )
        #expect(variant.supplementalCodecs?.starts(with: "dvh1") == true)
    }

    @Test("Dolby Vision Profile 8 codec string")
    func dolbyVisionProfile8() {
        let codecString = "dvh1.08.06"
        let variant = Variant(
            bandwidth: 10_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "dv8/playlist.m3u8",
            supplementalCodecs: codecString
        )
        #expect(variant.supplementalCodecs?.contains("08") == true)
    }

    // MARK: - Combined with VIDEO-RANGE

    @Test("Variant: both videoRange and supplementalCodecs")
    func combinedVideoRangeAndSupplemental() {
        let variant = Variant(
            bandwidth: 12_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "hdr-dv/playlist.m3u8",
            videoRange: .pq,
            supplementalCodecs: "dvh1.05.06"
        )
        #expect(variant.videoRange == .pq)
        #expect(variant.supplementalCodecs == "dvh1.05.06")
    }

    // MARK: - Parsing Integration

    @Test("TagParser: parses SUPPLEMENTAL-CODECS from EXT-X-STREAM-INF")
    func parseSupplementalCodecs() throws {
        let parser = TagParser()
        let attributes = """
            BANDWIDTH=8000000,RESOLUTION=3840x2160,CODECS="hvc1.2.4.L150.90",\
            VIDEO-RANGE=PQ,SUPPLEMENTAL-CODECS="dvh1.05.06"
            """
        let variant = try parser.parseStreamInf(attributes)
        #expect(variant.supplementalCodecs == "dvh1.05.06")
    }

    @Test("TagParser: SUPPLEMENTAL-CODECS absent returns nil")
    func parseWithoutSupplementalCodecs() throws {
        let parser = TagParser()
        let attributes = "BANDWIDTH=2000000,RESOLUTION=1920x1080"
        let variant = try parser.parseStreamInf(attributes)
        #expect(variant.supplementalCodecs == nil)
    }

    // MARK: - Generation Integration

    @Test("TagWriter: writes SUPPLEMENTAL-CODECS")
    func writeSupplementalCodecs() {
        let writer = TagWriter()
        let variant = Variant(
            bandwidth: 8_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "dv/playlist.m3u8",
            supplementalCodecs: "dvh1.05.06"
        )
        let output = writer.writeStreamInf(variant)
        #expect(output.contains("SUPPLEMENTAL-CODECS=\"dvh1.05.06\""))
    }

    @Test("TagWriter: omits SUPPLEMENTAL-CODECS when nil")
    func writeWithoutSupplementalCodecs() {
        let writer = TagWriter()
        let variant = Variant(
            bandwidth: 2_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "video/playlist.m3u8"
        )
        let output = writer.writeStreamInf(variant)
        #expect(!output.contains("SUPPLEMENTAL-CODECS"))
    }
}
