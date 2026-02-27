# HDR & Ultra-Resolution

@Metadata {
    @PageKind(article)
}

Support HDR10, HLG, Dolby Vision, and ultra-resolution video up to 8K in HLS streams.

## Overview

HLSKit provides ``HDRConfig`` for unified HDR configuration, ``HDRVariantGenerator`` for producing HLS variant entries with correct `VIDEO-RANGE` and `SUPPLEMENTAL-CODECS` attributes, and ``VideoRangeMapper`` for mapping HDR metadata to HLS manifest attributes.

### HDR Configuration

``HDRConfig`` describes the HDR format, video range, bit depth, and optional supplemental codecs:

```swift
let config = HDRConfig.hdr10Default
// config.type == .hdr10
// config.videoRange == .pq
```

Presets: `.hdr10Default`, `.hlgDefault`, `.dolbyVisionProfile8`, `.dolbyVisionProfile5`.

### Variant Generation

``HDRVariantGenerator`` creates an adaptive bitrate ladder with HDR and SDR fallback variants:

```swift
let generator = HDRVariantGenerator()
let ladder = generator.generateAdaptiveLadder(hdrConfig: .hdr10Default)

let hdrVariants = ladder.filter { !$0.isSDRFallback }
let sdrVariants = ladder.filter { $0.isSDRFallback }
// Both HDR and SDR variants included for compatibility
```

Generate variants for specific resolutions:

```swift
let variants = generator.generateVariants(
    hdrConfig: .dolbyVisionProfile8,
    resolutions: [.uhd4K]
)
let attrs = variants[0].formatAttributes()
// attrs contains VIDEO-RANGE and SUPPLEMENTAL-CODECS
```

Validate your ladder for compliance:

```swift
let warnings = generator.validateLadder(ladder)
// warnings.isEmpty == true for a well-formed ladder
```

### Video Range

``VideoRange`` maps to the HLS `VIDEO-RANGE` attribute:

| Range | Description |
|-------|-------------|
| `.sdr` | Standard Dynamic Range |
| `.pq` | Perceptual Quantizer (HDR10, Dolby Vision) |
| `.hlg` | Hybrid Log-Gamma |

### Video Range Mapper

``VideoRangeMapper`` translates HDR configuration to HLS manifest attributes:

```swift
let mapper = VideoRangeMapper()
let attrs = mapper.mapToHLSAttributes(config: .hdr10Default)
// attrs.videoRange == .pq
// attrs.minimumBitDepth >= 10
```

### Dolby Vision

``DolbyVisionProfile`` configures Dolby Vision profiles and levels, generating the `SUPPLEMENTAL-CODECS` string:

```swift
let config = HDRConfig.dolbyVisionProfile8
// config.supplementalCodecs contains "dvh1" codec string
```

### Ultra-Resolution Presets

``ResolutionPreset`` provides standard video resolution presets from SD to 8K:

| Preset | Resolution | Typical Bitrate |
|--------|-----------|----------------|
| `.sd480` | 854x480 | 1.5 Mbps |
| `.hd720` | 1280x720 | 3 Mbps |
| `.fullHD` | 1920x1080 | 6 Mbps |
| `.uhd4K` | 3840x2160 | 16 Mbps |
| `.uhd8K` | 7680x4320 | 50 Mbps |

## Next Steps

- <doc:LivePresets> — Pipeline presets with HDR video
- <doc:SpatialAudio> — Combine HDR with spatial audio
- <doc:LiveStreaming> — Full pipeline overview
