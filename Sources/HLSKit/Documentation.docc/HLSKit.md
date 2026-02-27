# ``HLSKit``

@Metadata {
    @DisplayName("HLSKit")
}

A pure Swift library for the full HLS pipeline — VOD packaging and complete live streaming, from audio/video input to encrypted segment delivery.

## Overview

**HLSKit** is the first pure Swift HLS library with zero external dependencies in its core. It covers the full HLS pipeline — manifest parsing, generation, validation, segmentation, transcoding, encryption, and a complete live streaming pipeline with Low-Latency HLS, multi-destination push, timed metadata, DRM, spatial audio, HDR, and accessibility. Strict `Sendable` conformance throughout. 4478 tests, 31 industry standards covered.

```swift
import HLSKit

let engine = HLSEngine()

// Parse a manifest
let manifest = try engine.parse(m3u8String)

// Validate against RFC 8216
let report = engine.validate(manifest)
print("Valid: \(report.isValid)")

// Generate an HLS manifest
let output = engine.generate(manifest)
```

### Key Features — VOD

- **Parse** — Full HLS manifest parsing with typed models for master and media playlists
- **Generate** — Produce spec-compliant M3U8 output from playlist models
- **Validate** — Check conformance against RFC 8216 and Apple HLS rules
- **Segment** — Split MP4 files into fMP4 or MPEG-TS segments with automatic playlist generation
- **Transcode** — Hardware-accelerated encoding via Apple VideoToolbox or FFmpeg
- **Cloud Transcode** — Delegate to Cloudflare Stream, AWS MediaConvert, or Mux
- **Encrypt** — AES-128 full-segment and SAMPLE-AES sample-level encryption
- **I-Frame** — Generate `EXT-X-I-FRAMES-ONLY` playlists for trick play
- **Builder DSL** — `@resultBuilder` syntax for constructing playlists declaratively
- **CLI** — `hlskit-cli` command-line tool with 8 commands

### Key Features — Live Streaming

- **Live Pipeline** — End-to-end ``LivePipeline`` facade: input → encoding → segmentation → playlist → push
- **LL-HLS** — Low-Latency HLS with partial segments, blocking reload, delta updates
- **Multi-Destination Push** — HTTP, RTMP, SRT, and Icecast with failover and bandwidth monitoring
- **Timed Metadata** — ID3, SCTE-35, DateRange, HLS Interstitials injection
- **Recording** — Simultaneous recording with live-to-VOD conversion and auto chapters
- **Spatial Audio** — Dolby Atmos, AC-3/E-AC-3, multi-channel layouts, Hi-Res audio
- **HDR Video** — HDR10, HLG, Dolby Vision with adaptive ladder generation
- **Live DRM** — FairPlay Streaming, key rotation, multi-DRM (CENC) interoperability
- **Accessibility** — CEA-608/708 closed captions, live subtitles, audio descriptions
- **Resilience** — Redundant streams, failover, gap signaling, content steering
- **Audio Processing** — Format conversion, loudness metering, silence detection, channel mixing

### How It Works — VOD

1. **Model** — Typed Swift structs represent every HLS concept: ``MasterPlaylist``, ``MediaPlaylist``, ``Variant``, ``Segment``
2. **Parse** — ``ManifestParser`` converts M3U8 text into models
3. **Generate** — ``ManifestGenerator`` serializes models back to M3U8
4. **Segment** — ``MP4Segmenter`` and ``TSSegmenter`` split media files into HLS segments
5. **Validate** — ``HLSValidator`` checks playlists against industry rule sets

### How It Works — Live

1. **Input** — ``MediaSource`` provides raw audio/video buffers
2. **Encode** — ``LiveEncoder`` compresses to AAC, H.264, or HEVC
3. **Segment** — ``LiveSegmenter`` packages frames into CMAF fMP4
4. **Playlist** — ``LivePlaylistManager`` maintains the live M3U8
5. **Push** — ``SegmentPusher`` delivers to CDN or streaming servers

## Topics

### Essentials

- <doc:GettingStarted>

### Engine

- ``HLSEngine``

### Manifest Models

- ``Manifest``
- ``MasterPlaylist``
- ``MediaPlaylist``
- ``Variant``
- ``IFrameVariant``
- ``Segment``
- ``Rendition``
- ``Resolution``
- ``ByteRange``
- ``EncryptionKey``
- ``MapTag``
- ``DateRange``
- ``SessionData``
- ``ContentSteering``
- ``StartOffset``
- ``VariableDefinition``
- ``VideoRange``

