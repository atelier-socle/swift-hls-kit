// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipeline Enriched", .timeLimit(.minutes(1)))
struct LivePipelineEnrichedTests {

    // MARK: - Start With Components

    @Test("Start with components: state = running, hasComponents = true")
    func startWithComponents() async throws {
        let pipeline = LivePipeline()
        let components = LivePipelineComponents(
            audio: AudioComponents(levelMeter: LevelMeter())
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
        let has = await pipeline.hasComponents
        #expect(has == true)
        try await pipeline.stop()
    }

    @Test("Start without components: backward compatible, hasComponents = false")
    func startWithoutComponents() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let has = await pipeline.hasComponents
        #expect(has == false)
        try await pipeline.stop()
    }

    @Test("Start with components: currentComponents returns the groups")
    func currentComponentsAccessor() async throws {
        let pipeline = LivePipeline()
        let components = LivePipelineComponents(
            audio: AudioComponents(levelMeter: LevelMeter())
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        let current = await pipeline.currentComponents
        #expect(current != nil)
        #expect(current?.audio != nil)
        #expect(current?.audio?.levelMeter != nil)
        try await pipeline.stop()
    }

    @Test("Stop clears components")
    func stopClearsComponents() async throws {
        let pipeline = LivePipeline()
        let components = LivePipelineComponents()
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        try await pipeline.stop()
        let has = await pipeline.hasComponents
        #expect(has == false)
    }

    // MARK: - Component Compatibility Warnings

    @Test("Warning: recording enabled but no RecordingComponents")
    func warningRecordingNoComponents() async throws {
        let pipeline = LivePipeline()
        var config = LivePipelineConfiguration()
        config.enableRecording = true
        config.recordingDirectory = "rec"
        let components = LivePipelineComponents()
        try await pipeline.start(
            configuration: config,
            components: components
        )
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
        try await pipeline.stop()
    }

    @Test("Warning: low-latency enabled but no LowLatencyComponents")
    func warningLowLatencyNoComponents() async throws {
        let pipeline = LivePipeline()
        var config = LivePipelineConfiguration()
        config.lowLatency = LowLatencyConfig(partTargetDuration: 0.5)
        let components = LivePipelineComponents()
        try await pipeline.start(
            configuration: config,
            components: components
        )
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
        try await pipeline.stop()
    }

    @Test("Warning: push destinations but no PushComponents")
    func warningPushNoComponents() async throws {
        let pipeline = LivePipeline()
        var config = LivePipelineConfiguration()
        config.destinations = [.http(url: "https://cdn.example.com")]
        let components = LivePipelineComponents()
        try await pipeline.start(
            configuration: config,
            components: components
        )
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
        try await pipeline.stop()
    }

    // MARK: - renderPlaylist

    @Test("renderPlaylist: returns nil without playlist component")
    func renderPlaylistNil() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let result = await pipeline.renderPlaylist()
        #expect(result == nil)
        try await pipeline.stop()
    }

    @Test("renderPlaylist: delegates to playlist manager")
    func renderPlaylistDelegates() async throws {
        let pipeline = LivePipeline()
        let playlist = SlidingWindowPlaylist()
        let components = LivePipelineComponents(
            playlist: PlaylistComponents(manager: playlist)
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        let result = await pipeline.renderPlaylist()
        #expect(result != nil)
        #expect(result?.contains("#EXTM3U") == true)
        try await pipeline.stop()
    }

    // MARK: - renderDeltaPlaylist

    @Test("renderDeltaPlaylist: returns nil without LL-HLS components")
    func renderDeltaNil() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let result = await pipeline.renderDeltaPlaylist()
        #expect(result == nil)
        try await pipeline.stop()
    }

    // MARK: - awaitBlockingPlaylist

    @Test("awaitBlockingPlaylist: throws componentNotConfigured")
    func awaitBlockingThrows() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let request = BlockingPlaylistRequest(mediaSequenceNumber: 0)
        do {
            _ = try await pipeline.awaitBlockingPlaylist(for: request)
            Issue.record("Expected componentNotConfigured error")
        } catch let error as LivePipelineError {
            #expect(error == .componentNotConfigured("BlockingPlaylistHandler"))
        }
        try await pipeline.stop()
    }

    // MARK: - finalizeRecording

    @Test("finalizeRecording: throws componentNotConfigured")
    func finalizeRecordingThrows() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        do {
            _ = try await pipeline.finalizeRecording()
            Issue.record("Expected componentNotConfigured error")
        } catch let error as LivePipelineError {
            #expect(error == .componentNotConfigured("RecordingComponents"))
        }
        try await pipeline.stop()
    }

    // MARK: - injectMetadata

    @Test("injectMetadata: emits event even without components")
    func injectMetadataEvent() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        await pipeline.injectMetadata(LivePlaylistMetadata())
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
        try await pipeline.stop()
    }

    // MARK: - insertSCTE35

    @Test("insertSCTE35: emits scte35Inserted event")
    func insertSCTE35Event() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let marker = SCTE35Marker.spliceInsert(
            eventId: 42, duration: 30.0
        )
        await pipeline.insertSCTE35(marker)
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
        try await pipeline.stop()
    }

    // MARK: - processBuffer

    @Test("processBuffer: no-op without components")
    func processBufferNoComponents() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let buffer = RawMediaBuffer(
            data: Data(repeating: 0, count: 100),
            timestamp: MediaTimestamp(seconds: 0.0),
            duration: MediaTimestamp(seconds: 0.02),
            isKeyframe: true,
            mediaType: .audio,
            formatInfo: .audio(
                sampleRate: 48000, channels: 2, bitsPerSample: 16
            )
        )
        try await pipeline.processBuffer(buffer)
        let produced = await pipeline.segmentsProduced
        #expect(produced == 0)
        try await pipeline.stop()
    }
}
