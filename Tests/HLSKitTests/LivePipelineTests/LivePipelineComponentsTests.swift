// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipelineComponents", .timeLimit(.minutes(1)))
struct LivePipelineComponentsTests {

    // MARK: - Empty Components

    @Test("Empty components: all groups nil")
    func emptyComponents() {
        let c = LivePipelineComponents()
        #expect(c.input == nil)
        #expect(c.encoding == nil)
        #expect(c.segmentation == nil)
        #expect(c.playlist == nil)
        #expect(c.lowLatency == nil)
        #expect(c.push == nil)
        #expect(c.metadata == nil)
        #expect(c.recording == nil)
        #expect(c.audio == nil)
    }

    // MARK: - AudioComponents

    @Test("AudioComponents: default init all nil")
    func audioComponentsDefault() {
        let audio = AudioComponents()
        #expect(audio.loudnessMeter == nil)
        #expect(audio.normalizer == nil)
        #expect(audio.silenceDetector == nil)
        #expect(audio.levelMeter == nil)
        #expect(audio.formatConverter == nil)
        #expect(audio.sampleRateConverter == nil)
        #expect(audio.channelMixer == nil)
    }

    @Test("AudioComponents: with loudness meter")
    func audioComponentsWithMeter() {
        let meter = LoudnessMeter(sampleRate: 48000, channels: 2)
        let audio = AudioComponents(loudnessMeter: meter)
        #expect(audio.loudnessMeter != nil)
    }

    @Test("AudioComponents: with all fields")
    func audioComponentsAllFields() {
        let audio = AudioComponents(
            loudnessMeter: LoudnessMeter(sampleRate: 48000, channels: 2),
            normalizer: AudioNormalizer(targetLoudness: -16.0),
            silenceDetector: SilenceDetector(),
            levelMeter: LevelMeter(),
            formatConverter: AudioFormatConverter(),
            sampleRateConverter: SampleRateConverter(),
            channelMixer: ChannelMixer()
        )
        #expect(audio.loudnessMeter != nil)
        #expect(audio.normalizer != nil)
        #expect(audio.silenceDetector != nil)
        #expect(audio.levelMeter != nil)
        #expect(audio.formatConverter != nil)
        #expect(audio.sampleRateConverter != nil)
        #expect(audio.channelMixer != nil)
    }

    // MARK: - EncodingComponents

    @Test("EncodingComponents: stores encoder")
    func encodingComponents() async {
        let encoder = AudioEncoder()
        let encoding = EncodingComponents(encoder: encoder)
        #expect(encoding.encoder is AudioEncoder)
    }

    // MARK: - SegmentationComponents

    @Test("SegmentationComponents: stores segmenter")
    func segmentationComponents() async {
        let segmenter = IncrementalSegmenter()
        let seg = SegmentationComponents(segmenter: segmenter)
        #expect(seg.segmenter is IncrementalSegmenter)
    }

    // MARK: - PlaylistComponents

    @Test("PlaylistComponents: stores manager")
    func playlistComponents() async {
        let playlist = SlidingWindowPlaylist()
        let pc = PlaylistComponents(manager: playlist)
        #expect(pc.manager is SlidingWindowPlaylist)
    }

    // MARK: - LowLatencyComponents

    @Test("LowLatencyComponents: required + optional fields")
    func lowLatencyComponents() {
        let manager = LLHLSManager()
        let handler = BlockingPlaylistHandler(manager: manager)
        let delta = DeltaUpdateGenerator(canSkipUntil: 36.0)
        let ll = LowLatencyComponents(
            manager: manager,
            blockingHandler: handler,
            deltaGenerator: delta
        )
        #expect(ll.deltaGenerator != nil)
    }

    @Test("LowLatencyComponents: deltaGenerator defaults to nil")
    func lowLatencyComponentsDefaultDelta() {
        let manager = LLHLSManager()
        let handler = BlockingPlaylistHandler(manager: manager)
        let ll = LowLatencyComponents(
            manager: manager,
            blockingHandler: handler
        )
        #expect(ll.deltaGenerator == nil)
    }

