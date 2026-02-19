# Manifest Generation

Generate spec-compliant M3U8 output from playlist models with ``ManifestGenerator`` and the builder DSL.

## Overview

HLSKit can generate both master and media playlists from typed Swift models. You can construct playlists either with standard initializers or with the `@resultBuilder` DSL.

### Generate a Master Playlist

```swift
let playlist = MasterPlaylist(
    version: .v7,
    variants: [
        Variant(
            bandwidth: 800_000,
            resolution: .p480,
            uri: "480p/playlist.m3u8",
            codecs: "avc1.4d401e,mp4a.40.2"
        ),
        Variant(
            bandwidth: 2_800_000,
            resolution: .p720,
            uri: "720p/playlist.m3u8",
            codecs: "avc1.4d401f,mp4a.40.2"
        )
    ],
    independentSegments: true
)

let output = ManifestGenerator().generateMaster(playlist)
// output contains #EXTM3U, #EXT-X-VERSION:7, BANDWIDTH=800000, etc.
```

### Generate a Media Playlist

```swift
let playlist = MediaPlaylist(
    version: .v3,
    targetDuration: 6,
    playlistType: .vod,
    hasEndList: true,
    segments: [
        Segment(duration: 6.006, uri: "segment000.ts"),
        Segment(duration: 5.839, uri: "segment001.ts")
    ]
)

let output = ManifestGenerator().generateMedia(playlist)
// output contains #EXT-X-TARGETDURATION:6, #EXTINF:6.006, #EXT-X-ENDLIST
```

### Byte-Range Playlist

```swift
let playlist = MediaPlaylist(
    version: .v4,
    targetDuration: 6,
    hasEndList: true,
    segments: [
        Segment(duration: 6.0, uri: "main.ts", byteRange: ByteRange(length: 1024, offset: 0)),
        Segment(duration: 6.0, uri: "main.ts", byteRange: ByteRange(length: 1024, offset: 1024))
    ]
)

let output = ManifestGenerator().generateMedia(playlist)
// output contains #EXT-X-BYTERANGE:1024@0, #EXT-X-BYTERANGE:1024@1024
```

### Encrypted Playlist

```swift
let key = EncryptionKey(method: .aes128, uri: "https://example.com/key")
let playlist = MediaPlaylist(
    targetDuration: 6,
    hasEndList: true,
    segments: [
        Segment(duration: 6.0, uri: "enc_seg0.ts", key: key)
    ]
)

let output = ManifestGenerator().generateMedia(playlist)
// output contains METHOD=AES-128, URI="https://example.com/key"
```

### Alternate Audio Renditions

```swift
let playlist = MasterPlaylist(
    variants: [
        Variant(bandwidth: 2_800_000, uri: "video.m3u8", audio: "audio-group")
    ],
    renditions: [
        Rendition(
            type: .audio, groupId: "audio-group", name: "English",
            uri: "audio/en.m3u8", language: "en", isDefault: true
        )
    ]
)

let output = ManifestGenerator().generateMaster(playlist)
// output contains TYPE=AUDIO, GROUP-ID="audio-group", NAME="English"
```

### Builder DSL

Use the `@resultBuilder` DSL to construct playlists declaratively:

#### Master Playlist Builder

```swift
let playlist = MasterPlaylist {
    Variant(bandwidth: 800_000, resolution: .p480, uri: "480p/playlist.m3u8")
    Variant(bandwidth: 2_800_000, resolution: .p720, uri: "720p/playlist.m3u8")
    Variant(bandwidth: 5_000_000, resolution: .p1080, uri: "1080p/playlist.m3u8")
}
// playlist.variants.count == 3
```

You can also include renditions in the builder:

```swift
let playlist = MasterPlaylist {
    Variant(bandwidth: 2_800_000, uri: "video.m3u8")
    Rendition(type: .audio, groupId: "audio-en", name: "English", uri: "audio/en.m3u8")
}
// playlist.variants.count == 1
// playlist.renditions.count == 1
```

#### Media Playlist Builder

```swift
let playlist = MediaPlaylist(targetDuration: 6) {
    Segment(duration: 6.006, uri: "segment001.ts")
    Segment(duration: 5.839, uri: "segment002.ts")
    Segment(duration: 6.006, uri: "segment003.ts")
}
// playlist.segments.count == 3
```

With playlist type:

```swift
let playlist = MediaPlaylist(targetDuration: 10, playlistType: .vod) {
    Segment(duration: 9.009, uri: "seg001.ts")
}
// playlist.playlistType == .vod
```

### Low-Latency HLS Models

HLSKit supports Low-Latency HLS extensions for live streaming:

```swift
let control = ServerControl(
    canBlockReload: true,
    canSkipUntil: 36.0,
    canSkipDateRanges: true,
    holdBack: 12.0,
    partHoldBack: 3.0
)

let part = PartialSegment(uri: "part001.mp4", duration: 1.0, independent: true)
let hint = PreloadHint(type: .part, uri: "next-part.mp4")
```

### Low-Level Tag Writing

For fine-grained control, use ``TagWriter`` directly:

```swift
let writer = TagWriter()
writer.writeExtInf(duration: 6.006, title: nil, version: .v3)
// "#EXTINF:6.006,"

writer.writeByteRange(ByteRange(length: 1024, offset: 512))
// "#EXT-X-BYTERANGE:1024@512"

writer.writeKey(EncryptionKey(method: .aes128, uri: "key.bin"))
// "#EXT-X-KEY:METHOD=AES-128,URI=\"key.bin\""

writer.writeMap(MapTag(uri: "init.mp4"))
// "#EXT-X-MAP:URI=\"init.mp4\""
```

## Next Steps

- <doc:ManifestParsing> — Parse M3U8 text into typed models
- <doc:ValidatingManifests> — Validate generated playlists against RFC 8216
- <doc:HLSEngine> — Use the engine facade for round-trip workflows
