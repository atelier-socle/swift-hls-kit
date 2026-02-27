# Recording & Live-to-VOD

@Metadata {
    @PageKind(article)
}

Record live streams and convert them to clean VOD playlists.

## Overview

HLSKit provides ``SimultaneousRecorder`` for capturing all segments during a live stream, ``LiveToVODConverter`` for converting recorded content to VOD playlists, and ``AutoChapterGenerator`` for creating chapter markers from stream metadata.

### Simultaneous Recorder

``SimultaneousRecorder`` records all segments emitted during a live session. It runs alongside the live pipeline without affecting delivery:

```swift
let recorder = SimultaneousRecorder(
    storage: localStorage,
    outputDirectory: recordingDir
)
await recorder.start()

// Later, after the live session ends:
await recorder.stop()
let recordedSegments = await recorder.segments
```

``RecordingStorage`` is a protocol for recording storage operations — implement it for local disk, cloud storage, or any persistence layer.

### Live-to-VOD Conversion

``LiveToVODConverter`` transforms recorded live/event segments into a clean VOD playlist with `EXT-X-PLAYLIST-TYPE:VOD` and `EXT-X-ENDLIST`:

```swift
let converter = LiveToVODConverter()
let vodPlaylist = converter.convert(
    segments: recordedSegments,
    targetDuration: 6
)
// vodPlaylist is a clean VOD M3U8 string
```

The converter removes live-only artifacts (sliding window gaps, discontinuity sequences from failover) and produces a continuous, seekable VOD experience.

### Auto Chapter Generation

``AutoChapterGenerator`` creates chapter markers from live stream metadata. Supports both JSON Chapters and WebVTT output:

```swift
let generator = AutoChapterGenerator()
let chapters = generator.generateFromMetadata(
    metadata: streamMetadata,
    totalDuration: 3600
)
// chapters contains titled, timestamped chapter markers
```

### CLI Command

The `hlskit-cli live convert-to-vod` command converts a recorded live directory to VOD:

```bash
hlskit-cli live convert-to-vod /tmp/recording/ --output /tmp/vod/
```

## Next Steps

- <doc:LiveStreaming> — Full pipeline architecture
- <doc:LiveMetadata> — Metadata that drives chapter generation
- <doc:CLIReference> — CLI live commands
