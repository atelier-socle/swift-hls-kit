# Low-Latency HLS

@Metadata {
    @PageKind(article)
}

Deliver sub-second latency with LL-HLS partial segments, blocking reload, and delta updates.

## Overview

HLSKit implements the Low-Latency HLS extensions from RFC 8216bis. ``LLHLSManager`` orchestrates the full LL-HLS pipeline — partial segments, preload hints, server control, blocking playlist reload, and delta updates.

### LL-HLS Manager

``LLHLSManager`` is the central orchestrator:

```swift
let config = LLHLSConfiguration(
    partTargetDuration: 0.5,
    maxPartCount: 6,
    uriTemplate: "segment_{seg}_part_{part}.m4s"
)
let manager = LLHLSManager(configuration: config)
```

### Partial Segments

``PartialSegmentManager`` manages the lifecycle of partial segments within a live stream. Each ``LLPartialSegment`` represents a sub-segment chunk that clients can fetch before the full segment is complete.

HLS tags generated: `EXT-X-PART-INF`, `EXT-X-PART`, `EXT-X-PRELOAD-HINT`.

### Blocking Playlist Reload

``BlockingPlaylistHandler`` handles `_HLS_msn` and `_HLS_part` query parameters from LL-HLS clients. It holds the response until the requested segment or partial is available:

```swift
let handler = BlockingPlaylistHandler()
// Client requests: playlist.m3u8?_HLS_msn=5&_HLS_part=2
// Handler blocks until segment 5, part 2 is available
```

``BlockingPlaylistRequest`` models the incoming request parameters.

### Server Control

``ServerControlConfig`` defines the `EXT-X-SERVER-CONTROL` tag parameters:

| Parameter | Description |
|-----------|-------------|
| `canBlockReload` | Enables blocking playlist reload |
| `canSkipUntil` | Enables delta updates (CAN-SKIP-UNTIL) |
| `canSkipDateRanges` | Enables skipping date ranges |
| `holdBack` | Hold-back duration for segments |
| `partHoldBack` | Hold-back duration for partial segments |

``ServerControlRenderer`` generates the corresponding M3U8 tag.

### Delta Updates

``DeltaUpdateGenerator`` creates delta playlists for `_HLS_skip` requests. Instead of sending the full playlist, only new segments since the last request are included:

```swift
let generator = DeltaUpdateGenerator()
// Handles _HLS_skip=YES and _HLS_skip=v2 (with date ranges)
```

``HLSSkipRequest`` models the skip type.

### LL-HLS Playlist Rendering

``LLHLSPlaylistRenderer`` adds LL-HLS specific tags to the M3U8 output: `EXT-X-PART-INF`, `EXT-X-PART`, and `EXT-X-PRELOAD-HINT`.

### Configuration

``LLHLSConfiguration`` controls timing, URI templates, and partial segment limits:

| Parameter | Description |
|-----------|-------------|
| `partTargetDuration` | Target duration per partial segment |
| `maxPartCount` | Max partials per full segment |
| `uriTemplate` | URI pattern for partial segments |

## Next Steps

- <doc:LivePlaylists> — Full segment playlist management
- <doc:LiveSegmentation> — Produce segments and partial segments
- <doc:LiveStreaming> — Complete pipeline architecture
