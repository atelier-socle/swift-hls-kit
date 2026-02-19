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
        #expect(report.warnings.count >= 1)
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
