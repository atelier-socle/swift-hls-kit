// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - LivePipelineComponents

/// Dependency injection container for LivePipeline.
///
/// Components are grouped by responsibility. Each group is optional —
/// only configure the groups your pipeline needs.
///
/// ## Example: Podcast Live
/// ```swift
/// let components = LivePipelineComponents(
///     input: .init(source: micSource),
///     encoding: .init(encoder: aacEncoder),
///     segmentation: .init(segmenter: audioSegmenter),
///     playlist: .init(manager: slidingWindow),
///     push: .init(destinations: [httpPusher]),
///     audio: .init(loudnessMeter: meter, normalizer: normalizer)
/// )
/// ```
///
/// ## Example: Video Live with LL-HLS
/// ```swift
/// let components = LivePipelineComponents(
///     input: .init(source: cameraSource),
///     encoding: .init(encoder: h264Encoder),
///     segmentation: .init(segmenter: videoSegmenter),
///     playlist: .init(manager: slidingWindow),
///     lowLatency: .init(manager: llhlsManager, blockingHandler: handler),
///     push: .init(destinations: [httpPusher, rtmpPusher])
/// )
/// ```
public struct LivePipelineComponents: Sendable {

    /// Input source components (Phase 8).
    public var input: InputComponents?

    /// Encoding components (Phase 8).
    public var encoding: EncodingComponents?

    /// Segmentation components (Phase 9).
    public var segmentation: SegmentationComponents?

    /// Playlist management components (Phase 10).
    public var playlist: PlaylistComponents?

    /// Low-Latency HLS components (Phase 11).
    public var lowLatency: LowLatencyComponents?

    /// Push delivery components (Phase 12).
    public var push: PushComponents?

    /// Metadata injection components (Phase 13).
    public var metadata: MetadataComponents?

    /// Recording components (Phase 14).
    public var recording: RecordingComponents?

    /// Audio processing components (Phase 15).
    public var audio: AudioComponents?

    /// Spatial audio components (Phase 19). Nil if not configured.
    public var spatialAudio: SpatialAudioComponents?

    /// HDR video components (Phase 20). Nil if not configured.
    public var hdr: HDRComponents?

    /// DRM components (Phase 21). Nil if not configured.
    public var drm: DRMComponents?

    /// Accessibility components (Phase 22). Nil if not configured.
    public var accessibility: AccessibilityComponents?

    /// Resilience components (Phase 22). Nil if not configured.
    public var resilience: ResilienceComponents?

    /// Creates a components container with the given groups.
    ///
    /// All parameters default to nil — configure only what your pipeline needs.
    public init(
        input: InputComponents? = nil,
        encoding: EncodingComponents? = nil,
        segmentation: SegmentationComponents? = nil,
        playlist: PlaylistComponents? = nil,
        lowLatency: LowLatencyComponents? = nil,
        push: PushComponents? = nil,
        metadata: MetadataComponents? = nil,
        recording: RecordingComponents? = nil,
        audio: AudioComponents? = nil,
        spatialAudio: SpatialAudioComponents? = nil,
        hdr: HDRComponents? = nil,
        drm: DRMComponents? = nil,
        accessibility: AccessibilityComponents? = nil,
        resilience: ResilienceComponents? = nil
    ) {
        self.input = input
        self.encoding = encoding
        self.segmentation = segmentation
        self.playlist = playlist
        self.lowLatency = lowLatency
        self.push = push
        self.metadata = metadata
        self.recording = recording
        self.audio = audio
        self.spatialAudio = spatialAudio
        self.hdr = hdr
        self.drm = drm
        self.accessibility = accessibility
        self.resilience = resilience
    }
}

// MARK: - InputComponents (Phase 8)

/// Media input source for the pipeline.
public struct InputComponents: Sendable {

    /// Media source providing raw audio/video buffers.
    public let source: any MediaSource

    /// Creates input components with the given source.
    ///
    /// - Parameter source: Media source providing raw audio/video buffers.
    public init(source: any MediaSource) {
        self.source = source
    }
}

