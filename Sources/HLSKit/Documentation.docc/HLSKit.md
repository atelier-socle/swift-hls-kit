# ``HLSKit``

@Metadata {
    @DisplayName("HLSKit")
}

A pure Swift library for parsing, generating, segmenting, transcoding, encrypting, and validating HTTP Live Streaming content.

## Overview

**HLSKit** is the first pure Swift HLS library with zero external dependencies in its core. It covers the full HLS pipeline — from manifest parsing to encrypted segment delivery — with strict `Sendable` conformance throughout.

```swift
import HLSKit

let engine = HLSEngine()

// Parse a manifest
let manifest = try engine.parse(m3u8String)

// Validate against RFC 8216
let report = engine.validate(manifest)
print("Valid: \(report.isValid)")

// Generate an HLS manifest
let output = engine.generate(manifest)
```

### Key Features

- **Parse** — Full HLS manifest parsing with typed models for master and media playlists
- **Generate** — Produce spec-compliant M3U8 output from playlist models
- **Validate** — Check conformance against RFC 8216 and Apple HLS rules
- **Segment** — Split MP4 files into fMP4 or MPEG-TS segments with automatic playlist generation
- **Transcode** — Hardware-accelerated encoding via Apple VideoToolbox or FFmpeg
- **Encrypt** — AES-128 full-segment and SAMPLE-AES sample-level encryption
- **Builder DSL** — `@resultBuilder` syntax for constructing playlists declaratively
- **CLI** — `hlskit-cli` command-line tool with 6 commands for common workflows

### How It Works

1. **Model** — Typed Swift structs represent every HLS concept: ``MasterPlaylist``, ``MediaPlaylist``, ``Variant``, ``Segment``
2. **Parse** — ``ManifestParser`` converts M3U8 text into models
3. **Generate** — ``ManifestGenerator`` serializes models back to M3U8
4. **Segment** — ``MP4Segmenter`` and ``TSSegmenter`` split media files into HLS segments
5. **Validate** — ``HLSValidator`` checks playlists against industry rule sets

## Topics

### Essentials

- <doc:GettingStarted>

### Engine

- ``HLSEngine``

### Manifest Models

- ``Manifest``
- ``MasterPlaylist``
- ``MediaPlaylist``
- ``Variant``
- ``IFrameVariant``
- ``Segment``
- ``Rendition``
- ``Resolution``
- ``ByteRange``
- ``EncryptionKey``
- ``MapTag``
- ``DateRange``
- ``SessionData``
- ``ContentSteering``
- ``StartOffset``
- ``VariableDefinition``

### Low-Latency HLS Models

- ``ServerControl``
- ``PartialSegment``
- ``PreloadHint``
- ``PreloadHintType``
- ``RenditionReport``
- ``SkipInfo``

### Enumerations

- ``HLSVersion``
- ``PlaylistType``
- ``MediaType``
- ``EncryptionMethod``
- ``HDCPLevel``
- ``ClosedCaptionsValue``
- ``HLSTag``

### Parsing

- ``ManifestParser``
- ``TagParser``
- ``AttributeParser``

### Generation

- ``ManifestGenerator``
- ``TagWriter``

### Builder DSL

- ``MasterPlaylistBuilder``
- ``MasterPlaylistComponent``
- ``MediaPlaylistBuilder``
- ``MediaPlaylistComponent``

### Validation

- ``HLSValidator``
- ``ValidationReport``
- ``ValidationResult``
- ``ValidationSeverity``
- ``ValidationRuleSet``

### Segmentation

- ``MP4Segmenter``
- ``TSSegmenter``
- ``SegmentationConfig``
- ``SegmentationResult``
- ``MediaSegmentOutput``

### Transcoding

- ``Transcoder``
- ``AppleTranscoder``
- ``FFmpegTranscoder``
- ``TranscodingConfig``
- ``TranscodingResult``
- ``MultiVariantResult``
- ``QualityPreset``
- ``VideoProfile``
- ``VideoCodec``
- ``AudioCodec``
- ``VariantPlaylistBuilder``

### Encryption

- ``SegmentEncryptor``
- ``SampleEncryptor``
- ``KeyManager``
- ``EncryptionConfig``

### Container — MP4

- ``MP4BoxReader``
- ``MP4InfoParser``
- ``MP4FileInfo``
- ``MP4Box``
- ``MP4TrackAnalysis``
- ``TrackInfo``
- ``MediaTrackType``
- ``VideoDimensions``
- ``SampleTable``
- ``SampleTableParser``
- ``SampleLocator``
- ``SegmentInfo``
- ``TimeToSampleEntry``
- ``CompositionOffsetEntry``
- ``SampleToChunkEntry``
- ``InitSegmentWriter``
- ``MediaSegmentWriter``
- ``MuxedTrackInput``
- ``BinaryReader``
- ``BinaryWriter``

### Container — MPEG-TS

- ``TSSegmentBuilder``
- ``TSPacket``
- ``TSPacketWriter``
- ``TSCodecConfig``
- ``SampleData``
- ``ProgramTableGenerator``
- ``PESPacketizer``
- ``ADTSConverter``
- ``AnnexBConverter``
- ``AdaptationField``

### Errors

- ``ParserError``
- ``MP4Error``
- ``TranscodingError``
- ``EncryptionError``
- ``TransportError``
- ``BinaryReaderError``

### Articles

- <doc:ManifestParsing>
- <doc:ManifestGeneration>
- <doc:ValidatingManifests>
- <doc:SegmentingMedia>
- <doc:TranscodingMedia>
- <doc:EncryptingSegments>
- <doc:HLSEngine>
- <doc:CLIReference>
