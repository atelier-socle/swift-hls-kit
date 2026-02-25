// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - MockRecordingStorage

actor MockRecordingStorage: RecordingStorage {
    var files: [String: Data] = [:]
    var playlists: [String: String] = [:]
    var chapterFiles: [String: String] = [:]
    private var bytesWritten: Int = 0

    func writeSegment(data: Data, filename: String, directory: String) async throws {
        files["\(directory)/\(filename)"] = data
        bytesWritten += data.count
    }

    func writePlaylist(content: String, filename: String, directory: String) async throws {
        playlists["\(directory)/\(filename)"] = content
    }

    func writeChapters(content: String, filename: String, directory: String) async throws {
        chapterFiles["\(directory)/\(filename)"] = content
    }

    func listFiles(in directory: String) async throws -> [String] {
        files.keys.filter { $0.hasPrefix(directory) }
            .map { String($0.dropFirst(directory.count + 1)) }
    }

    func fileExists(filename: String, directory: String) async -> Bool {
        files["\(directory)/\(filename)"] != nil
    }

    var totalBytesWritten: Int { bytesWritten }
}

// MARK: - Tests

@Suite("SimultaneousRecorder", .timeLimit(.minutes(1)))
struct SimultaneousRecorderTests {

    private func makeRecorder(
        config: SimultaneousRecorder.Configuration = .standard
    ) -> (SimultaneousRecorder, MockRecordingStorage) {
        let storage = MockRecordingStorage()
        let recorder = SimultaneousRecorder(storage: storage, configuration: config)
        return (recorder, storage)
    }

    private func sampleData(size: Int = 1024) -> Data {
        Data(repeating: 0xAB, count: size)
    }

    // MARK: - State

    @Test("Initial state is idle")
    func initialState() async {
        let (recorder, _) = makeRecorder()
        let state = await recorder.state
        #expect(state == .idle)
    }

