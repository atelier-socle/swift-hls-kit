# Getting Started with HLSKit

Add HLSKit to your project and build your first HLS workflow.

## Overview

HLSKit is a pure Swift library with zero external dependencies in its core. It supports macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+, and Linux.

### Installation

Add HLSKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/atelier-socle/swift-hls-kit.git", from: "0.3.0")
]
```

Then add it as a dependency to your target:

```swift
.target(
    name: "MyApp",
    dependencies: ["HLSKit"]
)
```

### Your First Workflow — Parse, Inspect, Validate

The simplest way to use HLSKit is through the ``HLSEngine`` facade:

```swift
import HLSKit

let engine = HLSEngine()

let m3u8 = """
    #EXTM3U
    #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
    360p/playlist.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
    720p/playlist.m3u8
    """

// Parse the manifest
let manifest = try engine.parse(m3u8)

// Validate against RFC 8216
let report = engine.validate(manifest)
print("Valid: \(report.isValid)")

// Generate the M3U8 output
let output = engine.generate(manifest)
```

### Inspect Parsed Models

Once parsed, you can access typed models directly:

```swift
let parser = ManifestParser()
let manifest = try parser.parse(m3u8)

guard case .master(let playlist) = manifest else { return }
for variant in playlist.variants {
    print("\(variant.resolution) — \(variant.bandwidth) bps")
    print("  URI: \(variant.uri)")
}
```

### Build Playlists with the DSL

Use the `@resultBuilder` DSL to construct playlists declaratively:

```swift
let playlist = MasterPlaylist {
    Variant(bandwidth: 800_000, resolution: .p480, uri: "480p/playlist.m3u8")
    Variant(bandwidth: 2_800_000, resolution: .p720, uri: "720p/playlist.m3u8")
    Variant(bandwidth: 5_000_000, resolution: .p1080, uri: "1080p/playlist.m3u8")
}

let m3u8 = ManifestGenerator().generateMaster(playlist)
```

### Segment a Video File

Split an MP4 file into fMP4 segments for HLS delivery:

```swift
let config = SegmentationConfig(
    targetSegmentDuration: 6.0,
    containerFormat: .fragmentedMP4,
    generatePlaylist: true,
    playlistType: .vod
)

let result = try MP4Segmenter().segment(data: mp4Data, config: config)
print("Init segment: \(result.initSegment.count) bytes")
print("Segments: \(result.segmentCount)")
print("Duration: \(result.totalDuration)s")
```

### Quick Start: Live Streaming

HLSKit 0.3.0 adds a complete live streaming pipeline. Here is a minimal audio segmenter:

```swift
import HLSKit

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

// Ingest encoded frames from your capture pipeline
for frame in encodedFrames {
    try await segmenter.ingest(frame)
}
let finalSegment = try await segmenter.finish()

// Collect emitted CMAF segments
for await segment in segmenter.segments {
    print("Segment \(segment.index): \(segment.duration)s")
}
```

Or use a pre-built pipeline preset:

```swift
let config = LivePipelineConfiguration.podcastLive
// config.audioBitrate == 128_000
// config.videoEnabled == false
```

## Next Steps

- <doc:ManifestParsing> — Parse HLS manifests into typed models
- <doc:ManifestGeneration> — Generate M3U8 output and use the builder DSL
- <doc:ValidatingManifests> — Validate playlists against RFC 8216 and Apple rules
- <doc:SegmentingMedia> — Split media files into HLS segments
- <doc:TranscodingMedia> — Transcode media with Apple VideoToolbox or FFmpeg
- <doc:EncryptingSegments> — Encrypt segments with AES-128 or SAMPLE-AES
- <doc:HLSEngine> — Use the high-level engine facade
- <doc:LiveStreaming> — Build live streaming pipelines
- <doc:CLIReference> — Run HLS workflows from the command line