// MARK: - EncodingComponents (Phase 8)

/// Real-time encoding for the pipeline.
public struct EncodingComponents: Sendable {

    /// Primary encoder (audio or video).
    public let encoder: any LiveEncoder

    /// Creates encoding components with the given encoder.
    ///
    /// - Parameter encoder: Primary encoder (audio or video).
    public init(encoder: any LiveEncoder) {
        self.encoder = encoder
    }
}

// MARK: - SegmentationComponents (Phase 9)

/// Segmentation layer cutting encoded frames into HLS segments.
public struct SegmentationComponents: Sendable {

    /// Segmenter producing LiveSegment objects.
    public let segmenter: any LiveSegmenter

    /// Creates segmentation components with the given segmenter.
    ///
    /// - Parameter segmenter: Segmenter producing LiveSegment objects.
    public init(segmenter: any LiveSegmenter) {
        self.segmenter = segmenter
    }
}

// MARK: - PlaylistComponents (Phase 10)

/// Live playlist management.
public struct PlaylistComponents: Sendable {

    /// Playlist manager maintaining live M3U8.
    public let manager: any LivePlaylistManager

    /// Creates playlist components with the given manager.
    ///
    /// - Parameter manager: Playlist manager maintaining live M3U8.
    public init(manager: any LivePlaylistManager) {
        self.manager = manager
    }
}

// MARK: - LowLatencyComponents (Phase 11)

/// Low-Latency HLS components for sub-second delivery.
public struct LowLatencyComponents: Sendable {

    /// LL-HLS manager handling partial segments, preload hints, server control.
    public let manager: LLHLSManager

    /// Blocking playlist handler for LL-HLS client requests.
    public let blockingHandler: BlockingPlaylistHandler

    /// Delta update generator for `_HLS_skip` requests (optional).
    public var deltaGenerator: DeltaUpdateGenerator?

    /// Creates low-latency components.
    ///
    /// - Parameters:
    ///   - manager: LL-HLS manager.
    ///   - blockingHandler: Blocking playlist handler.
    ///   - deltaGenerator: Optional delta update generator.
    public init(
        manager: LLHLSManager,
        blockingHandler: BlockingPlaylistHandler,
        deltaGenerator: DeltaUpdateGenerator? = nil
    ) {
        self.manager = manager
        self.blockingHandler = blockingHandler
        self.deltaGenerator = deltaGenerator
    }
}

// MARK: - PushComponents (Phase 12)

/// Segment push delivery to CDN/origin servers.
public struct PushComponents: Sendable {

    /// Push destinations (HTTP, RTMP, SRT, Icecast).
    public let destinations: [any SegmentPusher]

    /// Multi-destination pusher wrapping all destinations (optional).
    public var multiDestinationPusher: MultiDestinationPusher?

    /// Bandwidth monitor for push quality tracking (optional).
    public var bandwidthMonitor: BandwidthMonitor?

    /// Creates push components.
    ///
    /// - Parameters:
    ///   - destinations: Push destinations.
    ///   - multiDestinationPusher: Optional multi-destination pusher.
    ///   - bandwidthMonitor: Optional bandwidth monitor.
    public init(
        destinations: [any SegmentPusher],
        multiDestinationPusher: MultiDestinationPusher? = nil,
        bandwidthMonitor: BandwidthMonitor? = nil
    ) {
        self.destinations = destinations
        self.multiDestinationPusher = multiDestinationPusher
        self.bandwidthMonitor = bandwidthMonitor
    }
}

// MARK: - MetadataComponents (Phase 13)

/// Timed metadata injection for the live stream.
public struct MetadataComponents: Sendable {

    /// Metadata injector orchestrating PDT, DATERANGE, ID3 per segment.
    public let injector: LiveMetadataInjector

    /// Interstitial manager for HLS Interstitials / ad insertion (optional).
    public var interstitialManager: InterstitialManager?

