// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AutoChapterGenerator", .timeLimit(.minutes(1)))
struct AutoChapterGeneratorTests {

    // MARK: - Empty

    @Test("Empty generator has 0 chapters")
    func emptyGenerator() {
        let gen = AutoChapterGenerator()
        #expect(gen.chapterCount == 0)
    }

    // MARK: - Adding Chapters

    @Test("addMetadataChange adds 1 chapter")
    func addMetadataChange() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "Introduction")
        #expect(gen.chapterCount == 1)
        #expect(gen.chapters[0].title == "Introduction")
    }

    @Test("Multiple metadata changes create chapters with correct startTimes")
    func multipleMetadataChanges() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "Intro")
        gen.addMetadataChange(at: 120.5, title: "Interview")
        gen.addMetadataChange(at: 300.0, title: "Outro")
        #expect(gen.chapterCount == 3)
        #expect(gen.chapters[0].startTime == 0.0)
        #expect(gen.chapters[1].startTime == 120.5)
        #expect(gen.chapters[2].startTime == 300.0)
    }

    @Test("addDiscontinuity creates chapter with default title")
    func addDiscontinuity() {
        var gen = AutoChapterGenerator()
        gen.addDiscontinuity(at: 60.0)
        #expect(gen.chapterCount == 1)
        #expect(gen.chapters[0].title.contains("Chapter"))
    }

    @Test("addFromDateRange creates chapter with dateRange title")
    func addFromDateRange() {
        var gen = AutoChapterGenerator()
        gen.addFromDateRange(id: "dr-1", startTime: 30.0, title: "Speaker A")
        #expect(gen.chapterCount == 1)
        #expect(gen.chapters[0].title == "Speaker A")
    }

    @Test("addExplicit creates chapter with exact times")
    func addExplicit() {
        var gen = AutoChapterGenerator()
        gen.addExplicit(title: "Manual", startTime: 10.0, endTime: 50.0)
        #expect(gen.chapters[0].startTime == 10.0)
        #expect(gen.chapters[0].endTime == 50.0)
    }

    // MARK: - Finalize

    @Test("finalize sets endTimes correctly")
    func finalizeEndTimes() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "Part 1")
        gen.addMetadataChange(at: 120.0, title: "Part 2")
        gen.finalize(totalDuration: 300.0)
        #expect(gen.chapters[0].endTime == 120.0)
        #expect(gen.chapters[1].endTime == 300.0)
    }

    @Test("finalize last chapter endTime equals totalDuration")
    func finalizeLastChapter() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "Only Chapter")
        gen.finalize(totalDuration: 600.0)
        #expect(gen.chapters[0].endTime == 600.0)
    }

    @Test("minimumDuration filter merges short chapters")
    func minimumDurationFilter() {
        var gen = AutoChapterGenerator(minimumDuration: 10.0)
        gen.addMetadataChange(at: 0.0, title: "Long Chapter")
        gen.addMetadataChange(at: 100.0, title: "Short")
        gen.addMetadataChange(at: 105.0, title: "Next Long")
        gen.finalize(totalDuration: 300.0)
        #expect(gen.chapterCount == 2)
        #expect(gen.chapters[0].title == "Long Chapter")
        #expect(gen.chapters[0].endTime == 105.0)
    }

    // MARK: - JSON Generation

    @Test("generateJSON produces valid Podcast Namespace 2.0 JSON")
    func generateJSON() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "Introduction")
        gen.addMetadataChange(at: 120.5, title: "Interview")
        gen.finalize(totalDuration: 300.0)
        let json = gen.generateJSON()
        #expect(json.contains("\"version\":\"1.2.0\""))
        #expect(json.contains("\"chapters\":["))
        #expect(json.contains("\"title\":\"Introduction\""))
        #expect(json.contains("\"title\":\"Interview\""))
    }

    @Test("generateJSON is parseable")
    func generateJSONParseable() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "Chapter 1")
        gen.addMetadataChange(at: 60.0, title: "Chapter 2")
        gen.finalize(totalDuration: 120.0)
        let json = gen.generateJSON()
        let data = Data(json.utf8)
        let parsed = try? JSONSerialization.jsonObject(with: data)
        #expect(parsed != nil)
    }

    // MARK: - WebVTT Generation

    @Test("generateWebVTT produces valid WebVTT")
    func generateWebVTT() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "Introduction")
        gen.addMetadataChange(at: 120.5, title: "Interview")
        gen.finalize(totalDuration: 300.0)
        let vtt = gen.generateWebVTT()
        #expect(vtt.hasPrefix("WEBVTT"))
        #expect(vtt.contains("Introduction"))
        #expect(vtt.contains("Interview"))
    }

    @Test("WebVTT timestamps in HH:MM:SS.mmm format")
    func webVTTTimestampFormat() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 120.5, title: "Chapter")
        gen.finalize(totalDuration: 300.0)
        let vtt = gen.generateWebVTT()
        #expect(vtt.contains("00:02:00.500"))
    }

    // MARK: - Properties

    @Test("chapterCount reflects finalized chapters")
    func chapterCountAfterFinalize() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "A")
        gen.addMetadataChange(at: 60.0, title: "B")
        gen.addMetadataChange(at: 120.0, title: "C")
        gen.finalize(totalDuration: 300.0)
        #expect(gen.chapterCount == 3)
    }

    @Test("reset clears all chapters")
    func resetClears() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "A")
        gen.addMetadataChange(at: 60.0, title: "B")
        gen.reset()
        #expect(gen.chapterCount == 0)
    }

    // MARK: - Coverage

    @Test("coveredDuration returns correct value")
    func coveredDuration() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 10.0, title: "A")
        gen.addMetadataChange(at: 60.0, title: "B")
        gen.finalize(totalDuration: 120.0)
        #expect(gen.coveredDuration == 110.0)
    }

    @Test("coveredDuration returns 0 for empty generator")
    func coveredDurationEmpty() {
        let gen = AutoChapterGenerator()
        #expect(gen.coveredDuration == 0)
    }

    @Test("generateJSON includes imageURL and url when set")
    func jsonWithImageAndURL() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(
            at: 0.0, title: "Ch1",
            imageURL: "https://example.com/img.jpg",
            url: "https://example.com/link"
        )
        gen.finalize(totalDuration: 60.0)
        let json = gen.generateJSON()
        #expect(json.contains("\"img\":\"https://example.com/img.jpg\""))
        #expect(json.contains("\"url\":\"https://example.com/link\""))
    }
}
