# IMSC1 Subtitles Guide

Deliver W3C TTML subtitles inside fragmented MP4 over HLS with IMSC1 Text Profile.

@Metadata {
    @PageKind(article)
}

## Overview

IMSC1 (Internet Media Subtitles and Captions 1) is a W3C profile of TTML (Timed Text Markup Language)
optimized for broadcast and streaming delivery. In HLS, IMSC1 subtitles are carried in fragmented MP4
(CMAF text tracks) using the `stpp` sample entry, unlike WebVTT which is delivered as plain-text
segments. The codec identifier `CODECS="stpp.ttml.im1t"` on an `EXT-X-MEDIA` rendition tells the
player that the subtitle track is IMSC1 Text Profile.

HLSKit provides a complete pipeline for IMSC1 content:

- ``IMSC1Parser`` — parses TTML XML from disk or network into a Swift model
- ``IMSC1Renderer`` — serializes the model back to standards-compliant TTML XML
- ``IMSC1Segmenter`` — wraps TTML payloads in ISO BMFF `ftyp`/`moov`/`moof`/`mdat` boxes
- ``SubtitleCodec`` — carries the codec string `stpp.ttml.im1t` for manifest authoring

Use IMSC1 when you need rich styling (fonts, colors, positions) or when your pipeline already produces
TTML (broadcast or SCTE-35 enriched streams). Use WebVTT for simpler web-only deployments.

## IMSC1 Document Model

The core model is an ``IMSC1Document``, which maps directly to the root `<tt>` element of a TTML file.

```swift
let document = IMSC1Document(
    language: "en",
    regions: [
        IMSC1Region(
            id: "bottom",
            originX: 10.0,
            originY: 80.0,
            extentWidth: 80.0,
            extentHeight: 20.0
        )
    ],
    styles: [
        IMSC1Style(
            id: "default",
            fontFamily: "proportionalSansSerif",
            fontSize: "100%",
            color: "white",
            backgroundColor: "black",
            textAlign: "center"
        )
    ],
    subtitles: [
        IMSC1Subtitle(
            begin: 0.0,
            end: 3.5,
            text: "Programmatic subtitle",
            region: "bottom",
            style: "default"
        )
    ]
)
```

### IMSC1Region

An ``IMSC1Region`` maps to a TTML `<region>` element. All coordinates are expressed as percentages
of the root container extent, matching the TTML `tts:origin` and `tts:extent` attributes.

| Property | Type | Description |
|---|---|---|
| `id` | `String` | Unique identifier referenced by subtitle cues |
| `originX` | `Double` | Horizontal origin, 0.0–100.0 percent |
| `originY` | `Double` | Vertical origin, 0.0–100.0 percent |
| `extentWidth` | `Double` | Width, 0.0–100.0 percent |
| `extentHeight` | `Double` | Height, 0.0–100.0 percent |

A region with `originY: 80` and `extentHeight: 20` places subtitles in the bottom band of the frame,
which is the conventional broadcast position.

### IMSC1Style

An ``IMSC1Style`` maps to a TTML `<style>` element in the document `<head>`. All styling properties
are optional strings serialized exactly as their TTML `tts:` namespace equivalents:

| Property | TTML attribute | Example value |
|---|---|---|
| `fontFamily` | `tts:fontFamily` | `"proportionalSansSerif"` |
| `fontSize` | `tts:fontSize` | `"100%"`, `"24px"` |
| `color` | `tts:color` | `"white"`, `"#FFFFFF"` |
| `backgroundColor` | `tts:backgroundColor` | `"black"`, `"#000000FF"` |
| `textAlign` | `tts:textAlign` | `"center"`, `"start"`, `"end"` |
| `fontStyle` | `tts:fontStyle` | `"italic"`, `"normal"` |
| `fontWeight` | `tts:fontWeight` | `"bold"`, `"normal"` |
| `textOutline` | `tts:textOutline` | `"black 2px"` |

### IMSC1Subtitle

An ``IMSC1Subtitle`` maps to a TTML `<p>` element in the document `<body>/<div>`. Timing values are
stored in seconds as `Double`. The optional `region` and `style` properties contain identifier strings
that reference ``IMSC1Region`` and ``IMSC1Style`` objects in the document.

## Parsing TTML

``IMSC1Parser`` converts a TTML XML string into an ``IMSC1Document``. It uses Foundation's `XMLParser`
(SAX-based, event-driven) internally, which keeps memory use constant regardless of document size and
works identically on macOS, iOS, tvOS, watchOS, visionOS, and Linux.

```swift
let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
      <body>
        <div>
          <p begin="00:00:01.000" end="00:00:04.000">Hello world</p>
          <p begin="00:00:05.000" end="00:00:08.000">Welcome to IMSC1</p>
        </div>
      </body>
    </tt>
    """

let document = try IMSC1Parser.parse(xml: xml)
// document.language == "en"
// document.subtitles[0].begin == 1.0
// document.subtitles[0].text == "Hello world"
```

`IMSC1Parser.parse(xml:)` throws ``IMSC1Error`` when the input is invalid:

- ``IMSC1Error/invalidXML(_:)`` — the string is not well-formed XML
- ``IMSC1Error/missingTTElement`` — the root `<tt>` element is absent
- ``IMSC1Error/missingLanguage`` — `xml:lang` is absent on `<tt>`
- ``IMSC1Error/invalidTimecode(_:)`` — a `begin` or `end` attribute cannot be parsed