    /// Date range manager for DATERANGE lifecycle (optional).
    public var dateRangeManager: DateRangeManager?

    /// Creates metadata components.
    ///
    /// - Parameters:
    ///   - injector: Metadata injector.
    ///   - interstitialManager: Optional interstitial manager.
    ///   - dateRangeManager: Optional date range manager.
    public init(
        injector: LiveMetadataInjector,
        interstitialManager: InterstitialManager? = nil,
        dateRangeManager: DateRangeManager? = nil
    ) {
        self.injector = injector
        self.interstitialManager = interstitialManager
        self.dateRangeManager = dateRangeManager
    }
}

// MARK: - RecordingComponents (Phase 14)

/// Recording and post-production components.
public struct RecordingComponents: Sendable {

    /// Simultaneous recorder for live-to-VOD.
    public let recorder: SimultaneousRecorder

    /// Storage backend for recorded segments.
    public let storage: any RecordingStorage

    /// Auto chapter generator (optional).
    public var chapterGenerator: AutoChapterGenerator?

    /// Live-to-VOD converter (optional).
    public var vodConverter: LiveToVODConverter?

    /// I-frame playlist generator for trick play (optional).
    public var iframeGenerator: IFramePlaylistGenerator?

    /// Thumbnail extractor for preview images (optional).
    public var thumbnailExtractor: ThumbnailExtractor?

    /// Image provider for platform-specific thumbnail extraction (optional).
    public var imageProvider: (any ThumbnailImageProvider)?

    /// Creates recording components.
    ///
    /// - Parameters:
    ///   - recorder: Simultaneous recorder.
    ///   - storage: Storage backend.
    ///   - chapterGenerator: Optional auto chapter generator.
    ///   - vodConverter: Optional live-to-VOD converter.
    ///   - iframeGenerator: Optional I-frame playlist generator.
    ///   - thumbnailExtractor: Optional thumbnail extractor.
    ///   - imageProvider: Optional thumbnail image provider.
    public init(
        recorder: SimultaneousRecorder,
        storage: any RecordingStorage,
        chapterGenerator: AutoChapterGenerator? = nil,
        vodConverter: LiveToVODConverter? = nil,
        iframeGenerator: IFramePlaylistGenerator? = nil,
        thumbnailExtractor: ThumbnailExtractor? = nil,
        imageProvider: (any ThumbnailImageProvider)? = nil
    ) {
        self.recorder = recorder
        self.storage = storage
        self.chapterGenerator = chapterGenerator
        self.vodConverter = vodConverter
        self.iframeGenerator = iframeGenerator
        self.thumbnailExtractor = thumbnailExtractor
        self.imageProvider = imageProvider
    }
}

// MARK: - AudioComponents (Phase 15)

/// Audio processing helpers for live audio quality.
///
/// All fields are optional — configure only what your pipeline needs.
public struct AudioComponents: Sendable {

    /// Loudness meter for real-time LUFS monitoring.
    public var loudnessMeter: LoudnessMeter?

    /// Audio normalizer for target loudness.
    public var normalizer: AudioNormalizer?

    /// Silence detector for dead air detection.
    public var silenceDetector: SilenceDetector?

    /// Level meter for real-time peak/RMS monitoring.
    public var levelMeter: LevelMeter?

    /// Audio format converter (PCM bit depth, interleaved/planar).
    public var formatConverter: AudioFormatConverter?

    /// Sample rate converter.
    public var sampleRateConverter: SampleRateConverter?

    /// Channel mixer (mono/stereo, surround downmix).
    public var channelMixer: ChannelMixer?

    /// Creates audio components.
    ///
    /// All parameters default to nil — configure only what your pipeline needs.
    public init(
        loudnessMeter: LoudnessMeter? = nil,
        normalizer: AudioNormalizer? = nil,
        silenceDetector: SilenceDetector? = nil,
        levelMeter: LevelMeter? = nil,
        formatConverter: AudioFormatConverter? = nil,
        sampleRateConverter: SampleRateConverter? = nil,
        channelMixer: ChannelMixer? = nil
    ) {
        self.loudnessMeter = loudnessMeter
        self.normalizer = normalizer
        self.silenceDetector = silenceDetector
        self.levelMeter = levelMeter
        self.formatConverter = formatConverter
        self.sampleRateConverter = sampleRateConverter
        self.channelMixer = channelMixer
    }
}