    // MARK: - PushComponents

    @Test("PushComponents: destinations array")
    func pushComponents() {
        let push = PushComponents(destinations: [])
        #expect(push.destinations.isEmpty)
        #expect(push.multiDestinationPusher == nil)
        #expect(push.bandwidthMonitor == nil)
    }

    // MARK: - MetadataComponents

    @Test("MetadataComponents: required + optional fields")
    func metadataComponents() {
        let injector = LiveMetadataInjector()
        let meta = MetadataComponents(injector: injector)
        #expect(meta.interstitialManager == nil)
        #expect(meta.dateRangeManager == nil)
    }

    @Test("MetadataComponents: with all optional fields")
    func metadataComponentsFull() {
        let injector = LiveMetadataInjector()
        let interstitialMgr = InterstitialManager()
        let dateRangeMgr = DateRangeManager()
        let meta = MetadataComponents(
            injector: injector,
            interstitialManager: interstitialMgr,
            dateRangeManager: dateRangeMgr
        )
        #expect(meta.interstitialManager != nil)
        #expect(meta.dateRangeManager != nil)
    }

    // MARK: - RecordingComponents

    @Test("RecordingComponents: required + optional fields")
    func recordingComponents() {
        let storage = MockComponentStorage()
        let recorder = SimultaneousRecorder(storage: storage)
        let rec = RecordingComponents(
            recorder: recorder,
            storage: storage
        )
        #expect(rec.chapterGenerator == nil)
        #expect(rec.vodConverter == nil)
        #expect(rec.iframeGenerator == nil)
        #expect(rec.thumbnailExtractor == nil)
        #expect(rec.imageProvider == nil)
    }

    @Test("RecordingComponents: with optional chapter generator")
    func recordingComponentsWithChapters() {
        let storage = MockComponentStorage()
        let recorder = SimultaneousRecorder(storage: storage)
        let rec = RecordingComponents(
            recorder: recorder,
            storage: storage,
            chapterGenerator: AutoChapterGenerator()
        )
        #expect(rec.chapterGenerator != nil)
    }

    // MARK: - InputComponents

    @Test("InputComponents: stores source")
    func inputComponents() async {
        let source = MockMediaSource()
        let input = InputComponents(source: source)
        #expect(input.source is MockMediaSource)
    }

    // MARK: - Full Podcast Components

    @Test("Full podcast: input + encoding + segmentation + playlist + audio")
    func fullPodcastComponents() async {
        let components = LivePipelineComponents(
            input: InputComponents(source: MockMediaSource()),
            encoding: EncodingComponents(encoder: AudioEncoder()),
            segmentation: SegmentationComponents(
                segmenter: IncrementalSegmenter()
            ),
            playlist: PlaylistComponents(
                manager: SlidingWindowPlaylist()
            ),
            audio: AudioComponents(
                loudnessMeter: LoudnessMeter(sampleRate: 48000, channels: 2),
                normalizer: AudioNormalizer(targetLoudness: -16.0)
            )
        )
        #expect(components.input != nil)
        #expect(components.encoding != nil)
        #expect(components.segmentation != nil)
        #expect(components.playlist != nil)
        #expect(components.lowLatency == nil)
        #expect(components.push == nil)
        #expect(components.metadata == nil)
        #expect(components.recording == nil)
        #expect(components.audio != nil)
    }

    // MARK: - Full Video LL-HLS Components

