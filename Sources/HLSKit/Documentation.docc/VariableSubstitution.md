# Variable Substitution

Use EXT-X-DEFINE to parameterize HLS manifests with CDN base URLs, session tokens, and query parameters.

@Metadata {
    @PageKind(article)
}

## Overview

HLS playlists can use `EXT-X-DEFINE` tags to define variables that are substituted throughout the manifest. This enables CDN path templating, multi-tenant token injection, and server-side playlist personalization without duplicating manifests. HLSKit supports all three forms defined in RFC 8216bis: NAME/VALUE (inline definitions), IMPORT (from parent playlists), and QUERYPARAM (from the playlist URL query string).

The ``VariableResolver`` handles substitution during parsing. ``VariableDefinition`` models each definition. The ``ManifestParser`` resolves `{$var}` references automatically when parsing, while ``ManifestGenerator`` emits the corresponding `EXT-X-DEFINE` tags and auto-bumps the version to 8.

## Three Definition Forms

### NAME/VALUE — Static Definition

Define a variable with a literal value directly in the manifest. Best for CDN base URLs, path prefixes, and static tokens.

```swift
let definition = VariableDefinition(name: "base", value: "https://cdn.example.com")
// definition.type == .value
```

In M3U8:

```
#EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
```

### IMPORT — From Parent Playlist

Import a variable defined in a parent (multivariant) playlist. Used in media playlists that inherit configuration from their parent.

```swift
let definition = VariableDefinition(import: "authToken")
// definition.type == .import
```

In M3U8:

```
#EXT-X-DEFINE:IMPORT="authToken"
```

### QUERYPARAM — From Playlist URL

Extract a variable from the query string of the playlist URL. Enables server-side personalization where the CDN injects session-specific values.

```swift
let definition = VariableDefinition(queryParam: "session")
// definition.type == .queryParam
```

In M3U8:

```
#EXT-X-DEFINE:QUERYPARAM="session"
```

## Parsing Variables

``ManifestParser`` resolves `{$var}` references automatically when parsing. All NAME/VALUE variables are substituted in variant URIs, rendition URIs, and other string fields:

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
    #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e"
    {$base}/360p/playlist.m3u8
    """

let manifest = try ManifestParser().parse(m3u8)

guard case .master(let playlist) = manifest else { return }
// playlist.definitions[0].name == "base"
// playlist.variants[0].uri == "https://cdn.example.com/360p/playlist.m3u8"
```

The ``VariableResolver`` class powers this substitution. It can also be used standalone:

```swift
let resolver = VariableResolver(definitions: ["base": "https://cdn.example.com"])
let resolved = resolver.resolve("{$base}/path/to/file.m3u8")
// resolved == "https://cdn.example.com/path/to/file.m3u8"
```

## Building with Variables

Use the builder DSL to construct playlists with definitions declaratively:

```swift
let playlist = MasterPlaylist {
    Define(name: "base", value: "https://cdn.example.com")
    Define(import: "authToken")
    Variant(
        bandwidth: 800_000,
        resolution: Resolution(width: 640, height: 360),
        uri: "360p/playlist.m3u8",
        codecs: "avc1.4d401e"
    )
    Variant(
        bandwidth: 2_800_000,
        resolution: Resolution(width: 1280, height: 720),
        uri: "720p/playlist.m3u8",
        codecs: "avc1.4d401f"
    )
}
// playlist.definitions.count == 2
// playlist.variants.count == 2
```

Or construct definitions directly:

```swift
let playlist = MasterPlaylist(
    version: .v8,
    variants: [...],
    definitions: [
        VariableDefinition(name: "base", value: "https://cdn.example.com"),
        VariableDefinition(import: "token"),
        VariableDefinition(queryParam: "session")
    ]
)
```

## Generating Manifests

``ManifestGenerator`` emits `EXT-X-DEFINE` tags in the correct format:

```swift
let output = ManifestGenerator().generateMaster(playlist)
// Output contains:
// #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
// #EXT-X-DEFINE:IMPORT="token"
// #EXT-X-DEFINE:QUERYPARAM="session"
```

## Validation

``HLSValidator`` includes variable substitution rules:
- **Undefined variable reference** — using `{$var}` without a corresponding `EXT-X-DEFINE`
- **Duplicate variable names** — defining the same variable name twice

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-STREAM-INF:BANDWIDTH=800000
    {$undefined_var}/360p/playlist.m3u8
    """
let manifest = try ManifestParser().parse(m3u8)
guard case .master(let playlist) = manifest else { return }

let report = HLSValidator().validate(playlist, ruleSet: .rfc8216)
// report.isValid == false
// report.errors contains "Undefined variable reference"
```

## CDN Path Templating Pattern

A real-world pattern using multiple variables for multi-CDN deployments:

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-VERSION:8
    #EXT-X-DEFINE:NAME="base",VALUE="https://cdn-east.example.com/live"
    #EXT-X-DEFINE:NAME="suffix",VALUE=".m3u8"
    #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e"
    {$base}/360p/playlist{$suffix}
    #EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f"
    {$base}/720p/playlist{$suffix}
    #EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028"
    {$base}/1080p/playlist{$suffix}
    """

let manifest = try ManifestParser().parse(m3u8)
guard case .master(let playlist) = manifest else { return }

// Variables resolved in all URIs
// playlist.variants[0].uri == "https://cdn-east.example.com/live/360p/playlist.m3u8"
// playlist.variants[1].uri == "https://cdn-east.example.com/live/720p/playlist.m3u8"
// playlist.variants[2].uri == "https://cdn-east.example.com/live/1080p/playlist.m3u8"
```

## Next Steps

- <doc:ManifestParsing> -- Full manifest parsing reference
- <doc:ManifestGeneration> -- Manifest generation and builder DSL
- <doc:ValidatingManifests> -- Validation rules and rule sets
