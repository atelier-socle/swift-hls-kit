# Video Projection Specifiers

Signal video layout and projection type in HLS manifests with REQ-VIDEO-LAYOUT.

@Metadata {
    @PageKind(article)
}

## Overview

The `REQ-VIDEO-LAYOUT` attribute on `EXT-X-STREAM-INF` tells the player how the video frames should be displayed — whether they carry stereoscopic left/right views, 360-degree equirectangular projections, or Apple Immersive Video content. HLSKit models this with ``VideoLayoutDescriptor`` (the composite attribute value) and two supporting enums: ``VideoChannelLayout`` for the stereo arrangement and ``VideoProjection`` for the projection geometry.

## Video Projections

``VideoProjection`` enumerates the projection types defined in Apple's HLS specification:

| Case | Raw Value | Description |
|------|-----------|-------------|
| `.rectilinear` | `PROJ-RECT` | Standard flat video (default for traditional content) |
| `.equirectangular` | `PROJ-EQUI` | Full 360-degree spherical projection |
| `.halfEquirectangular` | `PROJ-HEQU` | 180-degree hemisphere (Apple Vision Pro spatial) |
| `.primary` | `PROJ-PRIM` | Primary view of a multi-view stream |
| `.appleImmersiveVideo` | `PROJ-AIV` | Apple Immersive Video format |

```swift
let proj = VideoProjection.equirectangular
// proj.rawValue == "PROJ-EQUI"
```

## Layout Descriptors

``VideoLayoutDescriptor`` combines an optional ``VideoChannelLayout`` with an optional ``VideoProjection`` into a single attribute value string. The `attributeValue` property produces the string used in `REQ-VIDEO-LAYOUT`:

```swift
let descriptor = VideoLayoutDescriptor(
    channelLayout: .stereoLeftRight,
    projection: .halfEquirectangular
)
// descriptor.attributeValue == "CH-STEREO,PROJ-HEQU"
```

Five built-in presets cover common scenarios:

| Preset | Channel | Projection | Attribute Value |
|--------|---------|-----------|----------------|
| ``VideoLayoutDescriptor/stereo`` | CH-STEREO | — | `CH-STEREO` |
| ``VideoLayoutDescriptor/mono`` | CH-MONO | — | `CH-MONO` |
| ``VideoLayoutDescriptor/video360`` | — | PROJ-EQUI | `PROJ-EQUI` |
| ``VideoLayoutDescriptor/immersive180`` | CH-STEREO | PROJ-HEQU | `CH-STEREO,PROJ-HEQU` |
| ``VideoLayoutDescriptor/appleImmersive`` | CH-STEREO | PROJ-AIV | `CH-STEREO,PROJ-AIV` |

## Parsing

``VideoLayoutDescriptor/parse(_:)`` converts an attribute value string back to a descriptor:

```swift
let descriptor = VideoLayoutDescriptor.parse("CH-STEREO,PROJ-HEQU")
// descriptor.channelLayout == .stereoLeftRight
// descriptor.projection == .halfEquirectangular

let stereoOnly = VideoLayoutDescriptor.parse("CH-STEREO")
// stereoOnly.channelLayout == .stereoLeftRight
// stereoOnly.projection == nil

let projOnly = VideoLayoutDescriptor.parse("PROJ-EQUI")
// projOnly.channelLayout == nil
// projOnly.projection == .equirectangular
```

Round-trips preserve equality:

```swift
let original = VideoLayoutDescriptor(
    channelLayout: .stereoLeftRight,
    projection: .halfEquirectangular
)
let reparsed = VideoLayoutDescriptor.parse(original.attributeValue)
// reparsed == original
```

## Manifest Integration

``ManifestParser`` reads `REQ-VIDEO-LAYOUT` from `EXT-X-STREAM-INF` and populates `Variant.videoLayoutDescriptor`:

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-STREAM-INF:BANDWIDTH=10000000,\
    CODECS="hvc1.2.4.L123.B0",\
    RESOLUTION=1920x1080,\
    REQ-VIDEO-LAYOUT="CH-STEREO"
    spatial/1080p_stereo.m3u8
    """
let manifest = try ManifestParser().parse(m3u8)
guard case .master(let playlist) = manifest else { return }

let layout = playlist.variants[0].videoLayoutDescriptor
// layout?.channelLayout == .stereoLeftRight
```

``ManifestGenerator`` emits `REQ-VIDEO-LAYOUT` when a variant has a layout descriptor:

```swift
let variant = Variant(
    bandwidth: 10_000_000,
    resolution: Resolution(width: 1920, height: 1080),
    uri: "spatial/1080p.m3u8",
    codecs: "hvc1.2.4.L123.B0",
    videoLayoutDescriptor: .stereo
)
let playlist = MasterPlaylist(version: .v7, variants: [variant])
let output = ManifestGenerator().generateMaster(playlist)
// output contains: REQ-VIDEO-LAYOUT="CH-STEREO"
```

## Complete Vision Pro Pattern

A full multivariant manifest for Apple Vision Pro with stereoscopic Dolby Vision, standard stereo, 2D fallback, and IMSC1 subtitles:

```swift
let playlist = MasterPlaylist(
    version: .v7,
    variants: [
        Variant(
            bandwidth: 15_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "spatial/4k_dv.m3u8",
            codecs: "hvc1.2.4.L153.B0",
            subtitles: "subs",
            videoRange: .pq,
            supplementalCodecs: "dvh1.20.09/db4h",
            videoLayoutDescriptor: .immersive180
        ),
        Variant(
            bandwidth: 10_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "spatial/1080p.m3u8",
            codecs: "hvc1.2.4.L123.B0",
            subtitles: "subs",
            videoLayoutDescriptor: .stereo
        ),
        Variant(
            bandwidth: 4_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "video/1080p_2d.m3u8",
            codecs: "avc1.640028,mp4a.40.2",
            subtitles: "subs"
        )
    ],
    renditions: [
        Rendition(
            type: .subtitles,
            groupId: "subs",
            name: "English",
            uri: "subtitles/en.m3u8",
            language: "en",
            isDefault: true,
            autoselect: true,
            codec: SubtitleCodec.imsc1.rawValue
        )
    ],
    independentSegments: true
)

let output = ManifestGenerator().generateMaster(playlist)
// SUPPLEMENTAL-CODECS="dvh1.20.09/db4h"
// REQ-VIDEO-LAYOUT="CH-STEREO,PROJ-HEQU"
// REQ-VIDEO-LAYOUT="CH-STEREO"
// VIDEO-RANGE=PQ
```

## Next Steps

- <doc:SpatialVideoGuide> — MV-HEVC packaging for Apple Vision Pro
- <doc:IMSC1SubtitlesGuide> — IMSC1 subtitle support
- <doc:HDRVideo> — HDR and Dolby Vision configuration