### Low-Latency HLS Models

- ``ServerControl``
- ``PartialSegment``
- ``PreloadHint``
- ``PreloadHintType``
- ``RenditionReport``
- ``SkipInfo``

### Enumerations

- ``HLSVersion``
- ``PlaylistType``
- ``MediaType``
- ``EncryptionMethod``
- ``HDCPLevel``
- ``ClosedCaptionsValue``
- ``HLSTag``

### Parsing

- ``ManifestParser``
- ``TagParser``
- ``AttributeParser``
- ``VariableResolver``

### Generation

- ``ManifestGenerator``
- ``TagWriter``

### Builder DSL

- ``MasterPlaylistBuilder``
- ``MasterPlaylistComponent``
- ``MediaPlaylistBuilder``
- ``MediaPlaylistComponent``

### Validation

- ``HLSValidator``
- ``ValidationReport``
- ``ValidationResult``
- ``ValidationSeverity``
- ``ValidationRuleSet``

### Segmentation

- ``MP4Segmenter``
- ``TSSegmenter``
- ``SegmentationConfig``
- ``SegmentationResult``
- ``MediaSegmentOutput``

### Transcoding

- ``Transcoder``
- ``AppleTranscoder``
- ``FFmpegTranscoder``
- ``TranscodingConfig``
- ``TranscodingResult``
- ``MultiVariantResult``
- ``QualityPreset``
- ``VideoProfile``
- ``VideoCodec``
- ``AudioCodec``
- ``OutputVideoCodec``
- ``OutputAudioCodec``
- ``VariantPlaylistBuilder``

### Cloud Transcoding

- <doc:ManagedTranscoding>
- ``ManagedTranscoder``
- ``ManagedTranscodingProvider``
- ``ManagedTranscodingConfig``
- ``ManagedTranscodingJob``

### Encryption

- ``SegmentEncryptor``
- ``SampleEncryptor``
- ``KeyManager``
- ``EncryptionConfig``
- ``EncryptedPlaylistBuilder``

### I-Frame & Thumbnails

- ``IFramePlaylistGenerator``
- ``IFrameStreamInfo``

### Input & Media Sources

- ``MediaSource``
- ``FileSource``
- ``AudioFormat``
- ``RawMediaBuffer``
- ``MediaFormatDescription``
- ``MediaSourceConfiguration``
- ``MediaTimestamp``
- ``InputError``

### Live Encoding

- ``LiveEncoder``
- ``FFmpegAudioEncoder``
- ``FFmpegVideoEncoder``
- ``MultiBitrateEncoder``
- ``EncodedFrame``
- ``EncodedCodec``
- ``LiveEncoderConfiguration``
- ``LiveEncoderError``

### Live Segmentation

- ``LiveSegmenter``
- ``IncrementalSegmenter``
- ``AudioSegmenter``
- ``VideoSegmenter``
- ``CMAFWriter``
- ``LiveSegment``
- ``LivePartialSegment``
- ``LiveSegmenterConfiguration``
- ``LiveSegmenterError``

### Live Playlists

- ``LivePlaylistManager``
- ``SlidingWindowPlaylist``
- ``SlidingWindowConfiguration``
- ``EventPlaylist``
- ``EventPlaylistConfiguration``
- ``DVRPlaylist``
- ``DVRPlaylistConfiguration``
- ``DVRBuffer``
- ``LivePlaylistMetadata``
- ``LivePlaylistEvent``
- ``LivePlaylistError``

### Low-Latency HLS Pipeline

- ``LLHLSManager``
- ``LLHLSConfiguration``
- ``PartialSegmentManager``
- ``BlockingPlaylistHandler``
- ``BlockingPlaylistRequest``
- ``DeltaUpdateGenerator``
- ``ServerControlConfig``
- ``ServerControlRenderer``
- ``LLHLSPlaylistRenderer``
- ``LLPartialSegment``
- ``HLSSkipRequest``
- ``LLHLSError``
- ``LLHLSEvent``

### Segment Push & Distribution

- ``SegmentPusher``
- ``HTTPPusher``
- ``HTTPPusherConfiguration``
- ``RTMPPusher``
- ``RTMPPusherConfiguration``
- ``SRTPusher``
- ``SRTPusherConfiguration``
- ``IcecastPusher``
- ``IcecastPusherConfiguration``
- ``MultiDestinationPusher``
- ``BandwidthMonitor``
- ``PushRetryPolicy``
- ``PushStats``
- ``PushConnectionState``
- ``PushError``

