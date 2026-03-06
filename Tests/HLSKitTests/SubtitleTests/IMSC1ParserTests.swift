// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("IMSC1Parser — Valid Documents")
struct IMSC1ParserValidTests {

    @Test("Parse minimal valid TTML")
    func parseMinimal() throws {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:01.000" end="00:00:03.000">Hello</p>
                </div>
              </body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        #expect(doc.language == "en")
        #expect(doc.subtitles.count == 1)
        #expect(doc.subtitles[0].text == "Hello")
        #expect(doc.subtitles[0].begin == 1.0)
        #expect(doc.subtitles[0].end == 3.0)
    }

    @Test("Parse document with regions")
    func parseRegions() throws {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:tts="http://www.w3.org/ns/ttml#styling">
              <head>
                <layout>
                  <region xml:id="bottom"
                          tts:origin="10% 80%"
                          tts:extent="80% 10%"/>
                </layout>
              </head>
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:02.000"
                     region="bottom">Test</p>
                </div>
              </body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        #expect(doc.regions.count == 1)
        #expect(doc.regions[0].id == "bottom")
        #expect(doc.regions[0].originX == 10.0)
        #expect(doc.regions[0].originY == 80.0)
        #expect(doc.regions[0].extentWidth == 80.0)
        #expect(doc.regions[0].extentHeight == 10.0)
        #expect(doc.subtitles[0].region == "bottom")
    }

    @Test("Parse document with styles")
    func parseStyles() throws {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:tts="http://www.w3.org/ns/ttml#styling">
              <head>
                <styling>
                  <style xml:id="s1"
                         tts:fontFamily="proportionalSansSerif"
                         tts:fontSize="100%"
                         tts:color="white"
                         tts:backgroundColor="black"
                         tts:textAlign="center"/>
                </styling>
              </head>
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:02.000"
                     style="s1">Styled</p>
                </div>
              </body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        #expect(doc.styles.count == 1)
        #expect(doc.styles[0].id == "s1")
        #expect(doc.styles[0].fontFamily == "proportionalSansSerif")
        #expect(doc.styles[0].fontSize == "100%")
        #expect(doc.styles[0].color == "white")
        #expect(doc.styles[0].backgroundColor == "black")
        #expect(doc.styles[0].textAlign == "center")
        #expect(doc.subtitles[0].style == "s1")
    }

