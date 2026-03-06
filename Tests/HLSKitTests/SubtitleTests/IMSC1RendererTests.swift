// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("IMSC1Renderer — TTML Rendering")
struct IMSC1RendererTests {

    @Test("Render minimal document")
    func renderMinimal() {
        let doc = IMSC1Document(
            language: "en",
            subtitles: [
                IMSC1Subtitle(
                    begin: 0, end: 2, text: "Hello"
                )
            ]
        )
        let xml = IMSC1Renderer.render(doc)
        #expect(xml.contains("xml:lang=\"en\""))
        #expect(xml.contains("<body>"))
        #expect(xml.contains("Hello"))
        #expect(xml.contains("</tt>"))
    }

    @Test("Render includes correct namespaces")
    func renderNamespaces() {
        let doc = IMSC1Document(language: "en")
        let xml = IMSC1Renderer.render(doc)
        #expect(
            xml.contains(
                "xmlns=\"http://www.w3.org/ns/ttml\""
            )
        )
        #expect(
            xml.contains(
                "xmlns:ttp=\"http://www.w3.org/ns/ttml#parameter\""
            )
        )
        #expect(
            xml.contains(
                "xmlns:tts=\"http://www.w3.org/ns/ttml#styling\""
            )
        )
    }

    @Test("Render includes IMSC1 profile declaration")
    func renderProfile() {
        let doc = IMSC1Document(language: "en")
        let xml = IMSC1Renderer.render(doc)
        #expect(
            xml.contains(
                "ttp:profile=\"http://www.w3.org/ns/ttml/"
                    + "profile/imsc1/text\""
            )
        )
    }

    @Test("Render with regions")
    func renderRegions() {
        let doc = IMSC1Document(
            language: "en",
            regions: [
                IMSC1Region(
                    id: "r1", originX: 10, originY: 80,
                    extentWidth: 80, extentHeight: 10
                )
            ]
        )
        let xml = IMSC1Renderer.render(doc)
        #expect(xml.contains("<layout>"))
        #expect(xml.contains("xml:id=\"r1\""))
        #expect(xml.contains("tts:origin=\"10% 80%\""))
        #expect(xml.contains("tts:extent=\"80% 10%\""))
    }

    @Test("Render with styles")
    func renderStyles() {
        let doc = IMSC1Document(
            language: "en",
            styles: [
                IMSC1Style(
                    id: "s1",
                    fontFamily: "sansSerif",
                    color: "white",
                    backgroundColor: "#000000FF",
                    fontStyle: "italic",
                    fontWeight: "bold",
                    textOutline: "black 2px"
                )
            ]
        )
        let xml = IMSC1Renderer.render(doc)
        #expect(xml.contains("<styling>"))
        #expect(xml.contains("xml:id=\"s1\""))
        #expect(xml.contains("tts:fontFamily=\"sansSerif\""))
        #expect(xml.contains("tts:color=\"white\""))
        #expect(
            xml.contains("tts:backgroundColor=\"#000000FF\"")
        )
        #expect(xml.contains("tts:fontStyle=\"italic\""))
        #expect(xml.contains("tts:fontWeight=\"bold\""))
        #expect(
            xml.contains("tts:textOutline=\"black 2px\"")
        )
    }

    @Test("Render multiple subtitles")
    func renderMultipleSubtitles() {
        let doc = IMSC1Document(
            language: "en",
            subtitles: [
                IMSC1Subtitle(
                    begin: 0, end: 2, text: "First"
                ),
                IMSC1Subtitle(
                    begin: 2, end: 4, text: "Second"
                )
            ]
        )
        let xml = IMSC1Renderer.render(doc)
        #expect(xml.contains("First"))
        #expect(xml.contains("Second"))
        #expect(
            xml.contains(
                "begin=\"00:00:00.000\" end=\"00:00:02.000\""
            )
        )
        #expect(
            xml.contains(
                "begin=\"00:00:02.000\" end=\"00:00:04.000\""
            )
        )
    }

    @Test("Render region with fractional percentages")
    func renderFractionalPercent() {
        let doc = IMSC1Document(
            language: "en",
            regions: [
                IMSC1Region(
                    id: "r1", originX: 10.5, originY: 80.25,
                    extentWidth: 79.5, extentHeight: 9.75
                )
            ]
        )
        let xml = IMSC1Renderer.render(doc)
        #expect(xml.contains("tts:origin=\"10.50% 80.25%\""))
        #expect(xml.contains("tts:extent=\"79.50% 9.75%\""))
    }

    @Test("Timecode formatting HH:MM:SS.mmm")
    func timecodeFormatting() {
        let tc = IMSC1Renderer.formatTimecode(3661.5)
        #expect(tc == "01:01:01.500")
    }

    @Test("Round-trip: render then parse")
    func roundTrip() throws {
        let original = IMSC1Document(
            language: "fr",
            styles: [
                IMSC1Style(id: "s1", fontSize: "120%")
            ],
            subtitles: [
                IMSC1Subtitle(
                    begin: 5.0, end: 10.0, text: "Bonjour",
                    style: "s1"
                )
            ]
        )
        let xml = IMSC1Renderer.render(original)
        let parsed = try IMSC1Parser.parse(xml: xml)
        #expect(parsed.language == "fr")
        #expect(parsed.subtitles.count == 1)
        #expect(parsed.subtitles[0].text == "Bonjour")
        #expect(parsed.styles[0].fontSize == "120%")
    }
}
