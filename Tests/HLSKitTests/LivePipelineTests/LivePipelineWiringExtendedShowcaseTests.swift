// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipeline Wiring Extended Showcase", .timeLimit(.minutes(1)))
struct LivePipelineWiringExtendedShowcaseTests {

    // MARK: - Helpers

    private func segmentData(size: Int = 1024) -> Data {
        Data(repeating: 0xAA, count: size)
    }

    // MARK: - Full Stats

    #if canImport(AVFoundation)
        @Test("Full stats: all groups produce enriched statistics")
        func fullStatsWithComponents() async throws {
            let pipeline = LivePipeline()
            let storage = MockShowcase2Storage()
            let components = LivePipelineComponents(
                input: InputComponents(source: MockShowcase2Source()),
                encoding: EncodingComponents(encoder: AudioEncoder()),
                segmentation: SegmentationComponents(
                    segmenter: IncrementalSegmenter()
                ),
                playlist: PlaylistComponents(
                    manager: SlidingWindowPlaylist()
                ),
                recording: RecordingComponents(
                    recorder: SimultaneousRecorder(storage: storage),
                    storage: storage
                ),
                audio: AudioComponents(
                    loudnessMeter: LoudnessMeter(sampleRate: 48000, channels: 2),
                    levelMeter: LevelMeter()
                )
            )
            try await pipeline.start(
                configuration: LivePipelineConfiguration(),
                components: components
            )
            await pipeline.processSegment(
                data: segmentData(size: 2048), duration: 6.0,
                filename: "seg0.m4s"
            )
            await pipeline.processSegment(
                data: segmentData(size: 3072), duration: 6.0,
                filename: "seg1.m4s"
            )
            let stats = await pipeline.statistics
            #expect(stats.segmentsProduced == 2)
            #expect(stats.totalBytes == 5120)
            let summary = try await pipeline.stop()
            #expect(summary.segmentsProduced == 2)
        }
    #endif

    // MARK: - Live to VOD

    @Test("Live to VOD: finalizeRecording with recorder")
    func liveToVOD() async throws {
        let pipeline = LivePipeline()
        let storage = MockShowcase2Storage()
        let recorder = SimultaneousRecorder(storage: storage)
        let components = LivePipelineComponents(
            recording: RecordingComponents(
                recorder: recorder,
                storage: storage
            )
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        // Recorder must be started and have segments before finalize
        try await recorder.start()
        try await recorder.recordSegment(
            data: segmentData(), filename: "seg0.m4s", duration: 6.0
        )
        let vod = try await pipeline.finalizeRecording()
        #expect(vod.contains("#EXTM3U"))
        try await pipeline.stop()
    }

    // MARK: - Multi-Destination Push

    @Test("Multi-destination: HTTP + local pushers via components")
    func multiDestinationPush() async throws {
        let pipeline = LivePipeline()
        let components = LivePipelineComponents(
            push: PushComponents(
                destinations: [],
                multiDestinationPusher: MultiDestinationPusher(),
                bandwidthMonitor: BandwidthMonitor(
                    configuration: .standard(requiredBitrate: 128_000)
                )
            )
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        let current = await pipeline.currentComponents
        #expect(current?.push != nil)
        #expect(current?.push?.multiDestinationPusher != nil)
        #expect(current?.push?.bandwidthMonitor != nil)
        #expect(current?.push?.destinations.isEmpty == true)
        await pipeline.addDestination(
            .http(url: "https://cdn1.example.com"), id: "cdn1"
        )
        await pipeline.addDestination(
            .local(directory: "/tmp/segments"), id: "local"
        )
        let dests = await pipeline.activeDestinations
        #expect(dests.count == 2)
        try await pipeline.stop()
    }
}

// MARK: - Mock

private actor MockShowcase2Source: MediaSource {
    let mediaType: MediaSourceType = .audio
    let formatDescription = MediaFormatDescription(
        audioFormat: AudioFormat(
            codec: .aac, sampleRate: 48000, channels: 2, bitsPerSample: 16
        )
    )
    func nextSampleBuffer() async throws -> RawMediaBuffer? { nil }
    var isFinished: Bool { true }
}

private actor MockShowcase2Storage: RecordingStorage {
    var totalBytesWritten: Int { 0 }
    func writeSegment(
        data: Data, filename: String, directory: String
    ) async throws {}
    func writePlaylist(
        content: String, filename: String, directory: String
    ) async throws {}
    func writeChapters(
        content: String, filename: String, directory: String
    ) async throws {}
    func listFiles(in directory: String) async throws -> [String] { [] }
    func fileExists(
        filename: String, directory: String
    ) async -> Bool { false }
}
