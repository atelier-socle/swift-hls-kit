// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - Engine Tests

@Suite("HLSEngine Facade")
struct HLSEngineTests {

    @Test("Engine can be instantiated")
    func instantiation() {
        let engine = HLSEngine()
        _ = engine
    }

    @Test("Engine parses a minimal master playlist")
    func parseMaster() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8
            """

        let engine = HLSEngine()
        let manifest = try engine.parse(m3u8)

        if case .master = manifest {
            // Pass — correctly identified as master playlist
        } else {
            Issue.record("Expected .master manifest")
        }
    }

    @Test("Engine parses a minimal media playlist")
    func parseMedia() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXTINF:9.009,
            segment001.ts
            """

        let engine = HLSEngine()
        let manifest = try engine.parse(m3u8)

        if case .media = manifest {
            // Pass — correctly identified as media playlist
        } else {
            Issue.record("Expected .media manifest")
        }
    }

    @Test("Engine rejects input without EXTM3U header")
    func missingHeader() {
        let engine = HLSEngine()
        #expect(throws: ParserError.missingHeader) {
            try engine.parse("not a playlist")
        }
    }

    @Test("Engine generates a master playlist")
    func generateMaster() {
        let engine = HLSEngine()
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(bandwidth: 800_000, resolution: .p480, uri: "480p/playlist.m3u8")
            ]
        )

        let m3u8 = engine.generate(playlist)
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXT-X-VERSION:7"))
        #expect(m3u8.contains("BANDWIDTH=800000"))
        #expect(m3u8.contains("480p/playlist.m3u8"))
    }

    @Test("Engine generates a media playlist")
    func generateMedia() {
        let engine = HLSEngine()
        let playlist = MediaPlaylist(
            version: .v3,
            targetDuration: 10,
            playlistType: .vod,
            hasEndList: true,
            segments: [
                Segment(duration: 9.009, uri: "segment001.ts")
            ]
        )

        let m3u8 = engine.generate(playlist)
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXT-X-VERSION:3"))
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:10"))
        #expect(m3u8.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        #expect(m3u8.contains("#EXTINF:9.009,"))
        #expect(m3u8.contains("segment001.ts"))
        #expect(m3u8.contains("#EXT-X-ENDLIST"))
    }

    @Test("Engine validates a valid master playlist")
    func validateValidMaster() {
        let engine = HLSEngine()
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "480p/playlist.m3u8")
            ]
        )

        let report = engine.validate(playlist)
        #expect(report.isValid == true)
    }

    @Test("Engine validates an empty master playlist")
    func validateEmptyMaster() {
        let engine = HLSEngine()
        let playlist = MasterPlaylist()

        let report = engine.validate(playlist)
        #expect(report.isValid == false)
        #expect(report.errors.count >= 1)
    }

    @Test("Engine parseAndValidate combines both operations")
    func parseAndValidate() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXTINF:9.009,
            segment001.ts
            """

        let engine = HLSEngine()
        let (manifest, report) = try engine.parseAndValidate(m3u8)

        if case .media = manifest {
            // Pass
        } else {
            Issue.record("Expected .media manifest")
        }
        #expect(report.isValid == true)
    }
}

// MARK: - Manifest Enum Tests

@Suite("Manifest Enum")
struct ManifestEnumTests {

    @Test("Manifest.master case holds MasterPlaylist")
    func masterCase() {
        let playlist = MasterPlaylist(
            variants: [Variant(bandwidth: 1_000_000, uri: "video.m3u8")]
        )
        let manifest = Manifest.master(playlist)

        if case .master(let p) = manifest {
            #expect(p.variants.count == 1)
        } else {
            Issue.record("Expected .master case")
        }
    }

    @Test("Manifest.media case holds MediaPlaylist")
    func mediaCase() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [Segment(duration: 10.0, uri: "seg.ts")]
        )
        let manifest = Manifest.media(playlist)

        if case .media(let p) = manifest {
            #expect(p.segments.count == 1)
        } else {
            Issue.record("Expected .media case")
        }
    }

    @Test("Manifest conforms to Hashable")
    func hashable() {
        let a = Manifest.master(MasterPlaylist())
        let b = Manifest.master(MasterPlaylist())
        #expect(a == b)
    }
}

// MARK: - ManifestParser Tests

@Suite("ManifestParser")
struct ManifestParserTests {

    @Test("Parser instantiation")
    func instantiation() {
        let parser = ManifestParser()
        _ = parser
    }

    @Test("Parser rejects empty string")
    func emptyString() {
        let parser = ManifestParser()
        #expect(throws: ParserError.emptyManifest) {
            try parser.parse("")
        }
    }
}

// MARK: - ManifestGenerator Tests

@Suite("ManifestGenerator")
struct ManifestGeneratorTests {

    @Test("Generator instantiation")
    func instantiation() {
        let generator = ManifestGenerator()
        _ = generator
    }

    @Test("Generated output starts with EXTM3U")
    func outputStartsWithHeader() {
        let generator = ManifestGenerator()
        let output = generator.generate(.master(MasterPlaylist()))
        #expect(output.hasPrefix("#EXTM3U"))
    }
}

// MARK: - HLSValidator Tests

@Suite("HLSValidator")
struct HLSValidatorTests {

    @Test("Validator instantiation")
    func instantiation() {
        let validator = HLSValidator()
        _ = validator
    }

    @Test("Validator detects negative segment duration")
    func negativeSegmentDuration() {
        let validator = HLSValidator()
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(duration: -1.0, uri: "bad.ts")
            ]
        )

        let report = validator.validate(playlist)
        #expect(report.isValid == false)
    }

    @Test("Validator detects segment exceeding target duration")
    func segmentExceedsTargetDuration() {
        let validator = HLSValidator()
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 7.5, uri: "too-long.ts")
            ]
        )

        let report = validator.validate(playlist)
        #expect(report.isValid == false)
    }

    @Test("Validator warns about missing CODECS in variants")
    func missingCodecsWarning() {
        let validator = HLSValidator()
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 1_000_000, uri: "video.m3u8")
            ]
        )

        let report = validator.validate(playlist)
        #expect(report.warnings.count >= 1)
    }
}

// MARK: - AttributeParser Tests

@Suite("AttributeParser")
struct AttributeParserTests {

    @Test("Parse simple attribute list")
    func simpleAttributes() throws {
        let parser = AttributeParser()
        let result = parser.parseAttributes("BANDWIDTH=800000,RESOLUTION=1280x720")
        #expect(result["BANDWIDTH"] == "800000")
        #expect(result["RESOLUTION"] == "1280x720")
    }

    @Test("Parse quoted string attributes")
    func quotedAttributes() throws {
        let parser = AttributeParser()
        let result = parser.parseAttributes("CODECS=\"avc1.4d401f,mp4a.40.2\",BANDWIDTH=2800000")
        #expect(result["CODECS"] == "avc1.4d401f,mp4a.40.2")
        #expect(result["BANDWIDTH"] == "2800000")
    }

    @Test("Parse resolution")
    func parseResolution() throws {
        let parser = AttributeParser()
        let resolution = try parser.parseResolution("1920x1080", attribute: "RESOLUTION")
        #expect(resolution == .p1080)
    }

    @Test("Parse decimal integer")
    func parseDecimalInteger() throws {
        let parser = AttributeParser()
        let value = try parser.parseDecimalInteger("2800000", attribute: "BANDWIDTH")
        #expect(value == 2_800_000)
    }

    @Test("Parse decimal float")
    func parseDecimalFloat() throws {
        let parser = AttributeParser()
        let value = try parser.parseDecimalFloat("6.006", attribute: "DURATION")
        #expect(value == 6.006)
    }
}

// MARK: - TagParser Tests

@Suite("TagParser")
struct TagParserTests {

    @Test("Parse EXTINF with title")
    func parseExtInfWithTitle() throws {
        let parser = TagParser()
        let (duration, title) = try parser.parseExtInf("9.009,Segment Title")
        #expect(duration == 9.009)
        #expect(title == "Segment Title")
    }

    @Test("Parse EXTINF without title")
    func parseExtInfWithoutTitle() throws {
        let parser = TagParser()
        let (duration, title) = try parser.parseExtInf("6.006,")
        #expect(duration == 6.006)
        #expect(title == nil)
    }

    @Test("Parse BYTERANGE with offset")
    func parseByteRangeWithOffset() throws {
        let parser = TagParser()
        let range = try parser.parseByteRange("1024@512")
        #expect(range.length == 1024)
        #expect(range.offset == 512)
    }

    @Test("Parse BYTERANGE without offset")
    func parseByteRangeWithoutOffset() throws {
        let parser = TagParser()
        let range = try parser.parseByteRange("2048")
        #expect(range.length == 2048)
        #expect(range.offset == nil)
    }
}

// MARK: - TagWriter Tests

@Suite("TagWriter")
struct TagWriterTests {

    @Test("Write EXTINF tag")
    func writeExtInf() {
        let writer = TagWriter()
        let result = writer.writeExtInf(
            duration: 6.006, title: nil, version: .v3
        )
        #expect(result == "#EXTINF:6.006,")
    }

    @Test("Write EXTINF with title")
    func writeExtInfWithTitle() {
        let writer = TagWriter()
        let result = writer.writeExtInf(
            duration: 9.009, title: "Intro", version: .v3
        )
        #expect(result == "#EXTINF:9.009,Intro")
    }

    @Test("Write BYTERANGE tag")
    func writeByteRange() {
        let writer = TagWriter()
        let result = writer.writeByteRange(ByteRange(length: 1024, offset: 512))
        #expect(result == "#EXT-X-BYTERANGE:1024@512")
    }

    @Test("Write KEY tag")
    func writeKey() {
        let writer = TagWriter()
        let key = EncryptionKey(method: .aes128, uri: "key.bin")
        let result = writer.writeKey(key)
        #expect(result.contains("METHOD=AES-128"))
        #expect(result.contains("URI=\"key.bin\""))
    }

    @Test("Write MAP tag")
    func writeMap() {
        let writer = TagWriter()
        let map = MapTag(uri: "init.mp4")
        let result = writer.writeMap(map)
        #expect(result == "#EXT-X-MAP:URI=\"init.mp4\"")
    }
}
