// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("IMSC1Document — Document Model")
struct IMSC1DocumentTests {

    @Test("Init with defaults")
    func initDefaults() {
        let doc = IMSC1Document(language: "en")
        #expect(doc.language == "en")
        #expect(doc.regions.isEmpty)
        #expect(doc.styles.isEmpty)
        #expect(doc.subtitles.isEmpty)
    }

    @Test("Init with all parameters")
    func initAllParams() {
        let region = IMSC1Region(
            id: "r1", originX: 10, originY: 80,
            extentWidth: 80, extentHeight: 10
        )
        let style = IMSC1Style(id: "s1", color: "white")
        let subtitle = IMSC1Subtitle(
            begin: 0, end: 2, text: "Hello"
        )
        let doc = IMSC1Document(
            language: "fr",
            regions: [region],
            styles: [style],
            subtitles: [subtitle]
        )
        #expect(doc.language == "fr")
        #expect(doc.regions.count == 1)
        #expect(doc.styles.count == 1)
        #expect(doc.subtitles.count == 1)
    }

    @Test("Equatable — equal documents")
    func equatableEqual() {
        let a = IMSC1Document(language: "en")
        let b = IMSC1Document(language: "en")
        #expect(a == b)
    }

    @Test("Equatable — different languages")
    func equatableDifferent() {
        let a = IMSC1Document(language: "en")
        let b = IMSC1Document(language: "fr")
        #expect(a != b)
    }

    @Test("Multiple subtitles")
    func multipleSubtitles() {
        let subs = [
            IMSC1Subtitle(begin: 0, end: 2, text: "First"),
            IMSC1Subtitle(begin: 2, end: 4, text: "Second"),
            IMSC1Subtitle(begin: 4, end: 6, text: "Third")
        ]
        let doc = IMSC1Document(
            language: "en", subtitles: subs
        )
        #expect(doc.subtitles.count == 3)
        #expect(doc.subtitles[0].text == "First")
        #expect(doc.subtitles[2].text == "Third")
    }

    @Test("Multiple regions")
    func multipleRegions() {
        let regions = [
            IMSC1Region(
                id: "top", originX: 10, originY: 10,
                extentWidth: 80, extentHeight: 10
            ),
            IMSC1Region(
                id: "bottom", originX: 10, originY: 80,
                extentWidth: 80, extentHeight: 10
            )
        ]
        let doc = IMSC1Document(
            language: "en", regions: regions
        )
        #expect(doc.regions.count == 2)
        #expect(doc.regions[0].id == "top")
        #expect(doc.regions[1].id == "bottom")
    }

    @Test("Subtitle with nil optionals")
    func subtitleNilOptionals() {
        let sub = IMSC1Subtitle(
            begin: 0, end: 1, text: "Test"
        )
        #expect(sub.region == nil)
        #expect(sub.style == nil)
    }

    @Test("Subtitle with region and style")
    func subtitleWithRegionAndStyle() {
        let sub = IMSC1Subtitle(
            begin: 0, end: 1, text: "Test",
            region: "r1", style: "s1"
        )
        #expect(sub.region == "r1")
        #expect(sub.style == "s1")
    }
}
