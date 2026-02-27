# Input & Encoding

@Metadata {
    @PageKind(article)
}

Feed raw media into HLSKit and encode it in real time with ``LiveEncoder`` implementations.

## Overview

The input layer provides a cross-platform ``MediaSource`` protocol for feeding raw audio and video buffers into the pipeline. The encoding layer compresses those buffers into AAC, H.264, or HEVC frames using platform-specific or FFmpeg-based encoders.

### Media Sources

``MediaSource`` is the contract for media input. Your app implements it with `AVAudioEngine`, `AVCaptureSession`, or any other capture source:

```swift
public protocol MediaSource: Sendable {
    var format: MediaFormatDescription { get async }
    func start() async throws
    func stop() async
    func buffers() -> AsyncStream<RawMediaBuffer>
}
```

``FileSource`` is the reference implementation that reads from MP4/MOV files:

```swift
let source = FileSource(url: fileURL)
try await source.start()
for await buffer in source.buffers() {
    // Process raw media buffers
}
```

### Audio Format

``AudioFormat`` describes codec, sample rate, channels, bit depth, and bitrate:

```swift
let format = AudioFormat(
    codec: .aac,
    sampleRate: 48000,
    channels: 2,
    bitDepth: 16,
    bitrate: 128_000
)
```

### Live Encoder Protocol

``LiveEncoder`` transforms raw buffers into compressed ``EncodedFrame`` instances:

```swift
public protocol LiveEncoder: Sendable {
    func configure(_ config: LiveEncoderConfiguration) async throws
    func encode(_ buffer: RawMediaBuffer) async throws -> EncodedFrame?
    func flush() async throws -> [EncodedFrame]
}
```

### Apple Audio Encoder

On Apple platforms, `AudioEncoder` uses `AVAudioConverter` for hardware-accelerated AAC encoding. It accumulates PCM samples into 1024-sample frames as required by AAC.

### FFmpeg Encoders

For cross-platform support, ``FFmpegAudioEncoder`` and ``FFmpegVideoEncoder`` use ffmpeg subprocesses:

- ``FFmpegAudioEncoder`` — AAC via ADTS output
- ``FFmpegVideoEncoder`` — H.264/HEVC from YUV420p input

### Apple Video Encoder

On Apple platforms, `VideoEncoder` uses VideoToolbox for hardware-accelerated H.264/HEVC encoding with automatic keyframe insertion.

### Multi-Bitrate Encoding

``MultiBitrateEncoder`` encodes a single source at multiple quality levels simultaneously:

```swift
let configs = [
    LiveEncoderConfiguration(bitrate: 800_000),
    LiveEncoderConfiguration(bitrate: 2_800_000),
    LiveEncoderConfiguration(bitrate: 5_000_000)
]
```

### Encoder Configuration

``LiveEncoderConfiguration`` controls codec, bitrate, sample rate, channels, and preset:

```swift
let config = LiveEncoderConfiguration(
    codec: .aac,
    bitrate: 128_000,
    sampleRate: 48000,
    channels: 2
)
```

### Encoded Frames

``EncodedFrame`` represents a compressed media frame with codec info, timestamp, duration, and keyframe flag:

```swift
// frame.codec == .aac
// frame.timestamp.seconds == 0.0
// frame.isKeyframe == true
// frame.data.count > 0
```

## Next Steps

- <doc:LiveSegmentation> — Package encoded frames into CMAF segments
- <doc:LiveStreaming> — Full pipeline overview
- <doc:LivePresets> — Pre-built encoder configurations
