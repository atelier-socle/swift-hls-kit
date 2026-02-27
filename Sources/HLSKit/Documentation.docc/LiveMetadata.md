# Live Metadata

@Metadata {
    @PageKind(article)
}

Inject timed metadata into live HLS streams — ID3, SCTE-35, DateRange, and HLS Interstitials.

## Overview

HLSKit provides ``LiveMetadataInjector`` as the central orchestrator for real-time metadata insertion. It coordinates ID3 timed metadata, `EXT-X-DATERANGE` tags, `EXT-X-PROGRAM-DATE-TIME` synchronization, SCTE-35 markers, and HLS Interstitials.

### Metadata Injector

``LiveMetadataInjector`` manages all metadata types during a live stream:

```swift
let injector = LiveMetadataInjector()
```

### ID3 Timed Metadata

``ID3TimedMetadata`` creates ID3v2 timed metadata for injection into HLS segments. Common uses include chapter markers, now-playing info, and custom data:

```swift
let metadata = ID3TimedMetadata(
    timestamp: 10.0,
    entries: [
        .text(id: "TIT2", value: "Chapter 1: Introduction"),
        .text(id: "TALB", value: "My Podcast")
    ]
)
```

### DateRange Manager

``DateRangeManager`` manages the lifecycle of `EXT-X-DATERANGE` tags in a live playlist. Date ranges can be open-ended (updated in real time) or closed:

```swift
let manager = DateRangeManager()
await manager.addDateRange(
    id: "ad-break-1",
    startDate: Date(),
    plannedDuration: 30.0,
    scte35Cmd: scte35Data
)
```

### SCTE-35 Markers

``SCTE35Marker`` models SCTE-35 splice information for ad insertion in live HLS streams. Supports splice insert, time signal, and segmentation descriptors:

```swift
let marker = SCTE35Marker(
    type: .spliceInsert,
    eventID: 1001,
    duration: 30.0,
    autoReturn: true
)
```

### HLS Interstitials

``HLSInterstitial`` models Apple HLS Interstitials for content insertion (ads, bumpers, promos):

```swift
let interstitial = HLSInterstitial(
    id: "ad-001",
    startDate: Date(),
    duration: 30.0,
    assetURI: URL(string: "https://cdn.example.com/ads/spot1.m3u8")!,
    resumeOffset: 0
)
```

``InterstitialManager`` provides a higher-level API for managing multiple interstitials during a live stream.

### Program Date-Time Sync

``ProgramDateTimeSync`` maintains `EXT-X-PROGRAM-DATE-TIME` synchronization between the live stream and wall clock time.

### Variable Substitution

``VariableResolver`` handles `EXT-X-DEFINE` variable substitution in HLS playlists, replacing `{$variable}` references with their defined values.

## Next Steps

- <doc:LiveStreaming> — Full pipeline architecture
- <doc:LivePlaylists> — Playlist management with metadata
- <doc:LiveRecording> — Record metadata alongside segments
