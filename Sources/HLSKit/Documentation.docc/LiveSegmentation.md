# Live Segmentation

@Metadata {
    @PageKind(article)
}

Package encoded frames into CMAF fMP4 segments for live HLS delivery.

## Overview

HLSKit provides specialized segmenters that turn ``EncodedFrame`` streams into CMAF-compliant fMP4 segments. The ``LiveSegmenter`` protocol defines the contract, with ``AudioSegmenter`` and ``VideoSegmenter`` as concrete implementations.

### Audio Segmenter

``AudioSegmenter`` produces duration-aligned audio segments:

```swift
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

// Ingest encoded frames
for frame in encodedFrames {
    try await segmenter.ingest(frame)
}
let finalSegment = try await segmenter.finish()

// Collect emitted segments via AsyncStream
for await segment in segmenter.segments {
    print("Segment \(segment.index): \(segment.duration)s")
}
```

### Video Segmenter

``VideoSegmenter`` aligns segments on keyframe boundaries for proper seeking:

```swift
let videoConfig = CMAFWriter.VideoConfig(
    codec: .h264,
    width: 1280, height: 720,
    sps: spsData,
    pps: ppsData
)
let segConfig = LiveSegmenterConfiguration(
    targetDuration: 1.0,
    keyframeAligned: true
)
let segmenter = VideoSegmenter(
    videoConfig: videoConfig,
    configuration: segConfig
)
```

### CMAF Writer

``CMAFWriter`` generates CMAF-compliant fMP4 initialization and media segments. Init segments contain `ftyp` + `moov` boxes with the `cmfc` brand; media segments contain `styp` + `moof` + `mdat` with the `msdh` brand:

```swift
let writer = CMAFWriter()

// Generate init segment
let audioInit = writer.generateAudioInitSegment(
    config: CMAFWriter.AudioConfig(sampleRate: 48000, channels: 2)
)
// audioInit contains ftyp + moov with cmfc brand

// Generate media segment
let mediaSeg = writer.generateMediaSegment(
    frames: frames,
    sequenceNumber: 1,
    timescale: 48000
)
// mediaSeg contains styp + moof + mdat with msdh brand
```

### Ring Buffer

`SegmentRingBuffer` provides fixed-capacity storage for recent segments, enabling DVR-style playback:

```swift
let segConfig = LiveSegmenterConfiguration(
    targetDuration: 2.0,
    ringBufferSize: 3,
    keyframeAligned: false
)
// Ring buffer holds at most 3 recent segments
// Older segments are evicted automatically
```

### Incremental Segmenter

``IncrementalSegmenter`` is a general-purpose segmenter that handles both audio and video with keyframe alignment and configurable boundaries.

### Force Segment Boundary

For ad insertion or content switches, force an immediate segment boundary:

```swift
try await segmenter.forceSegmentBoundary()
// Current segment is emitted, new segment begins
```

### Configuration

``LiveSegmenterConfiguration`` controls target duration, ring buffer size, and keyframe alignment:

| Parameter | Default | Description |
|-----------|---------|-------------|
| `targetDuration` | `6.0` | Target segment duration in seconds |
| `ringBufferSize` | `nil` | Max segments to retain (nil = unlimited) |
| `keyframeAligned` | `true` | Align boundaries to keyframes (video) |

## Next Steps

- <doc:LivePlaylists> — Manage playlists from emitted segments
- <doc:LowLatencyHLS> — Partial segments for LL-HLS
- <doc:LiveEncoding> — Encode raw media into frames
