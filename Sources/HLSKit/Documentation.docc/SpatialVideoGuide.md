# MV-HEVC Spatial Video

Package stereoscopic MV-HEVC content for Apple Vision Pro with HLSKit.

@Metadata {
    @PageKind(article)
}

## Overview

MV-HEVC (Multi-View HEVC) encodes left and right eye views in a single HEVC bitstream,
enabling stereoscopic 3D playback on Apple Vision Pro while providing automatic 2D fallback
on other devices. HLSKit provides a complete packaging pipeline: ``MVHEVCSampleProcessor``
extracts HEVC parameter sets from NAL units, ``MVHEVCPackager`` produces ISO BMFF init and
media segments with the required spatial boxes (`vexu`, `stri`, `hero`), and
``SpatialVideoConfiguration`` captures resolution, codec, and Dolby Vision settings in
reusable presets.

## Spatial Video Configuration

``SpatialVideoConfiguration`` describes the encoding parameters for a stereoscopic stream.
Properties include `baseLayerCodec` (the HEVC codec string), `supplementalCodecs` (Dolby
Vision overlay), `channelLayout` (stereo or mono), `dolbyVisionProfile`, `width`, `height`,
and `frameRate`.

Three built-in presets cover common Apple Vision Pro scenarios:

| Preset | Resolution | Frame Rate | Dolby Vision | Codec |
|--------|-----------|------------|-------------|-------|
| ``SpatialVideoConfiguration/visionProStandard`` | 1920x1080 | 30 fps | No | hvc1.2.4.L123.B0 |
| ``SpatialVideoConfiguration/visionProHighQuality`` | 3840x2160 | 30 fps | No | hvc1.2.4.L153.B0 |
| ``SpatialVideoConfiguration/dolbyVisionStereo`` | 3840x2160 | 30 fps | Profile 20 | hvc1.2.4.L153.B0 + dvh1.20.09/db4h |

```swift
let standard = SpatialVideoConfiguration.visionProStandard
// standard.width == 1920
// standard.height == 1080
// standard.channelLayout == .stereoLeftRight

let dolby = SpatialVideoConfiguration.dolbyVisionStereo
// dolby.supplementalCodecs == "dvh1.20.09/db4h"
// dolby.dolbyVisionProfile == 20
```

## Channel Layouts

``VideoChannelLayout`` identifies the stereo arrangement:

- `.stereoLeftRight` (`"CH-STEREO"`) — left and right eye views, used for all stereoscopic content
- `.mono` (`"CH-MONO"`) — single view, for 2D content in a spatial container

```swift
let layout = VideoChannelLayout.stereoLeftRight
// layout.rawValue == "CH-STEREO"
```

## Sample Processing

``MVHEVCSampleProcessor`` handles HEVC NAL unit parsing, which is the prerequisite for
building init segments.

### Extracting NAL Units

`extractNALUs(from:)` splits Annex B bitstream data at start codes (`0x00000001` or
`0x000001`):

```swift
let processor = MVHEVCSampleProcessor()
let nalus = processor.extractNALUs(from: annexBData)
```

### Identifying NAL Unit Types

`naluType(_:)` identifies the NAL unit type from the first byte using the formula
`(byte >> 1) & 0x3F`:

```swift
let vpsNalu = Data([0x40, 0x01, 0xAA])
processor.naluType(vpsNalu)  // .vps (type 32)

let spsNalu = Data([0x42, 0x01, 0xBB])
processor.naluType(spsNalu)  // .sps (type 33)

let ppsNalu = Data([0x44, 0x01, 0xCC])
processor.naluType(ppsNalu)  // .pps (type 34)
```

``HEVCNALUType`` covers: `trailN`, `trailR`, `idrWRadl`, `idrNLP`, `vps`, `sps`, `pps`,
`prefixSEI`, `suffixSEI`.

### Extracting Parameter Sets

`extractParameterSets(from:)` filters VPS, SPS, and PPS from a NAL unit array:

```swift
let parameterSets = processor.extractParameterSets(from: nalus)
// parameterSets?.vps, .sps, .pps — Data for each
```