// MARK: - SpatialAudioComponents (Phase 19)

/// Spatial audio encoding components.
public struct SpatialAudioComponents: Sendable {

    /// Spatial audio encoder (Atmos, AC-3, E-AC-3).
    public var encoder: (any SpatialAudioEncoder)?

    /// Spatial rendition generator.
    public var renditionGenerator: SpatialRenditionGenerator?

    /// Creates spatial audio components.
    ///
    /// - Parameters:
    ///   - encoder: Optional spatial audio encoder.
    ///   - renditionGenerator: Optional spatial rendition generator.
    public init(
        encoder: (any SpatialAudioEncoder)? = nil,
        renditionGenerator: SpatialRenditionGenerator? = nil
    ) {
        self.encoder = encoder
        self.renditionGenerator = renditionGenerator
    }
}

// MARK: - HDRComponents (Phase 20)

/// HDR video components.
public struct HDRComponents: Sendable {

    /// Video range mapper for HLS attributes.
    public var rangeMapper: VideoRangeMapper?

    /// HDR variant generator.
    public var variantGenerator: HDRVariantGenerator?

    /// Creates HDR components.
    ///
    /// - Parameters:
    ///   - rangeMapper: Optional video range mapper.
    ///   - variantGenerator: Optional HDR variant generator.
    public init(
        rangeMapper: VideoRangeMapper? = nil,
        variantGenerator: HDRVariantGenerator? = nil
    ) {
        self.rangeMapper = rangeMapper
        self.variantGenerator = variantGenerator
    }
}

// MARK: - DRMComponents (Phase 21)

/// DRM components.
public struct DRMComponents: Sendable {

    /// Session key manager for master playlist.
    public var sessionKeyManager: SessionKeyManager?

    /// Creates DRM components.
    ///
    /// - Parameter sessionKeyManager: Optional session key manager.
    public init(sessionKeyManager: SessionKeyManager? = nil) {
        self.sessionKeyManager = sessionKeyManager
    }
}

// MARK: - AccessibilityComponents (Phase 22)

/// Accessibility components for captions, subtitles, and audio descriptions.
public struct AccessibilityComponents: Sendable {

    /// Rendition generator for captions, subtitles, audio descriptions.
    public var renditionGenerator: AccessibilityRenditionGenerator?

    /// WebVTT writer segment duration. Created at runtime.
    public var webVTTSegmentDuration: TimeInterval?

    /// Creates accessibility components.
    ///
    /// - Parameters:
    ///   - renditionGenerator: Optional accessibility rendition generator.
    ///   - webVTTSegmentDuration: Optional WebVTT segment duration.
    public init(
        renditionGenerator: AccessibilityRenditionGenerator? = nil,
        webVTTSegmentDuration: TimeInterval? = nil
    ) {
        self.renditionGenerator = renditionGenerator
        self.webVTTSegmentDuration = webVTTSegmentDuration
    }
}

// MARK: - ResilienceComponents (Phase 22)

/// Resilience components for gap handling and failover.
public struct ResilienceComponents: Sendable {

    /// Gap handler for live playlists.
    public var gapHandler: GapHandler?

    /// Failover manager for redundant streams.
    public var failoverManager: FailoverManager?

    /// Creates resilience components.
    ///
    /// - Parameters:
    ///   - gapHandler: Optional gap handler.
    ///   - failoverManager: Optional failover manager.
    public init(
        gapHandler: GapHandler? = nil,
        failoverManager: FailoverManager? = nil
    ) {
        self.gapHandler = gapHandler
        self.failoverManager = failoverManager
    }
}
