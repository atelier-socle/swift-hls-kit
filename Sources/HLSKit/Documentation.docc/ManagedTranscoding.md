# Cloud Transcoding with ManagedTranscoder

@Metadata {
    @PageKind(article)
}

Delegate transcoding to cloud services — same ``Transcoder`` protocol, zero local GPU required.

## Overview

``ManagedTranscoder`` offloads heavy transcoding work to cloud providers while conforming to the same ``Transcoder`` protocol as ``AppleTranscoder`` and ``FFmpegTranscoder``. Local file in, local file out — but processing happens in the cloud. Ideal for server-side applications (Vapor, Hummingbird) where GPU or FFmpeg are not available.

### Supported Providers

| Provider | Best For | Authentication |
|---|---|---|
| Cloudflare Stream | Zero egress costs, global CDN | API token (`Bearer`) |
| AWS MediaConvert | Enterprise, existing AWS infra | Access key + secret (SigV4) |
| Mux | Simplest API, auto-adaptive bitrate | Token ID + secret (Basic Auth) |

## Configuration

``ManagedTranscodingConfig`` holds all provider-specific settings. Each provider requires an `apiKey` and `accountID` at minimum.

### Cloudflare Stream

```swift
let config = ManagedTranscodingConfig(
    provider: .cloudflareStream,
    apiKey: "cf-api-token",
    accountID: "cf-account-123"
)
// config.provider == .cloudflareStream
// config.apiKey == "cf-api-token"
// config.accountID == "cf-account-123"
```

### AWS MediaConvert

AWS requires additional parameters for S3 storage and IAM role:

```swift
let config = ManagedTranscodingConfig(
    provider: .awsMediaConvert,
    apiKey: "AKIATEST:secretkey",
    accountID: "123456789",
    region: "us-east-1",
    storageBucket: "my-bucket",
    roleARN: "arn:aws:iam::123:role/MediaConvert"
)
// config.region == "us-east-1"
// config.storageBucket == "my-bucket"
// config.roleARN == "arn:aws:iam::123:role/MediaConvert"
```

### Mux

Mux uses a `tokenId:tokenSecret` pair encoded as Basic Auth:

```swift
let config = ManagedTranscodingConfig(
    provider: .mux,
    apiKey: "tokenId:tokenSecret",
    accountID: "unused"
)
// config.provider == .mux
// config.apiKey == "tokenId:tokenSecret"
```

### Defaults

```swift
let config = ManagedTranscodingConfig(
    provider: .cloudflareStream,
    apiKey: "k", accountID: "a"
)
// config.pollingInterval == 5     (seconds between status checks)
// config.timeout == 3600          (max wait before timeout error)
// config.defaultPreset == .p720   (720p default quality)
```

## Single-Variant Transcoding

Use the standard ``Transcoder`` protocol — callers don't need to know whether transcoding happens locally or in the cloud:

```swift
let config = ManagedTranscodingConfig(
    provider: .cloudflareStream,
    apiKey: "key", accountID: "acct"
)
let transcoder = ManagedTranscoder(config: config)

let result = try await transcoder.transcode(
    input: inputURL, outputDirectory: outputDir,
    config: TranscodingConfig(), progress: nil
)
// result.preset.name == QualityPreset.p720.name
// result.transcodingDuration > 0
```

## Multi-Variant Transcoding

Transcode to multiple quality levels in a single call:

```swift
let result = try await transcoder.transcodeVariants(
    input: inputURL, outputDirectory: outputDir,
    variants: [.p480, .p720, .p1080],
    config: TranscodingConfig(), progress: nil
)
// result.variants.count == 3
// result.masterPlaylist != nil
```

## Progress Tracking

The progress callback reports values through five phases:

| Phase | Progress Range | Description |
|---|---|---|
| Upload | 0.05 — 0.30 | File upload to cloud storage |
| Job creation | 0.30 | Transcoding job submitted |
| Polling | 0.30 — 0.80 | Cloud encoding in progress |
| Download | 0.80 — 0.95 | Output downloaded to local disk |
| Complete | 1.0 | All done |

