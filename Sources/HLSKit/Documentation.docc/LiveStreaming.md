# Live Streaming

@Metadata {
    @PageKind(article)
}

Build complete live HLS pipelines — from audio/video input to segment delivery.

## Overview

HLSKit 0.3.0 introduces a full live streaming pipeline alongside the existing VOD capabilities. The pipeline is modular: each stage has its own protocol, and ``LivePipeline`` orchestrates them end-to-end.

### Architecture

The live pipeline flows through six stages:

```
MediaSource → LiveEncoder → LiveSegmenter → LivePlaylistManager → SegmentPusher → Client
                                  ↓
                          LiveMetadataInjector
```

1. **Input** — ``MediaSource`` protocol provides raw audio/video buffers from any capture source
2. **Encoding** — ``LiveEncoder`` protocol compresses buffers into AAC, H.264, or HEVC frames
3. **Segmentation** — ``LiveSegmenter`` protocol packages frames into CMAF fMP4 segments
4. **Playlist** — ``LivePlaylistManager`` protocol maintains the live M3U8 with sliding window, DVR, or event modes
5. **Push** — ``SegmentPusher`` protocol delivers segments via HTTP, RTMP, SRT, or Icecast
6. **Metadata** — ``LiveMetadataInjector`` handles timed metadata (ID3, SCTE-35, DateRange) in parallel

### Quick Example — Podcast Live Audio

```swift
import HLSKit

// Configure a live audio segmenter
let audioConfig = CMAFWriter.AudioConfig(
    sampleRate: 48000, channels: 2, profile: .lc
)
let segConfig = LiveSegmenterConfiguration(
    targetDuration: 2.0,
    keyframeAligned: false
)
let segmenter = AudioSegmenter(
    audioConfig: audioConfig,
    configuration: segConfig
)

// Collect emitted segments
for await segment in segmenter.segments {
    // Each segment is a valid CMAF fMP4 fragment
    print("Segment \(segment.index): \(segment.duration)s")
}
```

### Use Cases

| Scenario | Key Components |
|----------|---------------|
| Podcast live | `AudioSegmenter`, `SlidingWindowPlaylist`, `HTTPPusher` |
| DJ mix / Webradio | `AudioSegmenter`, `DVRPlaylist`, `IcecastPusher` |
| Live video | `VideoSegmenter`, `MultiBitrateEncoder`, `EventPlaylist` |
| Low-latency live | `LLHLSManager`, `PartialSegmentManager`, `BlockingPlaylistHandler` |
| Simulcast | `MultiDestinationPusher`, `BandwidthMonitor` |

### Pipeline Presets

``LivePipelineConfiguration`` provides built-in presets for common scenarios:

```swift
let config = LivePipelineConfiguration.podcastLive
// config.audioBitrate == 128_000
// config.videoEnabled == false
```

Available presets include `podcastLive`, `musicLive`, `videoLive`, `videoSimulcast`, `broadcastPro`, `spatialAudioLive`, `videoDolbyVision`, `multiDRMLive`, and `accessibleLive`.

## Next Steps

- <doc:LiveEncoding> — Input sources and real-time encoding
- <doc:LiveSegmentation> — CMAF segmentation and ring buffers
- <doc:LivePlaylists> — Playlist management strategies
- <doc:LowLatencyHLS> — Low-Latency HLS with partial segments
- <doc:SegmentPushing> — Deliver segments to CDN or streaming servers
- <doc:LiveMetadata> — Timed metadata injection
- <doc:LiveRecording> — Record live streams and convert to VOD
- <doc:LivePresets> — Pipeline presets and configuration
