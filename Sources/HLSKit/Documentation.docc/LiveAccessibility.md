# Accessibility & Resilience

@Metadata {
    @PageKind(article)
}

Add closed captions, subtitles, audio descriptions, and resilience features to HLS streams.

## Overview

HLSKit provides comprehensive accessibility support through ``AccessibilityRenditionGenerator`` and resilience features through ``FailoverManager``, ``GapHandler``, and ``ContentSteeringConfig``.

### Closed Captions

``ClosedCaptionConfig`` supports both CEA-608 and CEA-708 standards:

```swift
let captions = ClosedCaptionConfig.broadcast708
let issues = captions.validate()
// issues.isEmpty == true
```

### Audio Descriptions

``AudioDescriptionConfig`` configures audio description tracks for visually impaired users:

```swift
let audioDescs: [(config: AudioDescriptionConfig, uri: String)] = [
    (config: .english, uri: "ad/en.m3u8"),
    (config: .french, uri: "ad/fr.m3u8")
]
```

### Live Subtitles

``LiveWebVTTWriter`` generates WebVTT subtitle segments in real time:

```swift
let writer = LiveWebVTTWriter(segmentDuration: 6.0)
await writer.addCue(
    WebVTTCue(startTime: 0, endTime: 3, text: "Welcome to the show")
)
let vttContent = await writer.renderSegment()
// vttContent contains WEBVTT header and cue data
```

``LiveSubtitlePlaylist`` generates a live media playlist for WebVTT segments:

```swift
var playlist = LiveSubtitlePlaylist(language: "en", name: "English")
playlist.addSegment(uri: "subs/en/seg0.vtt", duration: 6.0)
```

### Accessibility Rendition Generator

``AccessibilityRenditionGenerator`` combines all accessibility tracks into `EXT-X-MEDIA` entries:

```swift
let generator = AccessibilityRenditionGenerator()
let entries = generator.generateAll(
    captions: ClosedCaptionConfig.broadcast708,
    subtitles: [(playlist: subtitlePlaylist, uri: "subs/en/main.m3u8")],
    audioDescriptions: audioDescs
)
// entries includes caption, subtitle, and audio description renditions
```

### Failover & Redundancy

``RedundantStreamConfig`` defines primary/backup stream pairs:

```swift
let redundancy = RedundantStreamConfig(backups: [
    .init(
        primaryURI: "primary/720p.m3u8",
        backupURIs: ["backup-a/720p.m3u8", "backup-b/720p.m3u8"]
    )
])
let issues = redundancy.validate()
// issues.isEmpty == true
```

``FailoverManager`` tracks failures and automatically switches to backup URIs:

```swift
var failover = FailoverManager(config: redundancy)
failover.reportFailure(for: "primary/720p.m3u8")
// failover.activeURI(for: "primary/720p.m3u8") == "backup-a/720p.m3u8"

failover.reportRecovery(for: "primary/720p.m3u8")
// Back to primary
```

### Gap Signaling

``GapHandler`` manages `EXT-X-GAP` tags during stream outages:

```swift
var handler = GapHandler(maxConsecutiveGaps: 3)
handler.markGap(at: 5)
handler.markGap(at: 6)
// handler.isGap(at: 5) == true
// handler.gapCount == 2
```

### Content Steering

``ContentSteeringConfig`` enables dynamic CDN switching via `EXT-X-CONTENT-STEERING`:

```swift
let steering = ContentSteeringConfig(
    serverURI: "https://cdn.example.com/steering",
    pathways: ["CDN-A", "CDN-B", "CDN-C"],
    defaultPathway: "CDN-A"
)
let tag = steering.steeringTag()
// tag contains EXT-X-CONTENT-STEERING
```

### Session Data

``SessionDataConfig`` provides `EXT-X-SESSION-DATA` for carrying metadata in master playlists.

## Next Steps

- <doc:LiveStreaming> — Full pipeline overview
- <doc:LiveDRM> — DRM protection
- <doc:LivePresets> — Accessible pipeline presets
