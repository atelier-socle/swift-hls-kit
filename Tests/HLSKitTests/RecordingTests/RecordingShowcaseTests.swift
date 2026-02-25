// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Recording Showcase", .timeLimit(.minutes(1)))
struct RecordingShowcaseTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    private func sampleData(size: Int = 1024) -> Data {
        Data(repeating: 0xAB, count: size)
    }

    // MARK: - Podcast Recording

    @Test("Podcast: 1-hour episode with auto chapters")
    func podcastRecording() async throws {
        let storage = MockRecordingStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .podcast)
        try await recorder.start()
        var chapters = AutoChapterGenerator()
        chapters.addMetadataChange(at: 0.0, title: "Introduction")
        for i in 0..<10 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        chapters.addMetadataChange(at: 60.0, title: "Guest Interview")
        for i in 10..<20 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        chapters.addMetadataChange(at: 120.0, title: "Q&A")
        for i in 20..<30 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        _ = try await recorder.finalize()
        chapters.finalize(totalDuration: 180.0)
        let json = chapters.generateJSON()
        #expect(json.contains("Introduction"))
        #expect(json.contains("Guest Interview"))
        let metadata = await recorder.segmentMetadata
        let converter = LiveToVODConverter()
        let vod = converter.convert(segments: metadata, options: .podcast)
        #expect(vod.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        #expect(vod.contains("seg0.ts"))
    }

    // MARK: - Live Sports Event

    @Test("Sports: 90 minutes with halftime discontinuity → archive VOD")
    func liveSportsEvent() async throws {
        let storage = MockRecordingStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .event)
        try await recorder.start()
        for i in 0..<5 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0,
                programDateTime: refDate.addingTimeInterval(TimeInterval(i) * 6.0)
            )
        }
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg5.ts", duration: 6.0,
            isDiscontinuity: true,
            programDateTime: refDate.addingTimeInterval(2700)
        )
        for i in 6..<10 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0,
                programDateTime: refDate.addingTimeInterval(2700 + TimeInterval(i - 5) * 6.0)
            )
        }
        _ = try await recorder.finalize()
        let metadata = await recorder.segmentMetadata
        let converter = LiveToVODConverter()
        let vod = converter.convert(segments: metadata, options: .archive)
        #expect(vod.contains("#EXT-X-DISCONTINUITY"))
        #expect(vod.contains("#EXT-X-PROGRAM-DATE-TIME:"))
    }

    // MARK: - Conference Talk

    @Test("Conference: speaker changes via DATERANGE → chapter per speaker")
    func conferenceTalk() {
        var chapters = AutoChapterGenerator()
        chapters.addFromDateRange(
            id: "speaker-1", startTime: 0.0, title: "Alice - Keynote",
            className: "com.conference.speaker"
        )
        chapters.addFromDateRange(
            id: "speaker-2", startTime: 900.0, title: "Bob - Deep Dive",
            className: "com.conference.speaker"
        )
        chapters.addFromDateRange(
            id: "speaker-3", startTime: 1800.0, title: "Carol - Workshop",
            className: "com.conference.speaker"
        )
        chapters.finalize(totalDuration: 2700.0)
        #expect(chapters.chapterCount == 3)
        let json = chapters.generateJSON()
        #expect(json.contains("Alice - Keynote"))
        #expect(json.contains("Bob - Deep Dive"))
    }

    // MARK: - Music Festival

    @Test("Music festival: multiple sets with gaps → chapters per set")
    func musicFestival() async throws {
        let storage = MockRecordingStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        var chapters = AutoChapterGenerator()
        chapters.addMetadataChange(at: 0.0, title: "Opening Act")
        for i in 0..<5 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        chapters.addDiscontinuity(at: 30.0, title: "Headliner")
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg5.ts", duration: 6.0, isDiscontinuity: true
        )
        for i in 6..<10 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        _ = try await recorder.finalize()
        chapters.finalize(totalDuration: 60.0)
        #expect(chapters.chapterCount == 2)
        let vtt = chapters.generateWebVTT()
        #expect(vtt.contains("Opening Act"))
        #expect(vtt.contains("Headliner"))
    }

    // MARK: - News Broadcast

    @Test("News: frequent metadata → chapters merged by minimumDuration")
    func newsBroadcast() {
        var chapters = AutoChapterGenerator(minimumDuration: 30.0)
        chapters.addMetadataChange(at: 0.0, title: "Headlines")
        chapters.addMetadataChange(at: 5.0, title: "Breaking News")
        chapters.addMetadataChange(at: 10.0, title: "Weather Update")
        chapters.addMetadataChange(at: 60.0, title: "Sports")
        chapters.finalize(totalDuration: 120.0)
        #expect(chapters.chapterCount == 2)
    }

    // MARK: - Live Radio Show

    @Test("Radio: 2-hour recording → podcast VOD with chapters")
    func liveRadioShow() async throws {
        let storage = MockRecordingStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .podcast)
        try await recorder.start()
        for i in 0..<20 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        _ = try await recorder.finalize()
        let metadata = await recorder.segmentMetadata
        let converter = LiveToVODConverter()
        let vod = converter.convert(segments: metadata, options: .podcast)
        #expect(vod.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        #expect(!vod.contains("#EXT-X-DISCONTINUITY"))
    }

    // MARK: - Emergency Recording

    @Test("Emergency: start mid-stream → recording picks up from first segment")
    func emergencyRecording() async throws {
        let storage = MockRecordingStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg42.ts", duration: 6.0
        )
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg43.ts", duration: 6.0
        )
        let segments = await recorder.recordedSegments
        #expect(segments == ["seg42.ts", "seg43.ts"])
    }

    // MARK: - Re-numbering

    @Test("Re-numbering: live seg42-seg44 → VOD seg0-seg2")
    func renumberingShowcase() async throws {
        let storage = MockRecordingStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        for i in 42..<45 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        _ = try await recorder.finalize()
        let metadata = await recorder.segmentMetadata
        let converter = LiveToVODConverter()
        let vod = converter.convert(segments: metadata, options: .podcast)
        #expect(vod.contains("seg0.ts"))
        #expect(vod.contains("seg1.ts"))
        #expect(vod.contains("seg2.ts"))
        #expect(!vod.contains("seg42"))
    }

    // MARK: - Full Ecosystem

    @Test("Full ecosystem: record + chapters + convert + validate")
    func fullEcosystem() async throws {
        let storage = MockRecordingStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        var chapters = AutoChapterGenerator()
        chapters.addMetadataChange(at: 0.0, title: "Segment 1")
        for i in 0..<5 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.006
            )
        }
        chapters.addMetadataChange(at: 30.0, title: "Segment 2")
        for i in 5..<10 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.006
            )
        }
        _ = try await recorder.finalize()
        chapters.finalize(totalDuration: 60.06)
        let json = chapters.generateJSON()
        let jsonData = Data(json.utf8)
        let parsed = try? JSONSerialization.jsonObject(with: jsonData)
        #expect(parsed != nil)
        let metadata = await recorder.segmentMetadata
        let converter = LiveToVODConverter()
        let vod = converter.convert(segments: metadata)
        let parser = ManifestParser()
        let manifest = try parser.parse(vod)
        if case .media(let mp) = manifest {
            #expect(mp.segments.count == 10)
            #expect(mp.hasEndList)
        } else {
            Issue.record("Expected media playlist")
        }
    }
}
