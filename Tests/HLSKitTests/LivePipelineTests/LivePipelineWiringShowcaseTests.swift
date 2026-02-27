// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipeline Wiring Showcase", .timeLimit(.minutes(1)))
struct LivePipelineWiringShowcaseTests {

    // MARK: - Podcast Pipeline

    #if canImport(AVFoundation)
        @Test("Podcast: input + encoding + segmentation + playlist + audio")
        func podcastPipeline() async throws {
            let pipeline = LivePipeline()
            let components = LivePipelineComponents(
                input: InputComponents(source: MockShowcaseSource()),
                encoding: EncodingComponents(encoder: AudioEncoder()),
                segmentation: SegmentationComponents(
                    segmenter: IncrementalSegmenter()
                ),
                playlist: PlaylistComponents(
                    manager: SlidingWindowPlaylist()
                ),
                audio: AudioComponents(
                    loudnessMeter: LoudnessMeter(sampleRate: 48000, channels: 2),
                    normalizer: AudioNormalizer(targetLoudness: -16.0),
                    levelMeter: LevelMeter()
                )
            )
            try await pipeline.start(
                configuration: .podcastLive,
                components: components
            )
            let has = await pipeline.hasComponents
            #expect(has == true)
            let current = await pipeline.currentComponents
            #expect(current?.input != nil)
            #expect(current?.encoding != nil)
            #expect(current?.segmentation != nil)
            #expect(current?.playlist != nil)
            #expect(current?.audio != nil)
            #expect(current?.audio?.loudnessMeter != nil)
            #expect(current?.audio?.normalizer != nil)
            #expect(current?.audio?.levelMeter != nil)
            let hasLevel = await pipeline.hasLevelMeter
            #expect(hasLevel == true)
            try await pipeline.stop()
        }

        // MARK: - Video Live Pipeline

        @Test("Video live: input + encoding + segmentation + playlist + push")
        func videoLivePipeline() async throws {
            let pipeline = LivePipeline()
            let components = LivePipelineComponents(
                input: InputComponents(source: MockShowcaseSource()),
                encoding: EncodingComponents(encoder: AudioEncoder()),
                segmentation: SegmentationComponents(
                    segmenter: IncrementalSegmenter()
                ),
                playlist: PlaylistComponents(
                    manager: SlidingWindowPlaylist()
                ),
                push: PushComponents(
                    destinations: [],
                    multiDestinationPusher: MultiDestinationPusher()
                )
            )
            try await pipeline.start(
                configuration: .videoLive,
                components: components
            )
            let current = await pipeline.currentComponents
            #expect(current?.push != nil)
            #expect(current?.push?.multiDestinationPusher != nil)
            try await pipeline.stop()
        }

        // MARK: - LL-HLS Pipeline

        @Test("LL-HLS: all groups + low latency + blocking handler")
        func llhlsPipeline() async throws {
            let pipeline = LivePipeline()
            let llhls = LLHLSManager()
            let handler = BlockingPlaylistHandler(manager: llhls)
            let delta = DeltaUpdateGenerator(canSkipUntil: 36.0)
            let storage = MockShowcaseStorage()
            let components = LivePipelineComponents(
                input: InputComponents(source: MockShowcaseSource()),
                encoding: EncodingComponents(encoder: AudioEncoder()),
                segmentation: SegmentationComponents(
                    segmenter: IncrementalSegmenter()
                ),
                playlist: PlaylistComponents(
                    manager: SlidingWindowPlaylist()
                ),
                lowLatency: LowLatencyComponents(
                    manager: llhls,
                    blockingHandler: handler,
                    deltaGenerator: delta
                ),
                push: PushComponents(destinations: []),
                metadata: MetadataComponents(
                    injector: LiveMetadataInjector()
                ),
                recording: RecordingComponents(
                    recorder: SimultaneousRecorder(storage: storage),
                    storage: storage
                ),
                audio: AudioComponents(levelMeter: LevelMeter())
            )
            try await pipeline.start(
                configuration: LivePipelineConfiguration(),
                components: components
            )
            let current = await pipeline.currentComponents
            #expect(current?.lowLatency != nil)
            #expect(current?.lowLatency?.deltaGenerator != nil)
            #expect(current?.lowLatency?.blockingHandler != nil)
            try await pipeline.stop()
        }
    #endif

