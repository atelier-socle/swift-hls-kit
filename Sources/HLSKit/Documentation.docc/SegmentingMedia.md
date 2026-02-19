# Segmentation

Split MP4 files into fMP4 or MPEG-TS segments for HLS delivery.

## Overview

HLSKit provides two segmenters — ``MP4Segmenter`` for fragmented MP4 (fMP4) output and ``TSSegmenter`` for MPEG-TS output. Both produce ``SegmentationResult`` containing media segments, an optional init segment, and an auto-generated M3U8 playlist.

### fMP4 Segmentation

Fragmented MP4 is the recommended format for modern HLS (version 7+). It produces an init segment (`init.mp4`) and media segments (`.m4s`):

```swift
let config = SegmentationConfig(containerFormat: .fragmentedMP4)
let result = try MP4Segmenter().segment(data: mp4Data, config: config)

// result.hasInitSegment == true
// result.initSegment is the ftyp+moov data
// result.segmentCount > 0
// result.totalDuration > 0
```

### Configure Segmentation

``SegmentationConfig`` controls all segmentation parameters:

```swift
let config = SegmentationConfig(
    targetSegmentDuration: 4.0,
    containerFormat: .fragmentedMP4,
    generatePlaylist: true,
    playlistType: .vod
)

let result = try MP4Segmenter().segment(data: mp4Data, config: config)
// result.config.targetSegmentDuration == 4.0
// result.playlist contains the generated M3U8
```

#### Default Values

| Parameter | Default |
|-----------|---------|
| `targetSegmentDuration` | `6.0` seconds |
| `containerFormat` | `.fragmentedMP4` |
| `outputMode` | `.separateFiles` |
| `generatePlaylist` | `true` |
| `playlistType` | `.vod` |
| `includeAudio` | `true` |
| `initSegmentName` | `"init.mp4"` |
| `playlistName` | `"playlist.m3u8"` |

### Byte-Range Segments

Instead of separate files, you can use byte-range mode where all segments are in a single file:

```swift
let config = SegmentationConfig(
    containerFormat: .fragmentedMP4,
    outputMode: .byteRange
)

let result = try MP4Segmenter().segment(data: mp4Data, config: config)
for segment in result.mediaSegments {
    // segment.byteRangeLength and segment.byteRangeOffset are set
}
```

### Auto-Generated Playlist

When `generatePlaylist` is enabled, the segmenter produces a valid M3U8 playlist with `EXT-X-MAP` for the init segment:

```swift
let config = SegmentationConfig(
    containerFormat: .fragmentedMP4,
    generatePlaylist: true
)

let result = try MP4Segmenter().segment(data: mp4Data, config: config)
// result.playlist contains:
//   #EXTM3U
//   #EXT-X-MAP:URI="init.mp4"
//   #EXTINF:...
//   #EXT-X-ENDLIST
```

### MPEG-TS Segmentation

For legacy compatibility (HLS version 3), use ``TSSegmenter``:

```swift
let config = SegmentationConfig(
    targetSegmentDuration: 8.0,
    containerFormat: .mpegTS,
    generatePlaylist: true,
    playlistType: .vod
)

let segmenter = TSSegmenter()
```

### Container Format Properties

``SegmentationConfig/ContainerFormat`` maps to the appropriate HLS version and segment file extension:

| Format | HLS Version | Segment Extension |
|--------|-------------|-------------------|
| `.fragmentedMP4` | 7 | `.m4s` |
| `.mpegTS` | 3 | `.ts` |

### Segment to Directory

Write segments directly to disk:

```swift
let result = try MP4Segmenter().segmentToDirectory(
    data: mp4Data,
    outputDirectory: outputURL,
    config: config
)
```

### SegmentationResult Properties

``SegmentationResult`` provides access to all output data:

| Property | Description |
|----------|-------------|
| `initSegment` | Init segment data (fMP4 only) |
| `mediaSegments` | Array of ``MediaSegmentOutput`` |
| `playlist` | Generated M3U8 string (if enabled) |
| `fileInfo` | Parsed ``MP4FileInfo`` metadata |
| `totalDuration` | Sum of all segment durations |
| `segmentCount` | Number of media segments |
| `hasInitSegment` | Whether an init segment was produced |

## Next Steps

- <doc:TranscodingMedia> — Transcode media before segmenting
- <doc:EncryptingSegments> — Encrypt segments after segmentation
- <doc:HLSEngine> — Use the engine facade for segmentation workflows