    @Test("Full video LL-HLS: all 9 groups populated")
    func fullVideoLLHLSComponents() async {
        let llhls = LLHLSManager()
        let handler = BlockingPlaylistHandler(manager: llhls)
        let storage = MockComponentStorage()
        let components = LivePipelineComponents(
            input: InputComponents(source: MockMediaSource()),
            encoding: EncodingComponents(encoder: AudioEncoder()),
            segmentation: SegmentationComponents(
                segmenter: IncrementalSegmenter()
            ),
            playlist: PlaylistComponents(
                manager: SlidingWindowPlaylist()
            ),
            lowLatency: LowLatencyComponents(
                manager: llhls,
                blockingHandler: handler
            ),
            push: PushComponents(destinations: []),
            metadata: MetadataComponents(injector: LiveMetadataInjector()),
            recording: RecordingComponents(
                recorder: SimultaneousRecorder(storage: storage),
                storage: storage
            ),
            audio: AudioComponents(levelMeter: LevelMeter())
        )
        #expect(components.input != nil)
        #expect(components.encoding != nil)
        #expect(components.segmentation != nil)
        #expect(components.playlist != nil)
        #expect(components.lowLatency != nil)
        #expect(components.push != nil)
        #expect(components.metadata != nil)
        #expect(components.recording != nil)
        #expect(components.audio != nil)
    }

    // MARK: - AudioProcessingSettings

    @Test("AudioProcessingSettings: default values")
    func audioProcessingDefaults() {
        let settings = AudioProcessingSettings()
        #expect(settings.targetLoudness == nil)
        #expect(settings.silenceDetection == false)
        #expect(settings.silenceThreshold == -50.0)
        #expect(settings.silenceMinDuration == 3.0)
        #expect(settings.levelMetering == false)
        #expect(settings.loudnessMetering == false)
    }

    @Test("AudioProcessingSettings: podcast preset")
    func audioProcessingPodcast() {
        let settings = AudioProcessingSettings.podcast
        #expect(settings.targetLoudness == -16.0)
        #expect(settings.silenceDetection == true)
        #expect(settings.loudnessMetering == true)
    }

    @Test("AudioProcessingSettings: broadcast preset")
    func audioProcessingBroadcast() {
        let settings = AudioProcessingSettings.broadcast
        #expect(settings.targetLoudness == -23.0)
        #expect(settings.silenceDetection == true)
        #expect(settings.levelMetering == true)
        #expect(settings.loudnessMetering == true)
    }

    @Test("AudioProcessingSettings: music preset")
    func audioProcessingMusic() {
        let settings = AudioProcessingSettings.music
        #expect(settings.targetLoudness == nil)
        #expect(settings.silenceDetection == false)
        #expect(settings.levelMetering == true)
        #expect(settings.loudnessMetering == false)
    }

    @Test("AudioProcessingSettings: equatable")
    func audioProcessingEquatable() {
        #expect(AudioProcessingSettings.podcast == AudioProcessingSettings.podcast)
        #expect(AudioProcessingSettings.podcast != AudioProcessingSettings.broadcast)
        #expect(AudioProcessingSettings.broadcast != AudioProcessingSettings.music)
    }

    @Test("Presets with audioProcessing: podcastLive, broadcast, djMix")
    func presetsWithAudioProcessing() {
        #expect(
            LivePipelineConfiguration.podcastLive.audioProcessing == .podcast
        )
        #expect(
            LivePipelineConfiguration.broadcast.audioProcessing == .broadcast
        )
        #expect(LivePipelineConfiguration.djMix.audioProcessing == .music)
    }

    @Test("Presets without audioProcessing: webradio, videoLive")
    func presetsWithoutAudioProcessing() {
        #expect(LivePipelineConfiguration.webradio.audioProcessing == nil)
        #expect(LivePipelineConfiguration.videoLive.audioProcessing == nil)
        #expect(LivePipelineConfiguration.lowBandwidth.audioProcessing == nil)
    }
}

// MARK: - Mock

private actor MockMediaSource: MediaSource {
    let mediaType: MediaSourceType = .audio
    let formatDescription = MediaFormatDescription(
        audioFormat: AudioFormat(
            codec: .aac, sampleRate: 48000, channels: 2, bitsPerSample: 16
        )
    )
    func nextSampleBuffer() async throws -> RawMediaBuffer? { nil }
    var isFinished: Bool { true }
}

private actor MockComponentStorage: RecordingStorage {
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
    func fileExists(filename: String, directory: String) async -> Bool { false }
}
