# Live DRM

@Metadata {
    @PageKind(article)
}

Protect live HLS streams with FairPlay Streaming, key rotation, and multi-DRM (CENC) interoperability.

## Overview

HLSKit provides ``LiveDRMPipeline`` as the facade for live DRM orchestration, ``LiveKeyManager`` for encryption key lifecycle, and ``KeyRotationPolicy`` for rotating keys at configurable intervals.

### DRM Pipeline Configuration

``LiveDRMPipelineConfig`` is the lightweight configuration for ``LivePipelineConfiguration``:

```swift
let drm = LiveDRMPipelineConfig.fairPlayModern
// drm.isEnabled == true
// drm.fairPlay != nil
// drm.rotationPolicy == .everyNSegments(10)
```

Presets: `.fairPlayModern`, `.multiDRM`, `.disabled`.

### FairPlay Streaming

``FairPlayLiveConfig`` configures FairPlay Streaming for live content:

```swift
let fairPlay = FairPlayLiveConfig.modern
let sessionKey = fairPlay.sessionKeyEntry(
    keyURI: "skd://key-server/session"
)
// sessionKey.method == .sampleAESCTR
// sessionKey.keyFormat == "com.apple.streamingkeydelivery"
```

### Key Rotation

``KeyRotationPolicy`` determines when encryption keys are rotated:

```swift
let policy = KeyRotationPolicy.everyNSegments(10)
policy.shouldRotate(segmentIndex: 10, elapsed: 0)  // true
policy.shouldRotate(segmentIndex: 5, elapsed: 0)   // false
```

Policies: `.never`, `.everyNSegments(Int)`, `.everyNSeconds(TimeInterval)`.

### Live Key Manager

``LiveKeyManager`` manages the encryption key lifecycle during a live stream — generating new keys, tracking active keys, and handling rotation transitions.

### Session Key Manager

``SessionKeyManager`` manages `EXT-X-SESSION-KEY` entries in master playlists for pre-loading encryption keys.

### Multi-DRM (CENC)

``CENCConfig`` provides Common Encryption interoperability between FairPlay, Widevine, and PlayReady:

```swift
let drm = LiveDRMPipelineConfig.multiDRM
// drm.isMultiDRM == true
// drm.fairPlay != nil
// drm.cenc?.systems.contains(.widevine) == true
// drm.cenc?.systems.contains(.playReady) == true
```

### Pipeline Integration

DRM integrates with ``LivePipelineConfiguration``:

```swift
let config = LivePipelineConfiguration.multiDRMLive
// config.drm?.isMultiDRM == true
```

## Next Steps

- <doc:EncryptingSegments> — VOD segment encryption
- <doc:LivePresets> — Pipeline presets with DRM
- <doc:LiveStreaming> — Full pipeline overview
