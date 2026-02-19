# Validation

Validate HLS playlists against RFC 8216 and Apple HLS rules with ``HLSValidator``.

## Overview

HLSKit provides a comprehensive validation engine that checks playlists for conformance issues. The validator produces a ``ValidationReport`` containing typed results with severity levels — errors, warnings, and informational notes.

### Validate a Media Playlist

```swift
let playlist = MediaPlaylist(
    targetDuration: 6,
    hasEndList: true,
    segments: [
        Segment(duration: 5.5, uri: "seg0.ts"),
        Segment(duration: 6.0, uri: "seg1.ts")
    ]
)

let report = HLSValidator().validate(playlist)
// report.isValid == true
// report.errors.isEmpty == true
```

### Detect Validation Errors

The validator catches common issues like segments exceeding the target duration:

```swift
let playlist = MediaPlaylist(
    targetDuration: 6,
    segments: [Segment(duration: 8.0, uri: "long.ts")]
)

let report = HLSValidator().validate(playlist)
// report.isValid == false
// report.errors.count >= 1
```

### Detect Warnings

Warnings highlight best practices that are not strict errors. For example, missing `CODECS` attributes on variants:

```swift
let playlist = MasterPlaylist(
    variants: [Variant(bandwidth: 1_000_000, uri: "video.m3u8")]
)

let report = HLSValidator().validate(playlist)
// report.warnings.count >= 1 (missing CODECS)
```

### Severity Levels

``ValidationSeverity`` provides three ordered levels:

| Severity | Meaning | Affects `isValid` |
|----------|---------|-------------------|
| `.error` | Specification violation | Yes — makes `isValid` false |
| `.warning` | Best practice recommendation | No |
| `.info` | Informational note | No |

```swift
let results = [
    ValidationResult(severity: .error, message: "Missing tag", field: "header"),
    ValidationResult(severity: .warning, message: "Recommend version", field: "version"),
    ValidationResult(severity: .info, message: "Info note", field: "general")
]
let report = ValidationReport(results: results)
// report.isValid == false (has errors)
// report.errors.count == 1
// report.warnings.count == 1
// report.infos.count == 1
```

Results are automatically sorted by severity descending (errors first).

### Rule Sets

``ValidationRuleSet`` defines which rules to apply:

| Rule Set | Description |
|----------|-------------|
| `.rfc8216` | Core RFC 8216 specification rules |
| `.appleHLS` | Apple HLS authoring guidelines |

Use the `ruleSet` parameter to control which rules are checked:

```swift
let report = HLSValidator().validate(playlist, ruleSet: .all)
```

### Validate from M3U8 String

Combine parsing and validation in a single call:

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-TARGETDURATION:6
    #EXTINF:6.0,
    seg.ts
    #EXT-X-ENDLIST
    """

let report = try HLSValidator().validateString(m3u8)
// report.isValid == true
```

### ValidationReport Properties

``ValidationReport`` provides filtered views of results:

| Property | Returns |
|----------|---------|
| `isValid` | `true` if no errors |
| `errors` | All results with `.error` severity |
| `warnings` | All results with `.warning` severity |
| `infos` | All results with `.info` severity |
| `results` | All results sorted by severity |

## Next Steps

- <doc:ManifestParsing> — Parse manifests before validating
- <doc:ManifestGeneration> — Generate corrected playlists after validation
- <doc:HLSEngine> — Use the engine facade for combined workflows