```swift
_ = try await transcoder.transcode(
    input: inputURL, outputDirectory: outputDir,
    config: TranscodingConfig(),
    progress: { value in
        print("Progress: \(value * 100)%")
    }
)
// Progress callbacks include values >= 0.05, >= 0.80, and finally 1.0
```

Upload and download stream data to/from disk without loading entire files into memory, with granular progress reporting.

## Job Lifecycle

``ManagedTranscodingJob`` tracks the transcoding operation through its lifecycle:

```swift
let job = ManagedTranscodingJob(jobID: "job-1", assetID: "asset-1")
// job.status == .queued
```

### Status Flow

`queued` → `processing` → `completed` | `failed` | `cancelled`

The ``ManagedTranscodingJob/isTerminal`` property returns `true` for `completed`, `failed`, and `cancelled`.

### Job Properties

| Property | Description |
|---|---|
| `jobID` | Provider-assigned job identifier |
| `assetID` | Uploaded asset identifier |
| `status` | Current status (``ManagedTranscodingJob/Status``) |
| `progress` | Encoding progress (0.0 to 1.0) |
| `outputURLs` | Delivery URLs populated on completion |
| `errorMessage` | Error details populated on failure |
| `completedAt` | Completion timestamp |

## Error Handling

Cloud transcoding can fail at several stages. All errors are ``TranscodingError`` cases:

| Error | Cause |
|---|---|
| `uploadFailed` | File upload to cloud storage failed |
| `jobFailed` | Cloud encoding failed (codec unsupported, etc.) |
| `timeout` | Polling exceeded the configured timeout |
| `downloadFailed` | Output download failed (404, network error) |
| `authenticationFailed` | Invalid API key or account ID |

```swift
do {
    _ = try await transcoder.transcode(
        input: inputURL, outputDirectory: outputDir,
        config: TranscodingConfig(), progress: nil
    )
} catch let error as TranscodingError {
    // Handle specific error cases
}
```

## HLSEngine Integration

``HLSEngine`` provides a factory method for creating a managed transcoder:

```swift
let engine = HLSEngine()
let config = ManagedTranscodingConfig(
    provider: .cloudflareStream,
    apiKey: "key", accountID: "acct"
)
let transcoder = engine.managedTranscoder(config: config)
// ManagedTranscoder.isAvailable == true
```

The returned transcoder is transparent to callers — it conforms to the same ``Transcoder`` protocol as Apple and FFmpeg transcoders.

## Custom Quality Presets

Override the default 720p quality with ``ManagedTranscodingConfig/defaultPreset``:

```swift
// High quality (1080p)
let hdConfig = ManagedTranscodingConfig(
    provider: .cloudflareStream,
    apiKey: "k", accountID: "a",
    defaultPreset: .p1080
)
// hdConfig.defaultPreset == .p1080
```

For podcast and audio-only content:

```swift
let audioConfig = ManagedTranscodingConfig(
    provider: .cloudflareStream,
    apiKey: "k", accountID: "a",
    defaultPreset: .audioOnly
)
// audioConfig.defaultPreset.isAudioOnly == true
```

## Cleanup

By default, cloud assets are deleted after download (`cleanupAfterDownload = true`). This prevents lingering storage costs. To retain assets for manual inspection or reprocessing:

```swift
let config = ManagedTranscodingConfig(
    provider: .cloudflareStream,
    apiKey: "k", accountID: "a",
    cleanupAfterDownload: false
)
```

## Next Steps

- <doc:TranscodingMedia> — Local transcoding with Apple VideoToolbox and FFmpeg
- <doc:HLSEngine> — End-to-end HLS workflows
- <doc:SegmentingMedia> — Segmenting media into HLS-compatible chunks