Timecodes must follow `HH:MM:SS.mmm` or `HH:MM:SS` format. The static method
`IMSC1Parser.parseTimecode(_:)` is also available for standalone timecode conversion:

```swift
let seconds = try IMSC1Parser.parseTimecode("01:30:00.500")
// seconds == 5400.5
```

The parser handles XML namespace prefixes transparently — elements like `ttml:p` are treated
identically to unprefixed `p` elements.

## Creating Subtitles Programmatically

You do not need a TTML source file to use the subtitle pipeline. Build an ``IMSC1Document`` directly
from Swift and render or segment it on the fly:

```swift
let region = IMSC1Region(
    id: "bottom",
    originX: 10.0,
    originY: 80.0,
    extentWidth: 80.0,
    extentHeight: 20.0
)
let style = IMSC1Style(
    id: "default",
    fontFamily: "proportionalSansSerif",
    fontSize: "100%",
    color: "white",
    backgroundColor: "black",
    textAlign: "center"
)
let subtitle = IMSC1Subtitle(
    begin: 0.0,
    end: 3.5,
    text: "Programmatic subtitle",
    region: "bottom",
    style: "default"
)
let document = IMSC1Document(
    language: "fr",
    regions: [region],
    styles: [style],
    subtitles: [subtitle]
)
```

This pattern is useful when subtitles originate from a database, transcription service, or
caption editor rather than a pre-existing TTML file.

## Rendering to TTML

``IMSC1Renderer`` converts an ``IMSC1Document`` back to a standards-compliant TTML XML string.
The output always includes the IMSC1 Text Profile declaration and all required namespace bindings:

```swift
let xml = IMSC1Renderer.render(document)
// Produces:
// <?xml version="1.0" encoding="UTF-8"?>
// <tt xmlns="http://www.w3.org/ns/ttml"
//     xmlns:ttp="http://www.w3.org/ns/ttml#parameter"
//     xmlns:tts="http://www.w3.org/ns/ttml#styling"
//     ttp:profile="http://www.w3.org/ns/ttml/profile/imsc1/text"
//     xml:lang="fr">
//   <head>...</head>
//   <body><div>...</div></body>
// </tt>
```

`IMSC1Renderer.render(_:)` is a pure function — it takes no mutable state and produces the same
output for the same input. The renderer also exposes `formatTimecode(_:)` as a static utility:

```swift
let tc = IMSC1Renderer.formatTimecode(3661.123)
// tc == "01:01:01.123"
```

A full round-trip — parse, then render, then parse again — preserves all timing and text values
without loss.

## Segmenting into fMP4

``IMSC1Segmenter`` produces ISO BMFF binary segments that an HLS server can deliver as a CMAF
text track. Each call is stateless; supply the context on every invocation.

### Initialization Segment

The init segment declares the track structure and must be served before any media segment:

```swift
let segmenter = IMSC1Segmenter()
let initSegment = segmenter.createInitSegment(
    language: "eng",   // ISO 639-2/T three-letter code
    timescale: 1000    // milliseconds per second
)
// initSegment starts with "ftyp", contains "moov" with an "stpp" sample entry
```

The `stpp` sample entry inside `moov/trak/mdia/minf/stbl/stsd` carries the TTML namespace URI
`http://www.w3.org/ns/ttml`. The media header box `nmhd` (Null Media Header) is used, as required
for subtitle tracks per ISO 14496-12.

### Media Segments

Each media segment wraps one ``IMSC1Document`` rendered as TTML inside an `mdat` box:

```swift
let mediaSeg = segmenter.createMediaSegment(
    document: document,
    sequenceNumber: 1,
    baseDecodeTime: 0,      // in timescale units
    duration: 6000          // 6 seconds at timescale=1000
)
// mediaSeg contains "moof" (mfhd + traf) + "mdat" (TTML XML bytes)
```

The `baseDecodeTime` value should match the `EXT-X-DISCONTINUITY-SEQUENCE` or the segment
timeline in the corresponding media playlist. Increment `sequenceNumber` by one for each
consecutive segment. The rendered TTML is stored verbatim as UTF-8 text inside `mdat`.

## Manifest Integration

Declare IMSC1 subtitle renditions using ``SubtitleCodec/imsc1`` as the codec string on
`EXT-X-MEDIA` tags. Link variants to the subtitle group with the `SUBTITLES` attribute:

```swift
let playlist = MasterPlaylist(
    version: .v7,
    variants: [
        Variant(
            bandwidth: 4_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "video/1080p.m3u8",
            codecs: "avc1.640028,mp4a.40.2",
            subtitles: "imsc1-subs"
        )
    ],
    renditions: [
        Rendition(
            type: .subtitles,
            groupId: "imsc1-subs",
            name: "English",
            uri: "subtitles/en_imsc1.m3u8",
            language: "en",
            isDefault: true,
            autoselect: true,
            codec: SubtitleCodec.imsc1.rawValue   // "stpp.ttml.im1t"
        )
    ]
)
let output = ManifestGenerator().generateMaster(playlist)
```

The generated manifest contains:

```
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="imsc1-subs",NAME="English",
LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,
URI="subtitles/en_imsc1.m3u8",CODECS="stpp.ttml.im1t"
```

When ``ManifestParser`` reads a manifest with `CODECS="stpp.ttml.im1t"`, the parsed
`Rendition` carries `subtitleCodec == .imsc1`.

## Next Steps

- <doc:SpatialVideoGuide> — Package MV-HEVC stereoscopic video for Apple Vision Pro