### SPS Profile Parsing

`parseSPSProfile(_:)` extracts codec-level details from the SPS NAL unit:

```swift
let profile = processor.parseSPSProfile(spsData)
// profile?.profileIDC, .levelIDC, .chromaFormatIDC, .bitDepthLuma, ...
```

## fMP4 Packaging

``MVHEVCPackager`` creates ISO BMFF segments with the complete MV-HEVC box hierarchy.

### Init Segment

The init segment contains `ftyp` + `moov` with the `hvc1` sample entry carrying `hvcC`
(HEVC decoder configuration), `vexu` (video extended usage), `eyes`/`stri` (stereo view
information), and `hero` (hero eye description):

```swift
let packager = MVHEVCPackager()
let parameterSets = HEVCParameterSets(
    vps: vpsData, sps: spsData, pps: ppsData
)
let config = SpatialVideoConfiguration.visionProStandard
let initSegment = packager.createInitSegment(
    configuration: config,
    parameterSets: parameterSets
)
// initSegment contains: ftyp, moov, hvc1, hvcC, vexu, stri, hero
```

### Media Segments

Each media segment wraps NAL units in `moof` + `mdat`:

```swift
let mediaSegment = packager.createMediaSegment(
    nalus: frameNALUs,
    configuration: config,
    sequenceNumber: 1,
    baseDecodeTime: 0,
    sampleDurations: [3000]  // in timescale units
)
```

## Supplemental Codecs

``SupplementalCodecs`` models the `SUPPLEMENTAL-CODECS` attribute on `EXT-X-STREAM-INF`.
Two Dolby Vision presets:

```swift
let dv20 = SupplementalCodecs.dolbyVisionProfile20
// dv20.value == "dvh1.20.09/db4h"

let dv8 = SupplementalCodecs.dolbyVisionProfile8
// dv8.value == "dvh1.08.09/db4h"
```

## Manifest Pattern

A complete Apple Vision Pro manifest with stereoscopic, Dolby Vision, and 2D fallback:

```swift
let playlist = MasterPlaylist(
    version: .v7,
    variants: [
        Variant(
            bandwidth: 15_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "spatial/4k_dv.m3u8",
            codecs: "hvc1.2.4.L153.B0",
            videoRange: .pq,
            supplementalCodecs: "dvh1.20.09/db4h",
            videoLayoutDescriptor: .immersive180
        ),
        Variant(
            bandwidth: 10_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "spatial/1080p_stereo.m3u8",
            codecs: "hvc1.2.4.L123.B0",
            videoLayoutDescriptor: .stereo
        ),
        Variant(
            bandwidth: 4_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "video/1080p_2d.m3u8",
            codecs: "avc1.640028,mp4a.40.2"
        )
    ],
    independentSegments: true
)

let output = ManifestGenerator().generateMaster(playlist)
// Contains: SUPPLEMENTAL-CODECS="dvh1.20.09/db4h"
// Contains: REQ-VIDEO-LAYOUT="CH-STEREO,PROJ-HEQU"
// Contains: VIDEO-RANGE=PQ
```

## Pipeline Integration

``LivePipelineConfiguration`` includes a spatial video preset:

```swift
let config = LivePipelineConfiguration.spatialVideo()
// config.videoEnabled == true
// config.videoBitrate == 10_000_000

let dvConfig = LivePipelineConfiguration.spatialVideo(
    channelLayout: .stereoLeftRight,
    dolbyVision: true
)
// dvConfig.videoBitrate == 15_000_000
```

## Platform Availability

``MVHEVCEncoder`` is available only where `VideoToolbox` is present
(`#if canImport(VideoToolbox)` -- macOS, iOS, tvOS, visionOS). The packaging pipeline
(``MVHEVCPackager``, ``MVHEVCSampleProcessor``) works cross-platform including Linux, as
it uses pure Swift binary operations.

## Next Steps

- <doc:ProjectionSpecifiers> -- Video projection and layout descriptors
- <doc:IMSC1SubtitlesGuide> -- Add subtitles to spatial video packages
- <doc:HDRVideo> -- HDR and Dolby Vision configuration
