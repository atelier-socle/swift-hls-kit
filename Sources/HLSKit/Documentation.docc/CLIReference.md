# CLI Reference

@Metadata {
    @PageKind(article)
}

Run HLS workflows from the command line with `hlskit-cli`.

## Overview

HLSKit includes a command-line tool with 8 commands for common HLS operations. Install it via Swift Package Manager:

```bash
swift build -c release
# Binary at .build/release/hlskit-cli
```

The CLI requires the `HLSKitCommands` library, which depends on `swift-argument-parser`.

### Commands

| Command | Description |
|---------|-------------|
| `info` | Inspect MP4 or M3U8 files |
| `segment` | Split media files into HLS segments |
| `transcode` | Transcode media to HLS variants |
| `validate` | Validate M3U8 playlists |
| `encrypt` | Encrypt HLS segments |
| `manifest` | Parse or generate M3U8 manifests |
| `live` | Live streaming pipeline management |
| `iframe` | Generate I-frame only playlists |

---

### info

Inspect MP4 files (tracks, codec, duration) or M3U8 manifests (type, segments):

```bash
hlskit-cli info video.mp4
hlskit-cli info playlist.m3u8
hlskit-cli info video.mp4 --output-format json
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--output-format` | `text` | Output format: `text` or `json` |

---

### segment

Split an MP4 file into fMP4 or MPEG-TS segments with automatic playlist generation:

```bash
# fMP4 segments (default)
hlskit-cli segment video.mp4

# Custom output directory and duration
hlskit-cli segment video.mp4 --output /tmp/hls/ --duration 4.0

# MPEG-TS format
hlskit-cli segment video.mp4 --output /tmp/hls/ --format ts

# Byte-range mode
hlskit-cli segment video.mp4 --format fmp4 --byte-range

# JSON output
hlskit-cli segment video.mp4 --output-format json --quiet
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--output` | `./hls_output/` | Output directory |
| `--format` | `fmp4` | Container format: `fmp4` or `ts` |
| `--duration` | `6.0` | Target segment duration in seconds |
| `--byte-range` | `false` | Use byte-range segments |
| `--quiet` | `false` | Suppress progress output |
| `--output-format` | `text` | Output format: `text` or `json` |

---

### transcode

Transcode a media file to one or more HLS quality variants:

```bash
# Single preset
hlskit-cli transcode video.mp4 --preset 720p

# Multiple presets
hlskit-cli transcode video.mp4 --presets 360p,720p,1080p

# Quality ladder
hlskit-cli transcode video.mp4 --ladder standard

# Custom output
hlskit-cli transcode video.mp4 --output /tmp/hls/ --preset 720p
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--output` | `./hls_output/` | Output directory |
| `--preset` | — | Single quality preset |
| `--presets` | — | Comma-separated presets |
| `--ladder` | — | Preset ladder: `standard` or `full` |
| `--format` | `fmp4` | Container format: `fmp4` or `ts` |
| `--duration` | `6.0` | Segment duration |
| `--quiet` | `false` | Suppress progress output |
| `--output-format` | `text` | Output format: `text` or `json` |

**Available presets:** `360p`, `480p`, `720p`, `1080p`, `2160p`, `audio`

---

### validate

Validate an M3U8 playlist against RFC 8216 and Apple HLS rules:

```bash
# Basic validation
hlskit-cli validate playlist.m3u8

# Strict mode (warnings become errors)
hlskit-cli validate playlist.m3u8 --strict

# Recursive validation of a directory
hlskit-cli validate /tmp/hls/ --recursive

# JSON output
hlskit-cli validate playlist.m3u8 --output-format json
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--strict` | `false` | Treat warnings as errors |
| `--recursive` | `false` | Validate all M3U8 files in directory |
| `--output-format` | `text` | Output format: `text` or `json` |

---

### encrypt

Encrypt HLS segments in a directory:

