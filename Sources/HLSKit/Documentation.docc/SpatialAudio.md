# Spatial Audio & Hi-Res

@Metadata {
    @PageKind(article)
}

Add Dolby Atmos, multi-channel surround, and Hi-Res audio support to HLS streams.

## Overview

HLSKit supports spatial audio formats (Dolby Atmos, AC-3, E-AC-3), multi-channel layouts (5.1, 7.1, 7.1.4), and Hi-Res audio (96/192 kHz, 24/32-bit, ALAC, FLAC). ``SpatialRenditionGenerator`` produces the `EXT-X-MEDIA` entries needed in master playlists.

### Spatial Audio Configuration

``SpatialAudioConfig`` describes the spatial format and channel layout:

```swift
let config = SpatialAudioConfig.atmos5_1
// config.format == .dolbyAtmos
// config.channelLayout == .surround5_1
```

Preset configurations: `.atmos5_1`, `.surround5_1_eac3`, `.stereo_aac`.

### Rendition Generation

``SpatialRenditionGenerator`` generates `EXT-X-MEDIA` entries for spatial and multi-channel audio:

```swift
let generator = SpatialRenditionGenerator()
let renditions = generator.generateRenditions(
    config: .atmos5_1,
    language: "en",
    name: "English (Atmos)"
)
// renditions includes Atmos (ec+3) and stereo fallback entries
let tag = renditions[0].formatAsTag()
// tag contains EXT-X-MEDIA TYPE=AUDIO
```

For multi-language support:

```swift
let tracks: [SpatialRenditionGenerator.AudioTrackDescriptor] = [
    .init(language: "en", name: "English", config: .atmos5_1, uri: "audio/en/main.m3u8"),
    .init(language: "fr", name: "Français", config: .atmos5_1, uri: "audio/fr/main.m3u8")
]
let renditions = generator.generateMultiLanguageRenditions(tracks: tracks)
```

### Multi-Channel Layouts

``MultiChannelLayout`` defines standard audio channel layouts with HLS mapping:

| Layout | Channels | Use Case |
|--------|----------|----------|
| `.mono` | 1 | Commentary |
| `.stereo` | 2 | Standard audio |
| `.surround5_1` | 6 | Surround sound |
| `.surround7_1` | 8 | Extended surround |
| `.atmos7_1_4` | 12 | Dolby Atmos immersive |

### Encoders

- ``DolbyAtmosEncoder`` — Dolby Atmos via E-AC-3 JOC (Joint Object Coding)
- ``AC3Encoder`` — AC-3 and E-AC-3 (Dolby Digital/Plus)
- ``SpatialAudioEncoder`` — Protocol for spatial audio encoding

### Hi-Res Audio

``HiResAudioConfig`` configures high-resolution audio for HLS:

```swift
let config = HiResAudioConfig(
    sampleRate: 96000,
    bitDepth: 24,
    codec: .alac
)
```

Supports 96/192 kHz sample rates, 24/32-bit depth, and ALAC/FLAC codecs.

## Next Steps

- <doc:AudioProcessing> — Audio format conversion and loudness
- <doc:LivePresets> — Pipeline presets with spatial audio
- <doc:LiveStreaming> — Integrate spatial audio in live pipelines