### Timed Metadata

- ``LiveMetadataInjector``
- ``DateRangeManager``
- ``InterstitialManager``
- ``ProgramDateTimeSync``
- ``SCTE35Marker``
- ``HLSInterstitial``
- ``ID3TimedMetadata``

### Recording & Live-to-VOD

- ``SimultaneousRecorder``
- ``LiveToVODConverter``
- ``AutoChapterGenerator``
- ``RecordingStorage``

### Audio Processing

- ``AudioFormatConverter``
- ``ChannelMixer``
- ``SampleRateConverter``
- ``LevelMeter``
- ``LoudnessMeter``
- ``LoudnessResult``
- ``SilenceDetector``
- ``SilenceRegion``
- ``AudioNormalizer``
- ``NormalizationPreset``
- ``ChannelLevel``
- ``GatingBlock``

### Spatial Audio & Hi-Res

- ``SpatialAudioConfig``
- ``SpatialRenditionGenerator``
- ``SpatialAudioEncoder``
- ``DolbyAtmosEncoder``
- ``AC3Encoder``
- ``MultiChannelLayout``
- ``HiResAudioConfig``

### HDR & Ultra-Resolution

- ``HDRConfig``
- ``HDRVariantGenerator``
- ``VideoRangeMapper``
- ``DolbyVisionProfile``
- ``ResolutionPreset``

### Live DRM

- ``LiveDRMPipeline``
- ``LiveDRMPipelineConfig``
- ``FairPlayLiveConfig``
- ``LiveKeyManager``
- ``SessionKeyManager``
- ``KeyRotationPolicy``
- ``CENCConfig``

### Accessibility

- ``AccessibilityRenditionGenerator``
- ``ClosedCaptionConfig``
- ``AudioDescriptionConfig``
- ``LiveSubtitlePlaylist``
- ``LiveWebVTTWriter``

### Resilience & Failover

- ``FailoverManager``
- ``RedundantStreamConfig``
- ``GapHandler``
- ``ContentSteeringConfig``
- ``SessionDataConfig``

### Live Pipeline

- ``LivePipeline``
- ``LivePipelineConfiguration``
- ``LivePipelineComponents``
- ``LivePipelineState``
- ``LivePipelineStatistics``
- ``LivePipelineEvent``
- ``LivePipelineError``

### Container — MP4

- ``MP4BoxReader``
- ``MP4InfoParser``
- ``MP4FileInfo``
- ``MP4Box``
- ``MP4TrackAnalysis``
- ``TrackInfo``
- ``MediaTrackType``
- ``VideoDimensions``
- ``SampleTable``
- ``SampleTableParser``
- ``SampleLocator``
- ``SegmentInfo``
- ``TimeToSampleEntry``
- ``CompositionOffsetEntry``
- ``SampleToChunkEntry``
- ``InitSegmentWriter``
- ``MediaSegmentWriter``
- ``MuxedTrackInput``
- ``BinaryReader``
- ``BinaryWriter``

### Container — MPEG-TS

- ``TSSegmentBuilder``
- ``TSPacket``
- ``TSPacketWriter``
- ``TSCodecConfig``
- ``SampleData``
- ``ProgramTableGenerator``
- ``PESPacketizer``
- ``ADTSConverter``
- ``AnnexBConverter``
- ``AdaptationField``

### Errors

- ``ParserError``
- ``MP4Error``
- ``TranscodingError``
- ``EncryptionError``
- ``TransportError``
- ``BinaryReaderError``

### Articles — VOD

- <doc:ManifestParsing>
- <doc:ManifestGeneration>
- <doc:ValidatingManifests>
- <doc:SegmentingMedia>
- <doc:TranscodingMedia>
- <doc:ManagedTranscoding>
- <doc:EncryptingSegments>
- <doc:HLSEngine>
- <doc:CLIReference>

### Articles — Live Streaming

- <doc:LiveStreaming>
- <doc:LiveEncoding>
- <doc:LiveSegmentation>
- <doc:LivePlaylists>
- <doc:LowLatencyHLS>
- <doc:SegmentPushing>
- <doc:LiveMetadata>
- <doc:LiveRecording>
- <doc:IFramePlaylists>
- <doc:AudioProcessing>
- <doc:SpatialAudio>
- <doc:HDRVideo>
- <doc:LiveDRM>
- <doc:LiveAccessibility>
- <doc:LivePresets>
