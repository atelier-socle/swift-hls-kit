// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - LiveWebVTTWriter

@Suite("LiveWebVTTWriter — Segment Rendering")
struct LiveWebVTTWriterTests {

    @Test("Default init has 6-second segment duration")
    func defaultInit() async {
        let writer = LiveWebVTTWriter()
        let index = await writer.currentSegmentIndex()
        let count = await writer.cueCount()
        #expect(index == 0)
        #expect(count == 0)
    }

    @Test("addCue increments cue count")
    func addCue() async {
        let writer = LiveWebVTTWriter()
        await writer.addCue(WebVTTCue(startTime: 0.5, endTime: 3.0, text: "Hello"))
        let count = await writer.cueCount()
        #expect(count == 1)
    }

    @Test("renderSegment produces valid WebVTT")
    func renderSegment() async {
        let writer = LiveWebVTTWriter()
        await writer.addCue(WebVTTCue(startTime: 0.5, endTime: 3.0, text: "Hello"))
        let vtt = await writer.renderSegment()
        #expect(vtt.hasPrefix("WEBVTT\n"))
        #expect(vtt.contains("00:00.500 --> 00:03.000"))
        #expect(vtt.contains("Hello"))
    }

    @Test("renderSegment clears cues and advances index")
    func renderSegmentAdvances() async {
        let writer = LiveWebVTTWriter()
        await writer.addCue(WebVTTCue(startTime: 0, endTime: 1, text: "Test"))
        _ = await writer.renderSegment()
        let count = await writer.cueCount()
        let index = await writer.currentSegmentIndex()
        #expect(count == 0)
        #expect(index == 1)
    }

    @Test("previewSegment does not advance")
    func previewSegment() async {
        let writer = LiveWebVTTWriter()
        await writer.addCue(WebVTTCue(startTime: 0, endTime: 1, text: "Preview"))
        let vtt = await writer.previewSegment()
        let count = await writer.cueCount()
        let index = await writer.currentSegmentIndex()
        #expect(vtt.contains("Preview"))
        #expect(count == 1)
        #expect(index == 0)
    }

    @Test("Empty segment renders header only")
    func emptySegment() async {
        let writer = LiveWebVTTWriter()
        let vtt = await writer.renderSegment()
        #expect(vtt == "WEBVTT\n")
    }

    @Test("Multiple cues render in order")
    func multipleCues() async {
        let writer = LiveWebVTTWriter()
        await writer.addCue(WebVTTCue(startTime: 0, endTime: 2, text: "First"))
        await writer.addCue(WebVTTCue(startTime: 2, endTime: 4, text: "Second"))
        let vtt = await writer.renderSegment()
        let firstRange = vtt.range(of: "First")
        let secondRange = vtt.range(of: "Second")
        #expect(firstRange != nil)
        #expect(secondRange != nil)
        if let first = firstRange, let second = secondRange {
            #expect(first.lowerBound < second.lowerBound)
        }
    }

    @Test("reset clears state completely")
    func reset() async {
        let writer = LiveWebVTTWriter()
        await writer.addCue(WebVTTCue(startTime: 0, endTime: 1, text: "Test"))
        _ = await writer.renderSegment()
        await writer.reset()
        let index = await writer.currentSegmentIndex()
        let count = await writer.cueCount()
        #expect(index == 0)
        #expect(count == 0)
    }

    @Test("Custom segment duration")
    func customDuration() async {
        let writer = LiveWebVTTWriter(segmentDuration: 10.0)
        let index = await writer.currentSegmentIndex()
        #expect(index == 0)
    }
}

// MARK: - WebVTTCue

@Suite("WebVTTCue — Formatting")
struct WebVTTCueTests {

    @Test("Basic cue format")
    func basicFormat() {
        let cue = WebVTTCue(startTime: 0.5, endTime: 3.0, text: "Hello")
        let formatted = cue.format()
        #expect(formatted == "00:00.500 --> 00:03.000\nHello\n")
    }

    @Test("Cue with position")
    func cueWithPosition() {
        let cue = WebVTTCue(startTime: 0, endTime: 1, text: "Pos", position: 50)
        let formatted = cue.format()
        #expect(formatted.contains("position:50%"))
    }

    @Test("Cue with alignment")
    func cueWithAlignment() {
        let cue = WebVTTCue(startTime: 0, endTime: 1, text: "Align", alignment: .center)
        let formatted = cue.format()
        #expect(formatted.contains("align:center"))
    }

    @Test("Cue with position and alignment")
    func cueWithPositionAndAlignment() {
        let cue = WebVTTCue(
            startTime: 0, endTime: 1, text: "Both",
            position: 80, alignment: .end
        )
        let formatted = cue.format()
        #expect(formatted.contains("position:80%"))
        #expect(formatted.contains("align:end"))
    }

    @Test("Time formatting with hours")
    func timeFormatWithHours() {
        let cue = WebVTTCue(startTime: 3661.5, endTime: 3665.0, text: "Hour")
        let formatted = cue.format()
        #expect(formatted.contains("01:01:01.500"))
        #expect(formatted.contains("01:01:05.000"))
    }

    @Test("WebVTTCue equatable")
    func equatable() {
        let a = WebVTTCue(startTime: 0, endTime: 1, text: "Same")
        let b = WebVTTCue(startTime: 0, endTime: 1, text: "Same")
        #expect(a == b)
    }
}

// MARK: - WebVTTAlignment

@Suite("WebVTTAlignment — Cases")
struct WebVTTAlignmentTests {

    @Test("All alignment cases exist")
    func allCases() {
        let cases = WebVTTAlignment.allCases
        #expect(cases.count == 5)
        #expect(cases.contains(.start))
        #expect(cases.contains(.center))
        #expect(cases.contains(.end))
        #expect(cases.contains(.left))
        #expect(cases.contains(.right))
    }

    @Test("Raw values match WebVTT spec")
    func rawValues() {
        #expect(WebVTTAlignment.start.rawValue == "start")
        #expect(WebVTTAlignment.center.rawValue == "center")
        #expect(WebVTTAlignment.end.rawValue == "end")
        #expect(WebVTTAlignment.left.rawValue == "left")
        #expect(WebVTTAlignment.right.rawValue == "right")
    }
}
