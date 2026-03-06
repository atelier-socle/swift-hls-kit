// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - IMSC1 Subtitle Showcase

@Suite("IMSC1 Subtitle Showcase — Parse, Render & Segment")
struct IMSC1ShowcaseTests {

    // MARK: - Sample TTML

    private var sampleTTML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
          <body>
            <div>
              <p begin="00:00:01.000" end="00:00:04.000">Hello world</p>
              <p begin="00:00:05.000" end="00:00:08.000">Welcome to IMSC1</p>
            </div>
          </body>
        </tt>
        """
    }

    // MARK: - Tests

    @Test("Parse TTML document — verify language, subtitle count, timing, and text")
    func parseTTMLDocument() throws {
        let document = try IMSC1Parser.parse(xml: sampleTTML)

        #expect(document.language == "en")
        #expect(document.subtitles.count == 2)

        #expect(document.subtitles[0].begin == 1.0)
        #expect(document.subtitles[0].end == 4.0)
        #expect(document.subtitles[0].text == "Hello world")

        #expect(document.subtitles[1].begin == 5.0)
        #expect(document.subtitles[1].end == 8.0)
        #expect(document.subtitles[1].text == "Welcome to IMSC1")
    }

    @Test("Render IMSC1Document — verify TTML XML output contains required elements")
    func renderIMSC1Document() throws {
        let document = try IMSC1Parser.parse(xml: sampleTTML)
        let output = IMSC1Renderer.render(document)

        #expect(output.contains("<tt"))
        #expect(output.contains("xmlns=\"http://www.w3.org/ns/ttml\""))
        #expect(output.contains("xml:lang=\"en\""))
        #expect(output.contains("Hello world"))
        #expect(output.contains("Welcome to IMSC1"))
    }

    @Test("Create IMSC1Document programmatically with region, style, and subtitle")
    func createDocumentProgrammatically() {
        let region = IMSC1Region(
            id: "bottom",
            originX: 10.0,
            originY: 80.0,
            extentWidth: 80.0,
            extentHeight: 20.0
        )
        let style = IMSC1Style(
            id: "default",
            fontFamily: "proportionalSansSerif",
            fontSize: "100%",
            color: "white",
            backgroundColor: "black",
            textAlign: "center"
        )
        let subtitle = IMSC1Subtitle(
            begin: 0.0,
            end: 3.5,
            text: "Programmatic subtitle",
            region: "bottom",
            style: "default"
        )
        let document = IMSC1Document(
            language: "fr",
            regions: [region],
            styles: [style],
            subtitles: [subtitle]
        )

        #expect(document.language == "fr")
        #expect(document.regions.count == 1)
        #expect(document.regions[0].id == "bottom")
        #expect(document.regions[0].originX == 10.0)
        #expect(document.styles.count == 1)
        #expect(document.styles[0].fontFamily == "proportionalSansSerif")
        #expect(document.styles[0].color == "white")
        #expect(document.subtitles.count == 1)
        #expect(document.subtitles[0].text == "Programmatic subtitle")
        #expect(document.subtitles[0].region == "bottom")
        #expect(document.subtitles[0].style == "default")
    }

    @Test("IMSC1Segmenter createInitSegment — verify non-empty and starts with ftyp")
    func createInitSegment() {
        let segmenter = IMSC1Segmenter()
        let initSegment = segmenter.createInitSegment(
            language: "eng",
            timescale: 1000
        )

        #expect(initSegment.count > 0)
        #expect(containsFourCC(initSegment, "ftyp"))
        #expect(containsFourCC(initSegment, "moov"))
        #expect(containsFourCC(initSegment, "stpp"))
    }

    @Test("IMSC1Segmenter createMediaSegment — verify non-empty and contains moof")
    func createMediaSegment() {
        let document = IMSC1Document(
            language: "en",
            subtitles: [
                IMSC1Subtitle(begin: 0.0, end: 6.0, text: "Test segment")
            ]
        )
        let segmenter = IMSC1Segmenter()
        let mediaSeg = segmenter.createMediaSegment(
            document: document,
            sequenceNumber: 1,
            baseDecodeTime: 0,
            duration: 6000
        )

        #expect(mediaSeg.count > 0)
        #expect(containsFourCC(mediaSeg, "moof"))
        #expect(containsFourCC(mediaSeg, "mdat"))
    }

    @Test("Parse manifest with subtitle rendition using CODECS stpp.ttml.im1t")
    func parseManifestWithIMSC1Rendition() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",\
            LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,\
            URI="subtitles/en.m3u8",CODECS="stpp.ttml.im1t"
            #EXT-X-STREAM-INF:BANDWIDTH=2800000,CODECS="avc1.4d401f,mp4a.40.2",\
            SUBTITLES="subs"
            video.m3u8
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }
        #expect(playlist.renditions.count == 1)
        #expect(playlist.renditions[0].type == .subtitles)
        #expect(playlist.renditions[0].codec == "stpp.ttml.im1t")
        #expect(playlist.renditions[0].subtitleCodec == .imsc1)
        #expect(playlist.renditions[0].language == "en")
        #expect(playlist.variants[0].subtitles == "subs")
    }

    @Test("Build MasterPlaylist with IMSC1 subtitle rendition")
    func buildMasterWithIMSC1Subtitles() {
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 4_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "video/1080p.m3u8",
                    codecs: "avc1.640028,mp4a.40.2",
                    subtitles: "imsc1-subs"
                )
            ],
            renditions: [
                Rendition(
                    type: .subtitles,
                    groupId: "imsc1-subs",
                    name: "English",
                    uri: "subtitles/en_imsc1.m3u8",
                    language: "en",
                    isDefault: true,
                    autoselect: true,
                    codec: SubtitleCodec.imsc1.rawValue
                )
            ]
        )
        let output = ManifestGenerator().generateMaster(playlist)

        #expect(output.contains("SUBTITLES=\"imsc1-subs\""))
        #expect(output.contains("TYPE=SUBTITLES"))
        #expect(output.contains("CODECS=\"stpp.ttml.im1t\""))
        #expect(output.contains("LANGUAGE=\"en\""))
    }

    @Test("Round-trip: parse TTML then render then parse again — verify identical subtitles")
    func roundTripTTML() throws {
        let original = try IMSC1Parser.parse(xml: sampleTTML)
        let rendered = IMSC1Renderer.render(original)
        let reparsed = try IMSC1Parser.parse(xml: rendered)

        #expect(reparsed.language == original.language)
        #expect(reparsed.subtitles.count == original.subtitles.count)

        for (index, subtitle) in reparsed.subtitles.enumerated() {
            #expect(subtitle.text == original.subtitles[index].text)
            #expect(subtitle.begin == original.subtitles[index].begin)
            #expect(subtitle.end == original.subtitles[index].end)
        }
    }

    @Test("IMSC1Renderer.formatTimecode produces HH:MM:SS.mmm format")
    func formatTimecodeFormat() {
        let result1 = IMSC1Renderer.formatTimecode(0.0)
        #expect(result1 == "00:00:00.000")

        let result2 = IMSC1Renderer.formatTimecode(61.5)
        #expect(result2 == "00:01:01.500")

        let result3 = IMSC1Renderer.formatTimecode(3661.123)
        #expect(result3 == "01:01:01.123")

        let result4 = IMSC1Renderer.formatTimecode(7200.0)
        #expect(result4 == "02:00:00.000")
    }

    @Test("IMSC1Parser.parseTimecode handles HH:MM:SS.mmm format")
    func parseTimecodeFormat() throws {
        let seconds1 = try IMSC1Parser.parseTimecode("00:00:01.000")
        #expect(seconds1 == 1.0)

        let seconds2 = try IMSC1Parser.parseTimecode("01:30:00.500")
        #expect(seconds2 == 5400.5)

        let seconds3 = try IMSC1Parser.parseTimecode("00:00:00.000")
        #expect(seconds3 == 0.0)

        let seconds4 = try IMSC1Parser.parseTimecode("02:15:30.750")
        #expect(seconds4 == 8130.75)
    }

    // MARK: - Helpers

    private func containsFourCC(_ data: Data, _ fourCC: String) -> Bool {
        let target = Data(fourCC.utf8)
        guard target.count == 4, data.count >= 4 else { return false }
        return data.range(of: target) != nil
    }
}
