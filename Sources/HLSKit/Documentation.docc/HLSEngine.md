# HLSEngine

Use the ``HLSEngine`` facade for high-level HLS workflows.

## Overview

``HLSEngine`` is the primary entry point for HLSKit. It provides a unified API that combines parsing, generation, validation, segmentation, transcoding, and encryption — all through a single `Sendable` struct.

### Create an Engine

```swift
let engine = HLSEngine()
```

### Parse Manifests

Parse any M3U8 string into a typed ``Manifest``:

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-STREAM-INF:BANDWIDTH=800000
    480p/playlist.m3u8
    """

let manifest = try engine.parse(m3u8)

if case .master(let playlist) = manifest {
    // Access typed playlist properties
}
```

### Generate Manifests

Serialize playlist models back to M3U8:

```swift
let playlist = MasterPlaylist(
    version: .v7,
    variants: [
        Variant(bandwidth: 800_000, resolution: .p480, uri: "480p/playlist.m3u8")
    ]
)

let m3u8 = engine.generate(playlist)
// m3u8 contains #EXTM3U, #EXT-X-VERSION:7, BANDWIDTH=800000
```

You can also generate media playlists:

```swift
let mediaPlaylist = MediaPlaylist(
    version: .v3,
    targetDuration: 10,
    playlistType: .vod,
    hasEndList: true,
    segments: [
        Segment(duration: 9.009, uri: "segment001.ts")
    ]
)

let m3u8 = engine.generate(mediaPlaylist)
```

### Validate Manifests

Check playlists against RFC 8216 and Apple HLS rules:

```swift
let report = engine.validate(manifest)
// report.isValid == true

let mediaReport = engine.validate(mediaPlaylist)
// mediaReport.isValid == true
```

### Parse and Validate

Combine parsing and validation in one call:

```swift
let (manifest, report) = try engine.parseAndValidate(m3u8)
// Access both the parsed manifest and validation report
```

### Regenerate Manifests

Round-trip a manifest through parse and generate:

```swift
let output = try engine.regenerate(m3u8)
// output contains #EXTM3U, #EXTINF, segment URIs
```

### Segment Media

Split MP4 data into HLS segments:

```swift
let config = SegmentationConfig(containerFormat: .fragmentedMP4)
let result = try engine.segment(data: mp4Data, config: config)

// result.segmentCount > 0
// result.hasInitSegment == true
// result.playlist contains the generated M3U8
```

With byte-range mode:

```swift
let config = SegmentationConfig(outputMode: .byteRange)
let result = try engine.segment(data: mp4Data, config: config)
```

### Encrypt Segments

Encrypt existing segments:

```swift
let segResult = try engine.segment(data: mp4Data)
let key = try KeyManager().generateKey()
let encConfig = EncryptionConfig(
    method: .aes128,
    keyURL: URL(string: "https://example.com/key")!,
    key: key
)

let encResult = try engine.encrypt(segments: segResult, config: encConfig)
// encResult.segmentCount == segResult.segmentCount
// encResult.playlist contains "AES-128"
```

### Check Transcoder Availability

```swift
let available = engine.isTranscoderAvailable
```

### Inspect MP4 Files

Use the container-level APIs to inspect media files:

```swift
let boxes = try MP4BoxReader().readBoxes(from: mp4Data)
let fileInfo = try MP4InfoParser().parseFileInfo(from: boxes)

// fileInfo.timescale > 0
// fileInfo.tracks contains track metadata
// fileInfo.durationSeconds > 0
```

## Next Steps

- <doc:ManifestParsing> — Deep dive into manifest parsing
- <doc:ManifestGeneration> — Advanced generation and builder DSL
- <doc:ValidatingManifests> — Detailed validation rules and reports
- <doc:SegmentingMedia> — Segmentation configuration and output
- <doc:TranscodingMedia> — Transcoding with quality presets
- <doc:EncryptingSegments> — Encryption methods and key management
- <doc:CLIReference> — Command-line workflows
