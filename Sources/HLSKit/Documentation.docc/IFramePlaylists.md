# I-Frame Playlists & Thumbnails

@Metadata {
    @PageKind(article)
}

Generate `EXT-X-I-FRAMES-ONLY` playlists for trick play, scrubbing, and thumbnail timelines.

## Overview

HLSKit provides ``IFramePlaylistGenerator`` for creating I-frame only playlists, ``IFrameStreamInfo`` for master playlist entries, and `ThumbnailExtractor` for extracting preview images from video segments.

### I-Frame Playlist Generator

``IFramePlaylistGenerator`` builds `EXT-X-I-FRAMES-ONLY` playlists from keyframe references:

```swift
var generator = IFramePlaylistGenerator(
    configuration: .init(version: 7, initSegmentURI: "init.mp4")
)

generator.addKeyframe(
    segmentURI: "segment_0.m4s",
    byteOffset: 0,
    byteLength: 4096,
    duration: 6.0
)
generator.addKeyframe(
    segmentURI: "segment_1.m4s",
    byteOffset: 0,
    byteLength: 3072,
    duration: 4.5
)

let playlist = generator.generate()
// playlist contains #EXT-X-I-FRAMES-ONLY, #EXT-X-MAP, BYTERANGE entries
```

### I-Frame Stream Info

``IFrameStreamInfo`` represents an `EXT-X-I-FRAME-STREAM-INF` entry in a master playlist. Use it to reference I-frame playlists from the master:

```swift
let info = IFrameStreamInfo(
    bandwidth: 200_000,
    codecs: "avc1.4d401e",
    resolution: Resolution(width: 640, height: 360),
    uri: "iframe.m3u8"
)
```

### Thumbnail Extraction

`ThumbnailExtractor` extracts thumbnail images from video segments for timeline preview. The `ThumbnailImageProvider` protocol enables custom image extraction on platforms with image processing capabilities.

### CLI Command

The `hlskit-cli iframe` command generates I-frame playlists from existing media playlists:

```bash
hlskit-cli iframe --input stream.m3u8 --output iframe.m3u8
hlskit-cli iframe --input stream.m3u8 --output iframe.m3u8 --byte-range
```

## Next Steps

- <doc:SegmentingMedia> — Segment media before generating I-frame playlists
- <doc:CLIReference> — CLI iframe command reference
- <doc:LiveStreaming> — I-frame generation in live pipelines