    // MARK: - Broadcast with DVR

    @Test("Broadcast: DVR playlist + recording + broadcast audio")
    func broadcastWithDVR() async throws {
        let pipeline = LivePipeline()
        let storage = MockShowcaseStorage()
        let components = LivePipelineComponents(
            playlist: PlaylistComponents(
                manager: DVRPlaylist()
            ),
            recording: RecordingComponents(
                recorder: SimultaneousRecorder(storage: storage),
                storage: storage
            ),
            audio: AudioComponents(
                loudnessMeter: LoudnessMeter(sampleRate: 48000, channels: 2),
                normalizer: AudioNormalizer(targetLoudness: -23.0),
                silenceDetector: SilenceDetector(),
                levelMeter: LevelMeter()
            )
        )
        try await pipeline.start(
            configuration: .broadcast,
            components: components
        )
        let hasSilence = await pipeline.hasSilenceDetector
        #expect(hasSilence == true)
        let hasLevel = await pipeline.hasLevelMeter
        #expect(hasLevel == true)
        try await pipeline.stop()
    }

    // MARK: - DJ Set

    @Test("DJ set: event playlist + recording + level meter")
    func djSetPipeline() async throws {
        let pipeline = LivePipeline()
        let storage = MockShowcaseStorage()
        let components = LivePipelineComponents(
            playlist: PlaylistComponents(
                manager: SlidingWindowPlaylist()
            ),
            recording: RecordingComponents(
                recorder: SimultaneousRecorder(storage: storage),
                storage: storage,
                chapterGenerator: AutoChapterGenerator()
            ),
            audio: AudioComponents(levelMeter: LevelMeter())
        )
        try await pipeline.start(
            configuration: .djMix,
            components: components
        )
        let current = await pipeline.currentComponents
        #expect(current?.recording != nil)
        #expect(current?.recording?.chapterGenerator != nil)
        let hasLevel = await pipeline.hasLevelMeter
        #expect(hasLevel == true)
        try await pipeline.stop()
    }

    // MARK: - Ad Insertion

    @Test("Ad insertion: insertInterstitial + insertSCTE35 emit events")
    func adInsertionEvents() async throws {
        let pipeline = LivePipeline()
        let dateRange = DateRangeManager()
        let interstitialMgr = InterstitialManager(
            dateRangeManager: dateRange
        )
        let components = LivePipelineComponents(
            metadata: MetadataComponents(
                injector: LiveMetadataInjector(),
                interstitialManager: interstitialMgr,
                dateRangeManager: dateRange
            )
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        let interstitial = HLSInterstitial(
            id: "ad-break-1",
            startDate: Date(),
            assetURI: "https://cdn.example.com/ad.m3u8",
            duration: 30.0
        )
        await pipeline.insertInterstitial(interstitial)
        let marker = SCTE35Marker.spliceInsert(
            eventId: 100, duration: 30.0
        )
        await pipeline.insertSCTE35(marker)
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
        try await pipeline.stop()
    }

    // MARK: - Silence Monitoring

    @Test("Silence monitoring: detector configured via components")
    func silenceMonitoring() async throws {
        let pipeline = LivePipeline()
        let components = LivePipelineComponents(
            audio: AudioComponents(
                silenceDetector: SilenceDetector(
                    thresholdDB: -50, minimumDuration: 3.0
                )
            )
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        let hasSilence = await pipeline.hasSilenceDetector
        #expect(hasSilence == true)
        let current = await pipeline.currentComponents
        #expect(current?.audio?.silenceDetector != nil)
        try await pipeline.stop()
    }
}

// MARK: - Mock

private actor MockShowcaseSource: MediaSource {
    let mediaType: MediaSourceType = .audio
    let formatDescription = MediaFormatDescription(
        audioFormat: AudioFormat(
            codec: .aac, sampleRate: 48000, channels: 2, bitsPerSample: 16
        )
    )
    func nextSampleBuffer() async throws -> RawMediaBuffer? { nil }
    var isFinished: Bool { true }
}

private actor MockShowcaseStorage: RecordingStorage {
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