    @Test("Parse multiple subtitles")
    func parseMultipleSubtitles() throws {
        let xml = """
            <tt xml:lang="fr" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:02.000">Premier</p>
                  <p begin="00:00:02.000" end="00:00:04.000">Deuxième</p>
                  <p begin="00:00:04.000" end="00:00:06.000">Troisième</p>
                </div>
              </body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        #expect(doc.language == "fr")
        #expect(doc.subtitles.count == 3)
        #expect(doc.subtitles[0].text == "Premier")
        #expect(doc.subtitles[1].text == "Deuxième")
        #expect(doc.subtitles[2].text == "Troisième")
    }

    @Test("Parse full document with regions, styles, and subtitles")
    func parseFullDocument() throws {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:tts="http://www.w3.org/ns/ttml#styling"
                xmlns:ttp="http://www.w3.org/ns/ttml#parameter"
                ttp:profile="http://www.w3.org/ns/ttml/profile/imsc1/text">
              <head>
                <styling>
                  <style xml:id="default" tts:color="white"
                         tts:fontFamily="proportionalSansSerif"/>
                </styling>
                <layout>
                  <region xml:id="r1" tts:origin="10% 80%"
                          tts:extent="80% 10%"/>
                </layout>
              </head>
              <body>
                <div>
                  <p begin="00:00:01.500" end="00:00:03.500"
                     region="r1" style="default">Full doc</p>
                </div>
              </body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        #expect(doc.language == "en")
        #expect(doc.regions.count == 1)
        #expect(doc.styles.count == 1)
        #expect(doc.subtitles.count == 1)
        #expect(doc.subtitles[0].begin == 1.5)
        #expect(doc.subtitles[0].end == 3.5)
        #expect(doc.subtitles[0].region == "r1")
        #expect(doc.subtitles[0].style == "default")
    }

    @Test("Parse timecodes without milliseconds")
    func parseTimecodesNoMillis() throws {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:01:30" end="00:02:00">No millis</p>
                </div>
              </body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        #expect(doc.subtitles[0].begin == 90.0)
        #expect(doc.subtitles[0].end == 120.0)
    }

    @Test("Parse timecodes with HH:MM:SS.mmm precision")
    func parseTimecodesPrecision() throws {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="01:02:03.456" end="23:59:59.999">Precise</p>
                </div>
              </body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        let expectedBegin = 1.0 * 3600 + 2.0 * 60 + 3.456
        let expectedEnd = 23.0 * 3600 + 59.0 * 60 + 59.999
        #expect(
            abs(doc.subtitles[0].begin - expectedBegin) < 0.001
        )
        #expect(
            abs(doc.subtitles[0].end - expectedEnd) < 0.001
        )
    }

    @Test("Parse real-world IMSC1 sample with namespaced elements")
    func parseRealWorldSample() throws {
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <tt xml:lang="en"
                xmlns="http://www.w3.org/ns/ttml"
                xmlns:ttp="http://www.w3.org/ns/ttml#parameter"
                xmlns:tts="http://www.w3.org/ns/ttml#styling"
                ttp:profile="http://www.w3.org/ns/ttml/profile/imsc1/text">
              <head>
                <styling>
                  <style xml:id="defaultStyle"
                         tts:fontFamily="proportionalSansSerif"
                         tts:fontSize="100%"
                         tts:textAlign="center"
                         tts:color="white"
                         tts:backgroundColor="#000000FF"/>
                </styling>
                <layout>
                  <region xml:id="bottomRegion"
                          tts:origin="10% 80%"
                          tts:extent="80% 15%"/>
                </layout>
              </head>
              <body>
                <div>
                  <p begin="00:00:01.000" end="00:00:04.000"
                     region="bottomRegion" style="defaultStyle">
                    Welcome to the show.
                  </p>
                  <p begin="00:00:05.000" end="00:00:08.000"
                     region="bottomRegion" style="defaultStyle">
                    Let us begin.
                  </p>
                </div>
              </body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        #expect(doc.language == "en")
        #expect(doc.styles.count == 1)
        #expect(doc.styles[0].backgroundColor == "#000000FF")
        #expect(doc.regions.count == 1)
        #expect(doc.regions[0].extentHeight == 15.0)
        #expect(doc.subtitles.count == 2)
        #expect(
            doc.subtitles[0].text == "Welcome to the show."
        )
        #expect(doc.subtitles[1].text == "Let us begin.")
    }
}

// MARK: - Error Cases & Round-Trip

@Suite("IMSC1Parser — Errors & Round-Trip")
struct IMSC1ParserErrorTests {

    @Test("Error on invalid XML")
    func errorInvalidXML() {
        let xml = "<not valid xml <>"
        #expect(throws: IMSC1Error.self) {
            try IMSC1Parser.parse(xml: xml)
        }
    }

    @Test("Error on missing tt element")
    func errorMissingTT() {
        let xml = """
            <?xml version="1.0"?>
            <document>
              <body><p>Text</p></body>
            </document>
            """
        #expect(throws: IMSC1Error.missingTTElement) {
            try IMSC1Parser.parse(xml: xml)
        }
    }

    @Test("Error on invalid timecode")
    func errorInvalidTimecode() {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="invalid" end="00:00:02.000">Bad</p>
                </div>
              </body>
            </tt>
            """
        #expect(throws: IMSC1Error.self) {
            try IMSC1Parser.parse(xml: xml)
        }
    }

    @Test("Error on missing language")
    func errorMissingLanguage() {
        let xml = """
            <tt xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="00:00:00.000" end="00:00:01.000">No lang</p>
                </div>
              </body>
            </tt>
            """
        #expect(throws: IMSC1Error.missingLanguage) {
            try IMSC1Parser.parse(xml: xml)
        }
    }

    @Test("Error on timecode with non-numeric hours")
    func errorTimecodeNonNumeric() {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
              <body>
                <div>
                  <p begin="ab:00:00.000" end="00:00:02.000">Bad</p>
                </div>
              </body>
            </tt>
            """
        #expect(throws: IMSC1Error.self) {
            try IMSC1Parser.parse(xml: xml)
        }
    }

    @Test("Parse skips regions and styles without id")
    func parseSkipsNoId() throws {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:tts="http://www.w3.org/ns/ttml#styling">
              <head>
                <styling>
                  <style tts:color="white"/>
                </styling>
                <layout>
                  <region tts:origin="10% 80%"
                          tts:extent="80% 10%"/>
                </layout>
              </head>
              <body><div>
                <p begin="00:00:00.000" end="00:00:01.000">X</p>
              </div></body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        #expect(doc.styles.isEmpty)
        #expect(doc.regions.isEmpty)
    }

    @Test("Parse style with all properties")
    func parseAllStyleProperties() throws {
        let xml = """
            <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
                xmlns:tts="http://www.w3.org/ns/ttml#styling">
              <head>
                <styling>
                  <style xml:id="full"
                         tts:fontFamily="sansSerif"
                         tts:fontSize="120%"
                         tts:color="yellow"
                         tts:backgroundColor="blue"
                         tts:textAlign="start"
                         tts:fontStyle="italic"
                         tts:fontWeight="bold"
                         tts:textOutline="black 2px"/>
                </styling>
              </head>
              <body><div>
                <p begin="00:00:00.000" end="00:00:01.000">X</p>
              </div></body>
            </tt>
            """
        let doc = try IMSC1Parser.parse(xml: xml)
        let style = doc.styles[0]
        #expect(style.fontStyle == "italic")
        #expect(style.fontWeight == "bold")
        #expect(style.textOutline == "black 2px")
    }

    @Test("Round-trip: parse rendered document")
    func roundTrip() throws {
        let original = IMSC1Document(
            language: "en",
            regions: [
                IMSC1Region(
                    id: "r1", originX: 10, originY: 80,
                    extentWidth: 80, extentHeight: 10
                )
            ],
            styles: [
                IMSC1Style(
                    id: "s1", color: "white",
                    textAlign: "center"
                )
            ],
            subtitles: [
                IMSC1Subtitle(
                    begin: 1.0, end: 3.0, text: "Round trip",
                    region: "r1", style: "s1"
                )
            ]
        )
        let xml = IMSC1Renderer.render(original)
        let parsed = try IMSC1Parser.parse(xml: xml)
        #expect(parsed.language == original.language)
        #expect(parsed.regions.count == original.regions.count)
        #expect(parsed.styles.count == original.styles.count)
        #expect(
            parsed.subtitles.count == original.subtitles.count
        )
        #expect(parsed.subtitles[0].text == "Round trip")
        #expect(abs(parsed.subtitles[0].begin - 1.0) < 0.001)
        #expect(abs(parsed.subtitles[0].end - 3.0) < 0.001)
    }
}