```bash
# AES-128 encryption (default)
hlskit-cli encrypt /tmp/hls/ --key-url "https://cdn.example.com/key"

# Write key file alongside segments
hlskit-cli encrypt /tmp/hls/ --key-url "https://cdn.example.com/key" --write-key

# SAMPLE-AES encryption
hlskit-cli encrypt /tmp/hls/ --key-url "https://cdn.example.com/key" --method sample-aes

# Provide explicit key and IV
hlskit-cli encrypt /tmp/hls/ \
    --key-url "https://cdn.example.com/key" \
    --key 00112233445566778899aabbccddeeff \
    --iv aabbccddeeff00112233445566778899

# Key rotation every 10 segments
hlskit-cli encrypt /tmp/hls/ --key-url "https://cdn.example.com/key" --rotation 10
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--key-url` | (required) | URL for the key in the playlist |
| `--method` | `aes-128` | Encryption method: `aes-128` or `sample-aes` |
| `--key` | (auto-generated) | Hex-encoded 16-byte key |
| `--iv` | (auto-generated) | Hex-encoded 16-byte IV |
| `--rotation` | — | Key rotation interval (segments) |
| `--write-key` | `false` | Write key file to output directory |
| `--quiet` | `false` | Suppress progress output |
| `--output-format` | `text` | Output format: `text` or `json` |

---

### manifest

Parse or generate M3U8 manifests. This command has two subcommands:

#### manifest parse

Parse an M3U8 file and display its contents:

```bash
hlskit-cli manifest parse playlist.m3u8
hlskit-cli manifest parse playlist.m3u8 --output-format json
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--output-format` | `text` | Output format: `text` or `json` |

#### manifest generate

Generate a master playlist from a JSON config or a directory of segments:

```bash
# From a segment directory
hlskit-cli manifest generate /tmp/hls/

# With output path
hlskit-cli manifest generate config.json --output /tmp/master.m3u8
```

The JSON config format:

```json
{
    "version": 7,
    "variants": [
        {
            "uri": "360p/playlist.m3u8",
            "bandwidth": 800000,
            "resolution": {"width": 640, "height": 360}
        }
    ]
}
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--output` | — | Output file path |

---

### live

Manage live streaming pipelines. This command has subcommands for starting, stopping, monitoring, converting, and injecting metadata.

```bash
# Start a live pipeline with a preset
hlskit-cli live start --preset podcast-live --output /tmp/live/

# Stop the running pipeline
hlskit-cli live stop

# Show pipeline statistics
hlskit-cli live stats

# Convert recorded live session to VOD
hlskit-cli live convert-to-vod /tmp/live/ --output /tmp/vod/

# Inject metadata during a live session
hlskit-cli live metadata --inject "title=Breaking News"
```

**Subcommands:**

| Subcommand | Description |
|------------|-------------|
| `start` | Start a live pipeline with a preset |
| `stop` | Stop the running pipeline |
| `stats` | Show pipeline statistics |
| `convert-to-vod` | Convert recorded live content to VOD |
| `metadata` | Inject or query live metadata |

**Available presets:** `podcast-live`, `music-live`, `video-live`, `video-simulcast`

---

### iframe

Generate an I-frame only playlist from a media playlist:

```bash
# Basic I-frame playlist generation
hlskit-cli iframe --input stream.m3u8 --output iframe.m3u8

# With interval and byte-range
hlskit-cli iframe --input stream.m3u8 --output iframe.m3u8 --interval 2.0 --byte-range

# With thumbnail extraction
hlskit-cli iframe --input stream.m3u8 --output iframe.m3u8 \
    --thumbnail-output /tmp/thumbs/ --thumbnail-size 320x180

# Quiet mode with JSON output
hlskit-cli iframe --input stream.m3u8 --output iframe.m3u8 --quiet --output-format json
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--input` | (required) | Input media playlist (.m3u8) |
| `--output` | (required) | Output I-frame playlist path |
| `--interval` | (from source) | I-frame interval in seconds |
| `--thumbnail-output` | — | Output directory for thumbnails |
| `--thumbnail-size` | — | Thumbnail dimensions (WxH) |
| `--byte-range` | `false` | Include BYTERANGE addressing |
| `--quiet` | `false` | Suppress output |
| `--output-format` | `text` | Output format: `text` or `json` |

## Next Steps

- <doc:GettingStarted> — Use HLSKit as a Swift library
- <doc:HLSEngine> — Programmatic API for the same workflows
- <doc:LiveStreaming> — Live streaming architecture
- <doc:IFramePlaylists> — I-frame playlist generation API
