# Encryption

Encrypt HLS segments with AES-128 or SAMPLE-AES using ``SegmentEncryptor``, ``SampleEncryptor``, and ``KeyManager``.

## Overview

HLSKit supports two encryption methods defined by the HLS specification: AES-128 full-segment encryption and SAMPLE-AES sample-level encryption. The ``KeyManager`` handles key generation, IV derivation, and key file I/O.

### Key Management

``KeyManager`` generates cryptographic keys and initialization vectors:

```swift
let km = KeyManager()

// Generate a random 16-byte AES key
let key = try km.generateKey()  // key.count == 16

// Generate a random 16-byte IV
let iv = try km.generateIV()  // iv.count == 16

// Each generated key is unique
let key2 = try km.generateKey()
// key != key2
```

#### IV Derivation from Sequence Number

Per RFC 8216, you can derive IVs from the media sequence number:

```swift
let km = KeyManager()
let iv0 = km.deriveIV(fromSequenceNumber: 0)  // 16 bytes, all zeros
let iv1 = km.deriveIV(fromSequenceNumber: 1)  // 16 bytes, sequence-based
// iv0 != iv1
```

#### Key File I/O

Write and read key files for HLS delivery:

```swift
let km = KeyManager()
let key = try km.generateKey()

// Write key to file
let keyURL = outputDir.appendingPathComponent("key.bin")
try km.writeKey(key, to: keyURL)

// Read key back
let readBack = try km.readKey(from: keyURL)
// readBack == key
```

### Encryption Configuration

``EncryptionConfig`` bundles all encryption parameters:

```swift
let config = EncryptionConfig(
    method: .aes128,
    keyURL: URL(string: "https://example.com/key")!,
    keyRotationInterval: 10,
    writeKeyFile: true
)
// config.method == .aes128
// config.keyRotationInterval == 10
```

#### FairPlay Configuration

For FairPlay Streaming with SAMPLE-AES:

```swift
let config = EncryptionConfig(
    method: .sampleAES,
    keyURL: URL(string: "skd://key.example.com")!,
    keyFormat: "com.apple.streamingkeydelivery",
    keyFormatVersions: "1"
)
```

### AES-128 Full-Segment Encryption

``SegmentEncryptor`` encrypts entire segments with AES-128-CBC:

```swift
let km = KeyManager()
let key = try km.generateKey()
let iv = try km.generateIV()
let original = Data(repeating: 0xAB, count: 1024)

// Encrypt
let encrypted = try SegmentEncryptor().encrypt(
    segmentData: original, key: key, iv: iv
)
// encrypted != original

// Decrypt (round-trip)
let decrypted = try SegmentEncryptor().decrypt(
    segmentData: encrypted, key: key, iv: iv
)
// decrypted == original
```

#### Batch Segment Encryption

Encrypt all segments from a segmentation result:

```swift
let segResult = try MP4Segmenter().segment(data: mp4Data, config: segConfig)

let key = try KeyManager().generateKey()
let encConfig = EncryptionConfig(
    method: .aes128,
    keyURL: URL(string: "https://example.com/key")!,
    key: key
)

let encResult = try SegmentEncryptor().encryptSegments(
    result: segResult, config: encConfig
)
// encResult.segmentCount == segResult.segmentCount
// encResult.playlist contains "METHOD=AES-128"
```

### SAMPLE-AES Sample-Level Encryption

``SampleEncryptor`` encrypts individual NAL units (video) and ADTS frames (audio):

#### Video Encryption

```swift
let km = KeyManager()
let key = try km.generateKey()
let iv = try km.generateIV()

let encrypted = try SampleEncryptor().encryptVideoSamples(videoData, key: key, iv: iv)
// encrypted.count == videoData.count
```

#### Audio Encryption

```swift
let encrypted = try SampleEncryptor().encryptAudioSamples(audioData, key: key, iv: iv)
// encrypted.count == audioData.count
```

#### Video Round-Trip

```swift
let enc = SampleEncryptor()
let encrypted = try enc.encryptVideoSamples(original, key: key, iv: iv)
let decrypted = try enc.decryptVideoSamples(encrypted, key: key, iv: iv)
// decrypted == original
```

### Encryption Methods

``EncryptionMethod`` defines the available methods:

| Method | Raw Value | Description |
|--------|-----------|-------------|
| `.none` | `"NONE"` | No encryption |
| `.aes128` | `"AES-128"` | Full-segment AES-128-CBC |
| `.sampleAES` | `"SAMPLE-AES"` | Sample-level encryption |
| `.sampleAESCTR` | `"SAMPLE-AES-CTR"` | Sample-level AES-CTR (CBCS) |

AES-128 and SAMPLE-AES produce different encrypted output for the same input data.

## Next Steps

- <doc:SegmentingMedia> — Segment media before encrypting
- <doc:ManifestGeneration> — Generate encrypted playlists with `EXT-X-KEY` tags
- <doc:HLSEngine> — Use the engine facade for segment-and-encrypt workflows
