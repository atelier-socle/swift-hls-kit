# Live Playlist Management

@Metadata {
    @PageKind(article)
}

Manage live HLS playlists with sliding windows, DVR buffers, and event recording.

## Overview

HLSKit provides three playlist strategies through the ``LivePlaylistManager`` protocol: ``SlidingWindowPlaylist`` for standard live, ``DVRPlaylist`` for time-shifted playback, and ``EventPlaylist`` for recording entire events.

### Sliding Window Playlist

``SlidingWindowPlaylist`` maintains a sliding window of recent segments. Old segments are removed as new ones arrive — this is the standard live HLS behavior with no `EXT-X-PLAYLIST-TYPE` tag:

```swift
let config = SlidingWindowConfiguration(
    targetDuration: 6,
    maxSegmentCount: 5
)
let playlist = SlidingWindowPlaylist(configuration: config)
```

### DVR Playlist

``DVRPlaylist`` retains segments within a time-based window, enabling DVR (time-shift) playback:

```swift
let config = DVRPlaylistConfiguration(
    targetDuration: 6,
    dvrWindowDuration: 300  // 5-minute rewind window
)
let playlist = DVRPlaylist(configuration: config)
```

``DVRBuffer`` manages the underlying segment storage with time-based eviction.

### Event Playlist

``EventPlaylist`` retains all segments from the start of the event. It uses `EXT-X-PLAYLIST-TYPE:EVENT` and appends an `EXT-X-ENDLIST` tag when the event ends:

```swift
let config = EventPlaylistConfiguration(targetDuration: 6)
let playlist = EventPlaylist(configuration: config)
```

### Playlist Rendering

`PlaylistRenderer` generates the M3U8 output from any playlist manager's segment state:

```swift
let renderer = PlaylistRenderer()
let m3u8 = renderer.render(
    segments: segments,
    targetDuration: 6,
    mediaSequence: 0
)
// m3u8 contains #EXTM3U, #EXT-X-TARGETDURATION, #EXTINF, etc.
```

### Media Sequence Tracking

`MediaSequenceTracker` tracks HLS media sequence and discontinuity sequence numbers as segments are added and removed.

### Playlist Events

``LivePlaylistEvent`` notifies your app of lifecycle changes (segment added, segment removed, playlist rendered, etc.).

### Metadata

``LivePlaylistMetadata`` lets you attach independent segments, start offset, and custom tags to a live playlist.

## Next Steps

- <doc:LiveSegmentation> — Produce segments for playlist management
- <doc:LowLatencyHLS> — LL-HLS partial segments and blocking reload
- <doc:LiveRecording> — Record events and convert to VOD