    @Test("Start transitions to recording")
    func startRecording() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        let state = await recorder.state
        #expect(state == .recording)
    }

    @Test("Cancel transitions to failed")
    func cancelRecording() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        await recorder.cancel()
        let state = await recorder.state
        #expect(state == .failed("Cancelled"))
    }

    // MARK: - Record Segment

    @Test("recordSegment writes to storage")
    func recordSegmentWritesToStorage() async throws {
        let (recorder, storage) = makeRecorder()
        try await recorder.start()
        let data = sampleData()
        try await recorder.recordSegment(data: data, filename: "seg0.ts", duration: 6.0)
        let exists = await storage.fileExists(filename: "seg0.ts", directory: "recording")
        #expect(exists)
    }

    @Test("recordSegment 5 times updates segmentCount")
    func recordMultipleSegments() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        for i in 0..<5 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        let stats = await recorder.stats
        #expect(stats.segmentCount == 5)
    }

    @Test("recordSegment accumulates totalBytes")
    func totalBytesAccumulate() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(size: 100), filename: "seg0.ts", duration: 6.0)
        try await recorder.recordSegment(data: sampleData(size: 200), filename: "seg1.ts", duration: 6.0)
        let stats = await recorder.stats
        #expect(stats.totalBytes == 300)
    }

    @Test("recordSegment accumulates totalDuration")
    func totalDurationAccumulates() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        try await recorder.recordSegment(data: sampleData(), filename: "seg1.ts", duration: 5.5)
        let stats = await recorder.stats
        #expect(abs(stats.totalDuration - 11.5) < 0.001)
    }

    // MARK: - Init Segment

    @Test("recordInitSegment writes to storage")
    func recordInitSegment() async throws {
        let (recorder, storage) = makeRecorder()
        try await recorder.start()
        try await recorder.recordInitSegment(data: sampleData(size: 512), filename: "init.mp4")
        let exists = await storage.fileExists(filename: "init.mp4", directory: "recording")
        #expect(exists)
    }

    // MARK: - Incremental Playlist

    @Test("Incremental playlist written after each segment")
    func incrementalPlaylist() async throws {
        let (recorder, storage) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        let playlist = await storage.playlists["recording/playlist.m3u8"]
        #expect(playlist != nil)
        #expect(playlist?.contains("seg0.ts") == true)
    }

    // MARK: - Finalize

    @Test("Finalize transitions to completed")
    func finalizeCompletes() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        _ = try await recorder.finalize()
        let state = await recorder.state
        #expect(state == .completed)
    }

    @Test("Finalize returns valid M3U8 with ENDLIST")
    func finalizeReturnsPlaylist() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        try await recorder.recordSegment(data: sampleData(), filename: "seg1.ts", duration: 6.0)
        let playlist = try await recorder.finalize()
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-ENDLIST"))
        #expect(playlist.contains("seg0.ts"))
        #expect(playlist.contains("seg1.ts"))
        #expect(playlist.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
    }

    // MARK: - Error Handling

    @Test("Record after finalize throws")
    func recordAfterFinalize() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        _ = try await recorder.finalize()
        do {
            try await recorder.recordSegment(data: sampleData(), filename: "seg1.ts", duration: 6.0)
            Issue.record("Expected error")
        } catch {
            #expect(error is SimultaneousRecorder.RecorderError)
        }
    }

    @Test("Record after cancel throws")
    func recordAfterCancel() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        await recorder.cancel()
        do {
            try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
            Issue.record("Expected error")
        } catch {
            #expect(error is SimultaneousRecorder.RecorderError)
        }
    }

    // MARK: - Event Playlist

    @Test("currentEventPlaylist valid M3U8 without ENDLIST")
    func currentEventPlaylist() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        let playlist = await recorder.currentEventPlaylist
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
        #expect(!playlist.contains("#EXT-X-ENDLIST"))
    }

    // MARK: - Segment Metadata

    @Test("recordedSegments returns filenames in order")
    func recordedSegments() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        for i in 0..<3 {
            try await recorder.recordSegment(
                data: sampleData(), filename: "seg\(i).ts", duration: 6.0
            )
        }
        let segments = await recorder.recordedSegments
        #expect(segments == ["seg0.ts", "seg1.ts", "seg2.ts"])
    }

    @Test("segmentMetadata has correct values")
    func segmentMetadataCorrect() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        let refDate = Date(timeIntervalSince1970: 1_740_000_000)
        try await recorder.recordSegment(
            data: sampleData(size: 500), filename: "seg0.ts",
            duration: 6.006, programDateTime: refDate
        )
        let metadata = await recorder.segmentMetadata
        #expect(metadata.count == 1)
        #expect(metadata[0].filename == "seg0.ts")
        #expect(abs(metadata[0].duration - 6.006) < 0.001)
        #expect(metadata[0].byteSize == 500)
        #expect(metadata[0].programDateTime == refDate)
    }

    // MARK: - Configuration Presets

    @Test("Configuration.standard defaults")
    func standardConfig() {
        let config = SimultaneousRecorder.Configuration.standard
        #expect(config.directory == "recording")
        #expect(config.incrementalPlaylist)
        #expect(!config.autoChapters)
    }

    @Test("Configuration.podcast preset")
    func podcastConfig() {
        let config = SimultaneousRecorder.Configuration.podcast
        #expect(config.autoChapters)
        #expect(config.directory == "podcast")
    }

    @Test("Configuration.event preset")
    func eventConfig() {
        let config = SimultaneousRecorder.Configuration.event
        #expect(config.includeProgramDateTime)
        #expect(!config.autoChapters)
    }

    // MARK: - Max Duration

    @Test("maxDuration stops recording")
    func maxDurationLimit() async throws {
        var config = SimultaneousRecorder.Configuration.standard
        config.maxDuration = 12.0
        let (recorder, _) = makeRecorder(config: config)
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        try await recorder.recordSegment(data: sampleData(), filename: "seg1.ts", duration: 6.0)
        do {
            try await recorder.recordSegment(data: sampleData(), filename: "seg2.ts", duration: 6.0)
            Issue.record("Expected maxDurationReached error")
        } catch {
            #expect(error as? SimultaneousRecorder.RecorderError == .maxDurationReached)
        }
    }

    // MARK: - Discontinuity

    @Test("Discontinuity segment produces EXT-X-DISCONTINUITY in playlist")
    func discontinuityInPlaylist() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        try await recorder.recordSegment(
            data: sampleData(), filename: "seg1.ts", duration: 6.0, isDiscontinuity: true
        )
        let playlist = await recorder.currentEventPlaylist
        #expect(playlist.contains("#EXT-X-DISCONTINUITY"))
    }

    // MARK: - Elapsed Time

    @Test("Stats elapsedTime is non-negative after start")
    func elapsedTime() async throws {
        let (recorder, _) = makeRecorder()
        try await recorder.start()
        try await recorder.recordSegment(data: sampleData(), filename: "seg0.ts", duration: 6.0)
        let stats = await recorder.stats
        #expect(stats.elapsedTime >= 0)
    }

    @Test("Stats elapsedTime is 0 before start")
    func elapsedTimeBeforeStart() async {
        let (recorder, _) = makeRecorder()
        let stats = await recorder.stats
        #expect(stats.elapsedTime == 0)
    }
}
