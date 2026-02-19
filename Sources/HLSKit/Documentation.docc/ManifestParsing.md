# Manifest Parsing

Parse HLS manifests into typed Swift models with ``ManifestParser``.

## Overview

HLSKit provides a complete M3U8 parser that handles both master and media playlists, including Low-Latency HLS extensions. The parser returns a ``Manifest`` enum — either `.master` or `.media` — with fully typed properties.

### Parse a Master Playlist

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-VERSION:7
    #EXT-X-INDEPENDENT-SEGMENTS
    #EXT-X-STREAM-INF:BANDWIDTH=800000,AVERAGE-BANDWIDTH=700000,\
    RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2",FRAME-RATE=30.000
    360p/playlist.m3u8
    #EXT-X-STREAM-INF:BANDWIDTH=2800000,AVERAGE-BANDWIDTH=2500000,\
    RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2",FRAME-RATE=30.000
    720p/playlist.m3u8
    """

let parser = ManifestParser()
let manifest = try parser.parse(m3u8)

guard case .master(let playlist) = manifest else { return }
// playlist.variants[0].bandwidth == 800_000
// playlist.variants[0].resolution == Resolution(width: 640, height: 360)
// playlist.variants[0].codecs == "avc1.4d401e,mp4a.40.2"
```

### Parse a Media Playlist

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-TARGETDURATION:6
    #EXT-X-MEDIA-SEQUENCE:0
    #EXT-X-PLAYLIST-TYPE:VOD
    #EXTINF:6.006,
    segment000.ts
    #EXTINF:5.839,
    segment001.ts
    #EXT-X-ENDLIST
    """

let parser = ManifestParser()
let manifest = try parser.parse(m3u8)

guard case .media(let playlist) = manifest else { return }
// playlist.version == .v3
// playlist.targetDuration == 6
// playlist.playlistType == .vod
// playlist.segments.count == 2
// playlist.segments[0].duration == 6.006
```

### Byte-Range Segments

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-VERSION:4
    #EXT-X-TARGETDURATION:6
    #EXTINF:6.0,
    #EXT-X-BYTERANGE:1024@0
    main.ts
    #EXTINF:6.0,
    #EXT-X-BYTERANGE:1024@1024
    main.ts
    #EXT-X-ENDLIST
    """

guard case .media(let playlist) = try ManifestParser().parse(m3u8) else { return }
// playlist.segments[0].byteRange?.length == 1024
// playlist.segments[0].byteRange?.offset == 0
```

### Encryption Tags

Parse `EXT-X-KEY` encryption metadata:

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-VERSION:3
    #EXT-X-TARGETDURATION:6
    #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key",\
    IV=0x00000000000000000000000000000001
    #EXTINF:6.0,
    segment000.ts
    #EXT-X-ENDLIST
    """

guard case .media(let playlist) = try ManifestParser().parse(m3u8) else { return }
let key = playlist.segments[0].key
// key?.method == .aes128
// key?.uri == "https://example.com/key"
```

### Audio Renditions

Parse `EXT-X-MEDIA` alternate audio tracks:

```swift
let m3u8 = """
    #EXTM3U
    #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",\
    LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,URI="audio/en.m3u8"
    #EXT-X-STREAM-INF:BANDWIDTH=2800000,AUDIO="audio"
    video.m3u8
    """

guard case .master(let playlist) = try ManifestParser().parse(m3u8) else { return }
// playlist.renditions[0].type == .audio
// playlist.renditions[0].language == "en"
// playlist.renditions[0].isDefault == true
```

### Low-Level Parsing

For fine-grained control, use ``TagParser`` and ``AttributeParser`` directly:

```swift
let tagParser = TagParser()
let (duration, title) = try tagParser.parseExtInf("9.009,Segment Title")
// duration == 9.009, title == "Segment Title"

let range = try tagParser.parseByteRange("1024@512")
// range.length == 1024, range.offset == 512

let attrParser = AttributeParser()
let attrs = attrParser.parseAttributes("BANDWIDTH=800000,RESOLUTION=1280x720")
// attrs["BANDWIDTH"] == "800000"
```

### Error Handling

The parser throws ``ParserError`` for invalid input:

```swift
let parser = ManifestParser()

// Empty input
do {
    try parser.parse("")
} catch ParserError.emptyManifest {
    // Handle empty manifest
}

// Missing #EXTM3U header
do {
    try parser.parse("not a playlist")
} catch ParserError.missingHeader {
    // Handle missing header
}
```

## Next Steps

- <doc:ManifestGeneration> — Generate M3U8 output from parsed models
- <doc:ValidatingManifests> — Validate parsed playlists against RFC 8216
- <doc:HLSEngine> — Use the high-level engine facade for combined workflows
