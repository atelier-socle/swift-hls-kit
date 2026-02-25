// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Recording Integration", .timeLimit(.minutes(1)))
struct RecordingIntegrationTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    private func makeStorage() -> MockRecordingStorage {
        MockRecordingStorage()
    }

    private func sampleData(size: Int = 1024) -> Data {
        Data(repeating: 0xAB, count: size)
    }

    // MARK: - Full Pipeline

    @Test("Record 10 segments → finalize → convert to VOD → valid M3U8")
    func fullPipeline() async throws {
        let storage = makeStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        for i in 0..<10 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.006
            )
        }
        let finalPlaylist = try await recorder.finalize()
        #expect(finalPlaylist.contains("#EXT-X-ENDLIST"))
        let converter = LiveToVODConverter()
        let metadata = await recorder.segmentMetadata
        let vod = converter.convert(segments: metadata, options: .podcast)
        #expect(vod.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        #expect(vod.contains("seg0.ts"))
        #expect(vod.contains("#EXT-X-ENDLIST"))
    }

    // MARK: - Auto Chapters

    @Test("Record with metadata changes → chapters in JSON")
    func recordWithAutoChapters() async throws {
        let storage = makeStorage()
        let recorder = SimultaneousRecorder(
            storage: storage, configuration: .podcast
        )
        try await recorder.start()
        var chapterGen = AutoChapterGenerator()
        chapterGen.addMetadataChange(at: 0.0, title: "Introduction")
        for i in 0..<5 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        chapterGen.addMetadataChange(at: 30.0, title: "Main Topic")
        for i in 5..<10 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        chapterGen.finalize(totalDuration: 60.0)
        let json = chapterGen.generateJSON()
        #expect(json.contains("Introduction"))
        #expect(json.contains("Main Topic"))
    }

    // MARK: - Discontinuity

    @Test("Discontinuity preserved in archive mode")
    func discontinuityArchive() async throws {
        let storage = makeStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg0.ts", duration: 6.0
        )
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg1.ts", duration: 6.0, isDiscontinuity: true
        )
        _ = try await recorder.finalize()
        let metadata = await recorder.segmentMetadata
        let converter = LiveToVODConverter()
        let vod = converter.convert(segments: metadata, options: .archive)
        #expect(vod.contains("#EXT-X-DISCONTINUITY"))
    }

    @Test("Discontinuity removed in podcast mode")
    func discontinuityPodcast() async throws {
        let storage = makeStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg0.ts", duration: 6.0
        )
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg1.ts", duration: 6.0, isDiscontinuity: true
        )
        _ = try await recorder.finalize()
        let metadata = await recorder.segmentMetadata
        let converter = LiveToVODConverter()
        let vod = converter.convert(segments: metadata, options: .podcast)
        #expect(!vod.contains("#EXT-X-DISCONTINUITY"))
    }

    // MARK: - fMP4

    @Test("Record fMP4 with init segment → EXT-X-MAP in VOD")
    func fmp4Recording() async throws {
        let storage = makeStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        try await recorder.recordInitSegment(data: sampleData(size: 256), filename: "init.mp4")
        for i in 0..<3 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).m4s", duration: 6.0
            )
        }
        let playlist = try await recorder.finalize()
        #expect(playlist.contains("#EXT-X-MAP:URI=\"init.mp4\""))
    }

    // MARK: - Stats Accuracy

    @Test("Stats: segmentCount, totalBytes, totalDuration all correct")
    func statsAccuracy() async throws {
        let storage = makeStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        for i in 0..<5 {
            try await recorder.recordSegment(
                data: sampleData(size: 200), filename: "seg\(i).ts", duration: 6.0
            )
        }
        let stats = await recorder.stats
        #expect(stats.segmentCount == 5)
        #expect(stats.totalBytes == 1000)
        #expect(abs(stats.totalDuration - 30.0) < 0.001)
        #expect(stats.startDate != nil)
    }

    // MARK: - VOD Round-Trip

    @Test("VOD playlist round-trip: generate → parse → segments match")
    func vodRoundTrip() async throws {
        let storage = makeStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        for i in 0..<3 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.006
            )
        }
        _ = try await recorder.finalize()
        let metadata = await recorder.segmentMetadata
        let converter = LiveToVODConverter()
        let vod = converter.convert(segments: metadata)
        let parser = ManifestParser()
        let manifest = try parser.parse(vod)
        if case .media(let mediaPlaylist) = manifest {
            #expect(mediaPlaylist.segments.count == 3)
            #expect(mediaPlaylist.hasEndList)
            #expect(mediaPlaylist.playlistType == .vod)
        } else {
            Issue.record("Expected media playlist")
        }
    }

    // MARK: - Chapter WebVTT

    @Test("Chapter WebVTT has valid timestamps")
    func chapterWebVTT() {
        var gen = AutoChapterGenerator()
        gen.addMetadataChange(at: 0.0, title: "Start")
        gen.addMetadataChange(at: 120.0, title: "Middle")
        gen.addMetadataChange(at: 300.0, title: "End")
        gen.finalize(totalDuration: 600.0)
        let vtt = gen.generateWebVTT()
        #expect(vtt.contains("00:00:00.000 --> 00:02:00.000"))
        #expect(vtt.contains("00:02:00.000 --> 00:05:00.000"))
        #expect(vtt.contains("00:05:00.000 --> 00:10:00.000"))
    }

    // MARK: - Long Recording

    @Test("Long recording: 100 segments stable")
    func longRecording() async throws {
        let storage = makeStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
        try await recorder.start()
        for i in 0..<100 {
            try await recorder.recordSegment(
                data: sampleData(size: 50), filename: "seg\(i).ts", duration: 6.0
            )
        }
        let stats = await recorder.stats
        #expect(stats.segmentCount == 100)
        #expect(stats.totalBytes == 5000)
        let playlist = try await recorder.finalize()
        #expect(playlist.contains("seg99.ts"))
    }
}
