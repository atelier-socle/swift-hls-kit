# Live Presets & Pipeline

@Metadata {
    @PageKind(article)
}

Orchestrate the full live pipeline with ``LivePipeline`` and pre-built ``LivePipelineConfiguration`` presets.

## Overview

``LivePipeline`` is the top-level facade that wires encoding, segmentation, playlist management, push delivery, metadata injection, and recording into a single orchestrated pipeline. ``LivePipelineConfiguration`` provides presets for common streaming scenarios.

### Pipeline Lifecycle

``LivePipeline`` manages the full lifecycle: `idle` → `starting` → `running` → `stopping` → `stopped`.

``LivePipelineState`` tracks the current state, and ``LivePipelineEvent`` notifies your app of transitions.

### Configuration

``LivePipelineConfiguration`` is the comprehensive configuration covering all pipeline stages:

```swift
var config = LivePipelineConfiguration()
config.audioBitrate = 128_000
config.videoEnabled = false
config.targetSegmentDuration = 6.0
```

### Built-in Presets

| Preset | Scenario | Key Settings |
|--------|----------|-------------|
| `.podcastLive` | Audio-only podcast | 128 kbps AAC, no video |
| `.musicLive` | DJ mix, webradio | 256 kbps AAC, no video |
| `.videoLive` | Standard live video | H.264, 720p, AAC |
| `.videoSimulcast` | Multi-destination | Multiple push targets |
| `.broadcastPro` | Full production | Atmos, 4K DV, DRM, CC, AD |
| `.spatialAudioLive` | Spatial audio | Dolby Atmos 5.1 |
| `.videoDolbyVision` | HDR video | DV Profile 8, 4K |
| `.multiDRMLive` | Multi-DRM | FairPlay + CENC |
| `.accessibleLive` | Accessibility | CC + AD + subtitles |

```swift
let config = LivePipelineConfiguration.broadcastPro
// config.spatialAudio?.format == .dolbyAtmos
// config.hdr?.type == .dolbyVisionWithHDR10Fallback
// config.resolution == .uhd4K
// config.drm?.isEnabled == true
// config.closedCaptions != nil
// config.audioDescriptions?.count == 3
// config.enableRecording == true
```

### Cherry-Pick Composition

Mix features from different presets:

```swift
var config = LivePipelineConfiguration()

// Spatial audio from spatialAudioLive
config.spatialAudio = LivePipelineConfiguration.spatialAudioLive.spatialAudio

// HDR from videoDolbyVision
config.hdr = LivePipelineConfiguration.videoDolbyVision.hdr
config.videoEnabled = true
config.resolution = .uhd4K

// DRM from multiDRMLive
config.drm = LivePipelineConfiguration.multiDRMLive.drm

// Accessibility from accessibleLive
config.closedCaptions = LivePipelineConfiguration.accessibleLive.closedCaptions
config.audioDescriptions = LivePipelineConfiguration.accessibleLive.audioDescriptions
config.subtitlesEnabled = true
```

### Pipeline Components

``LivePipelineComponents`` is a dependency injection container organized by responsibility:

| Component Group | Purpose |
|----------------|---------|
| ``InputComponents`` | Media sources |
| ``EncodingComponents`` | Encoders |
| ``SegmentationComponents`` | Segmenters |
| ``PlaylistComponents`` | Playlist managers |
| ``LowLatencyComponents`` | LL-HLS pipeline |
| ``PushComponents`` | Segment pushers |
| ``MetadataComponents`` | Metadata injectors |
| ``RecordingComponents`` | Recorders |
| ``AudioComponents`` | Audio processing |
| ``SpatialAudioComponents`` | Spatial encoders |
| ``HDRComponents`` | HDR configuration |
| ``DRMComponents`` | DRM pipeline |
| ``AccessibilityComponents`` | Accessibility |
| ``ResilienceComponents`` | Failover |

### Statistics

``LivePipelineStatistics`` provides runtime metrics:

```swift
let stats = await pipeline.statistics
// stats.uptime — seconds since start
// stats.segmentsProduced — total segments emitted
// stats.bytesProduced — total bytes generated
// stats.errorCount — errors encountered
```

### CLI Commands

The `hlskit-cli live` command group controls live pipelines:

```bash
hlskit-cli live start --preset podcast-live --output /tmp/live/
hlskit-cli live stop
hlskit-cli live stats
hlskit-cli live convert-to-vod /tmp/live/ --output /tmp/vod/
hlskit-cli live metadata --inject "title=Breaking News"
```

## Next Steps

- <doc:LiveStreaming> — Architecture overview
- <doc:LiveEncoding> — Encoder configuration
- <doc:LiveSegmentation> — Segmentation options
- <doc:CLIReference> — Full CLI reference
