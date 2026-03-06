// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("Rendition Codec Wiring")
struct RenditionCodecTests {

    // MARK: - Model

    @Test("Rendition codec property defaults to nil")
    func codecDefaultNil() {
        let rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "English"
        )
        #expect(rendition.codec == nil)
    }

    @Test("Rendition codec set via init")
    func codecViaInit() {
        let rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "English",
            codec: SubtitleCodec.imsc1.rawValue
        )
        #expect(rendition.codec == "stpp.ttml.im1t")
    }

    @Test("subtitleCodec getter returns matching enum")
    func subtitleCodecGetter() {
        var rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "EN"
        )
        rendition.codec = "wvtt"
        #expect(rendition.subtitleCodec == .webvtt)
    }

    @Test("subtitleCodec getter returns nil for unknown codec")
    func subtitleCodecGetterUnknown() {
        var rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "EN"
        )
        rendition.codec = "unknown-codec"
        #expect(rendition.subtitleCodec == nil)
    }

    @Test("subtitleCodec setter updates codec string")
    func subtitleCodecSetter() {
        var rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "EN"
        )
        rendition.subtitleCodec = .imsc1
        #expect(rendition.codec == "stpp.ttml.im1t")
    }

    @Test("subtitleCodec setter clears codec when nil")
    func subtitleCodecSetterNil() {
        var rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "EN",
            codec: "wvtt"
        )
        rendition.subtitleCodec = nil
        #expect(rendition.codec == nil)
    }

    // MARK: - Parser

    @Test("Parse EXT-X-MEDIA with CODECS attribute")
    func parseMediaWithCodecs() throws {
        let parser = TagParser()
        let attrs = """
            TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",\
            LANGUAGE="en",URI="subs/en.m3u8",\
            CODECS="stpp.ttml.im1t"
            """
        let rendition = try parser.parseMedia(attrs)
        #expect(rendition.codec == "stpp.ttml.im1t")
        #expect(rendition.subtitleCodec == .imsc1)
    }

    @Test("Parse EXT-X-MEDIA without CODECS returns nil codec")
    func parseMediaWithoutCodecs() throws {
        let parser = TagParser()
        let attrs = """
            TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",\
            URI="subs/en.m3u8"
            """
        let rendition = try parser.parseMedia(attrs)
        #expect(rendition.codec == nil)
    }

    // MARK: - Generator

    @Test("Generate EXT-X-MEDIA emits CODECS when set")
    func generateMediaWithCodecs() {
        let writer = TagWriter()
        let rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "English",
            uri: "subs/en.m3u8",
            codec: "stpp.ttml.im1t"
        )
        let output = writer.writeMedia(rendition)
        #expect(output.contains("CODECS=\"stpp.ttml.im1t\""))
    }

    @Test("Generate EXT-X-MEDIA omits CODECS when nil")
    func generateMediaWithoutCodecs() {
        let writer = TagWriter()
        let rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "English",
            uri: "subs/en.m3u8"
        )
        let output = writer.writeMedia(rendition)
        #expect(!output.contains("CODECS"))
    }

    // MARK: - Round-trip

    @Test("Round-trip: parse -> generate -> parse with CODECS")
    func roundTrip() throws {
        let parser = TagParser()
        let writer = TagWriter()
        let attrs = """
            TYPE=SUBTITLES,GROUP-ID="subs",NAME="EN",\
            CODECS="stpp.ttml.im1t",URI="subs/en.m3u8"
            """
        let rendition1 = try parser.parseMedia(attrs)
        let generated = writer.writeMedia(rendition1)
        let attrPart = generated.replacingOccurrences(
            of: "#EXT-X-MEDIA:", with: ""
        )
        let rendition2 = try parser.parseMedia(attrPart)
        #expect(rendition2.codec == rendition1.codec)
    }

    // MARK: - Builder DSL

    @Test("Rendition with codec in MasterPlaylist builder")
    func builderWithCodec() {
        let playlist = MasterPlaylist {
            Variant(
                bandwidth: 2_000_000,
                uri: "video.m3u8",
                subtitles: "subs"
            )
            Rendition(
                type: .subtitles, groupId: "subs",
                name: "English", uri: "subs/en.m3u8",
                language: "en",
                codec: SubtitleCodec.imsc1.rawValue
            )
        }
        let rendition = playlist.renditions.first
        #expect(rendition?.codec == "stpp.ttml.im1t")
        #expect(rendition?.subtitleCodec == .imsc1)
    }
}
