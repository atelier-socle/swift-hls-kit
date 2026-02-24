# Transcoding

Transcode media files with Apple VideoToolbox or FFmpeg using ``AppleTranscoder`` and ``FFmpegTranscoder``.

## Overview

HLSKit supports hardware-accelerated transcoding on Apple platforms via VideoToolbox, and cross-platform transcoding via FFmpeg. Both transcoders conform to the ``Transcoder`` protocol and produce ``TranscodingResult`` with segment output and performance metrics.

### Quality Presets

``QualityPreset`` provides predefined encoding profiles for common resolutions:

| Preset | Resolution | Video Bitrate | Profile |
|--------|-----------|---------------|---------|
| `.p360` | 640x360 | 800 kbps | Baseline |
| `.p480` | 854x480 | 1.4 Mbps | Main |
| `.p720` | 1280x720 | 2.8 Mbps | High |
| `.p1080` | 1920x1080 | 5 Mbps | High |
| `.p2160` | 3840x2160 | 14 Mbps | High |
| `.audioOnly` | — | — | — |

```swift
let p720 = QualityPreset.p720
// p720.resolution == .p720
// p720.videoBitrate == 2_800_000
// p720.videoProfile == .high
// p720.totalBandwidth > 0
```

#### Quality Ladders

Use predefined ladders for multi-variant HLS:

```swift
let standard = QualityPreset.standardLadder  // [p360, p480, p720, p1080]
let full = QualityPreset.fullLadder          // [p360, p480, p720, p1080, p2160]
```

#### Audio-Only Preset

For podcast and radio content:

```swift
let audio = QualityPreset.audioOnly
// audio.isAudioOnly == true
// audio.resolution == nil
// audio.videoBitrate == nil
// audio.audioBitrate > 0
```

#### Codecs String

Generate the `CODECS` attribute value for HLS manifests:

```swift
let codecs = QualityPreset.p720.codecsString()
// codecs contains "avc1" and "mp4a"
```

### TranscodingConfig

``TranscodingConfig`` controls the transcoding parameters:

```swift
let config = TranscodingConfig()
// config.videoCodec == .h264
// config.audioCodec == .aac
// config.containerFormat == .fragmentedMP4
// config.segmentDuration == 6.0
// config.generatePlaylist == true
// config.audioPassthrough == true
// config.hardwareAcceleration == true
```

#### Video Codecs

| Codec | Raw Value |
|-------|-----------|
| ``VideoCodec/h264`` | `"h264"` |
| ``VideoCodec/h265`` | `"h265"` |

#### Audio Codecs

| Codec | Raw Value |
|-------|-----------|
| ``AudioCodec/aac`` | `"aac"` |
| ``AudioCodec/heAAC`` | `"heAAC"` |
| ``AudioCodec/opus`` | `"opus"` |

#### Video Profiles

``VideoProfile`` defines the encoding profile for quality/compatibility tradeoffs:

| Profile | Use Case |
|---------|----------|
| `.baseline` | Maximum compatibility, lower quality |
| `.main` | Good balance of quality and compatibility |
| `.high` | Best quality for H.264 |
| `.mainHEVC` | HEVC/H.265 main profile |
| `.main10HEVC` | HEVC 10-bit HDR content |

### Apple Transcoder

On macOS and iOS, use hardware-accelerated VideoToolbox:

```swift
#if canImport(AVFoundation) && !os(watchOS)
let transcoder = AppleTranscoder()
// AppleTranscoder.isAvailable == true
// AppleTranscoder.name == "Apple VideoToolbox"
#endif
```

### FFmpeg Transcoder

For cross-platform transcoding (requires FFmpeg installed):

```swift
// FFmpegTranscoder.name == "FFmpeg"
// FFmpegTranscoder.isAvailable depends on FFmpeg installation
```

### Transcoding Results

``TranscodingResult`` includes performance metrics:

```swift
let result = TranscodingResult(
    preset: .p720,
    outputDirectory: outputURL,
    transcodingDuration: 5.0,
    sourceDuration: 10.0,
    outputSize: 1_000_000
)
// result.speedFactor == 2.0 (2x realtime)
// result.outputSize == 1_000_000
```

### Multi-Variant Transcoding

Transcode to multiple quality levels at once:

```swift
let multi = MultiVariantResult(
    variants: [result360, result720],
    masterPlaylist: nil,
    outputDirectory: outputURL
)
// multi.variants.count == 2
// multi.totalTranscodingDuration == sum of all variant durations
// multi.totalOutputSize == sum of all variant sizes
```

### Variant Playlist Builder

Generate a master playlist from quality presets:

```swift
let builder = VariantPlaylistBuilder()
let presets: [QualityPreset] = [.p360, .p720, .p1080]
let config = TranscodingConfig()
let m3u8 = builder.buildMasterPlaylist(
    presets: presets,
    videoCodec: config.videoCodec,
    config: config
)
// m3u8 contains #EXTM3U, BANDWIDTH=, RESOLUTION=
```

## Cloud Transcoding

For server-side applications where local GPU or FFmpeg are not available, ``ManagedTranscoder`` delegates transcoding to cloud providers (Cloudflare Stream, AWS MediaConvert, Mux). It conforms to the same ``Transcoder`` protocol — callers don't need to know whether transcoding happens locally or in the cloud.

See <doc:ManagedTranscoding> for configuration and usage.

## Next Steps

- <doc:ManagedTranscoding> — Cloud transcoding with Cloudflare, AWS, and Mux
- <doc:SegmentingMedia> — Segment transcoded output into HLS segments
- <doc:EncryptingSegments> — Encrypt transcoded segments
- <doc:HLSEngine> — Use the engine facade for end-to-end workflows
