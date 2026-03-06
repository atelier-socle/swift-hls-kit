#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Atelier Socle SAS

"""
Mock HLS Server for swift-hls-kit manual testing.

Comprehensive mock server supporting 5 modes:
  push    — HTTP segment receiver for push testing
  serve   — HLS content server for parse/validate/info testing
  live    — Live simulation with auto-updating playlists
  multi   — Multi-destination transport testing
  spatial — MV-HEVC spatial video content

Usage:
  python3 mock-hls-server.py --mode serve --port 8080
  python3 mock-hls-server.py --mode push --port 8080 --fail slow
  python3 mock-hls-server.py --mode live --port 8080
  python3 mock-hls-server.py --mode multi --port 8080 --port2 8081
  python3 mock-hls-server.py --mode spatial --port 8080
"""

import argparse
import io
import json
import os
import signal
import struct
import sys
import threading
import time
from datetime import datetime, timezone
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs


# ──────────────────────────────────────────────────────────────────────
# Colors
# ──────────────────────────────────────────────────────────────────────

class Color:
    """ANSI color codes with TTY detection."""

    _enabled = sys.stdout.isatty()

    GREEN = "\033[92m" if _enabled else ""
    RED = "\033[91m" if _enabled else ""
    YELLOW = "\033[93m" if _enabled else ""
    CYAN = "\033[96m" if _enabled else ""
    MAGENTA = "\033[95m" if _enabled else ""
    BLUE = "\033[94m" if _enabled else ""
    DIM = "\033[2m" if _enabled else ""
    BOLD = "\033[1m" if _enabled else ""
    RESET = "\033[0m" if _enabled else ""

    @staticmethod
    def success(msg):
        return f"{Color.GREEN}✓ {msg}{Color.RESET}"

    @staticmethod
    def error(msg):
        return f"{Color.RED}✗ {msg}{Color.RESET}"

    @staticmethod
    def warn(msg):
        return f"{Color.YELLOW}⚠ {msg}{Color.RESET}"

    @staticmethod
    def info(msg):
        return f"{Color.CYAN}ℹ {msg}{Color.RESET}"


# ──────────────────────────────────────────────────────────────────────
# Logging
# ──────────────────────────────────────────────────────────────────────

_verbose = False


def log(msg, color=""):
    ts = datetime.now().strftime("%H:%M:%S.%f")[:-3]
    prefix = f"{Color.DIM}[{ts}]{Color.RESET}"
    print(f"{prefix} {color}{msg}{Color.RESET}", flush=True)


def log_verbose(msg):
    if _verbose:
        log(msg, Color.DIM)


# ──────────────────────────────────────────────────────────────────────
# Utilities
# ──────────────────────────────────────────────────────────────────────

def fmt_bytes(n):
    """Format byte count for display."""
    if n < 1024:
        return f"{n} B"
    elif n < 1024 * 1024:
        return f"{n / 1024:.1f} KB"
    elif n < 1024 * 1024 * 1024:
        return f"{n / (1024 * 1024):.1f} MB"
    else:
        return f"{n / (1024 * 1024 * 1024):.2f} GB"


def mime_type(path):
    """Return MIME type for HLS-related file extensions."""
    ext = os.path.splitext(path)[1].lower()
    return {
        ".m3u8": "application/vnd.apple.mpegurl",
        ".m4s": "video/iso.segment",
        ".ts": "video/MP2T",
        ".mp4": "video/mp4",
        ".ttml": "application/ttml+xml",
        ".hevc": "application/octet-stream",
        ".json": "application/json",
    }.get(ext, "application/octet-stream")


# ──────────────────────────────────────────────────────────────────────
# Synthetic Content Generators
# ──────────────────────────────────────────────────────────────────────

def build_ftyp():
    """Minimal ftyp box: brand=isom, version=0x200, compat=[isom,iso6]."""
    brands = b"isom" + struct.pack(">I", 0x200) + b"isomiso6"
    size = 8 + len(brands)
    return struct.pack(">I", size) + b"ftyp" + brands


def build_minimal_moov(width=1920, height=1080, timescale=90000):
    """Minimal moov box with mvhd + trak + mvex for fMP4 init segment."""
    # mvhd (version 0, 108 bytes total)
    mvhd_payload = bytearray(96)
    struct.pack_into(">I", mvhd_payload, 0, 0)       # version+flags
    struct.pack_into(">I", mvhd_payload, 12, timescale)
    struct.pack_into(">I", mvhd_payload, 16, 0)       # duration
    struct.pack_into(">I", mvhd_payload, 20, 0x00010000)  # rate 1.0
    struct.pack_into(">H", mvhd_payload, 24, 0x0100)  # volume 1.0
    struct.pack_into(">I", mvhd_payload, 76, 0x00010000)  # matrix[0]
    struct.pack_into(">I", mvhd_payload, 88, 0x00010000)  # matrix[4]
    struct.pack_into(">I", mvhd_payload, 92, 0x40000000)  # matrix[8] — use offset 92
    struct.pack_into(">I", mvhd_payload, 72, 2)       # next_track_ID — place after matrix area
    mvhd = struct.pack(">I", 8 + len(mvhd_payload)) + b"mvhd" + bytes(mvhd_payload)

    # tkhd (version 0)
    tkhd_payload = bytearray(84)
    struct.pack_into(">I", tkhd_payload, 0, 0x03)     # flags: enabled+in-movie
    struct.pack_into(">I", tkhd_payload, 8, 1)        # track_ID
    struct.pack_into(">I", tkhd_payload, 48, 0x00010000)
    struct.pack_into(">I", tkhd_payload, 60, 0x00010000)
    struct.pack_into(">I", tkhd_payload, 64, 0x40000000)
    struct.pack_into(">I", tkhd_payload, 76, width << 16)
    struct.pack_into(">I", tkhd_payload, 80, height << 16)
    tkhd = struct.pack(">I", 8 + len(tkhd_payload)) + b"tkhd" + bytes(tkhd_payload)

    # mdhd
    mdhd_payload = bytearray(24)
    struct.pack_into(">I", mdhd_payload, 0, 0)
    struct.pack_into(">I", mdhd_payload, 12, timescale)
    struct.pack_into(">H", mdhd_payload, 20, 0x55C4)  # "und"
    mdhd = struct.pack(">I", 8 + len(mdhd_payload)) + b"mdhd" + bytes(mdhd_payload)

    # hdlr
    hdlr_payload = bytearray(25)
    struct.pack_into(">I", hdlr_payload, 0, 0)
    hdlr_payload[8:12] = b"vide"
    hdlr = struct.pack(">I", 8 + len(hdlr_payload)) + b"hdlr" + bytes(hdlr_payload)

    # stbl with empty sample tables
    stsd_inner = bytearray(8)  # version+flags + entry_count=0
    stsd = struct.pack(">I", 8 + len(stsd_inner)) + b"stsd" + bytes(stsd_inner)
    stts = struct.pack(">I", 16) + b"stts" + b"\x00" * 8
    stsc = struct.pack(">I", 16) + b"stsc" + b"\x00" * 8
    stsz = struct.pack(">I", 20) + b"stsz" + b"\x00" * 12
    stco = struct.pack(">I", 16) + b"stco" + b"\x00" * 8

    stbl_inner = stsd + stts + stsc + stsz + stco
    stbl = struct.pack(">I", 8 + len(stbl_inner)) + b"stbl" + stbl_inner

    # vmhd
    vmhd = struct.pack(">I", 20) + b"vmhd" + struct.pack(">I", 1) + b"\x00" * 8

    # dinf > dref > url
    url_box = struct.pack(">I", 12) + b"url " + struct.pack(">I", 1)
    dref = struct.pack(">I", 8 + 4 + 4 + len(url_box)) + b"dref" + b"\x00\x00\x00\x00" + struct.pack(">I", 1) + url_box
    dinf = struct.pack(">I", 8 + len(dref)) + b"dinf" + dref

    minf_inner = vmhd + dinf + stbl
    minf = struct.pack(">I", 8 + len(minf_inner)) + b"minf" + minf_inner

    mdia_inner = mdhd + hdlr + minf
    mdia = struct.pack(">I", 8 + len(mdia_inner)) + b"mdia" + mdia_inner

    trak_inner = tkhd + mdia
    trak = struct.pack(">I", 8 + len(trak_inner)) + b"trak" + trak_inner

    # mvex > trex
    trex_payload = struct.pack(">I", 0) + struct.pack(">I", 1) + b"\x00" * 16
    trex = struct.pack(">I", 8 + len(trex_payload)) + b"trex" + bytes(trex_payload)
    mvex = struct.pack(">I", 8 + len(trex)) + b"mvex" + trex

    moov_inner = mvhd + trak + mvex
    return struct.pack(">I", 8 + len(moov_inner)) + b"moov" + moov_inner


def build_init_segment(width=1920, height=1080, timescale=90000):
    """Build a minimal valid fMP4 init segment (ftyp + moov)."""
    return build_ftyp() + build_minimal_moov(width, height, timescale)


def build_media_segment(seq=0, duration_ms=6000, timescale=90000):
    """Build a minimal valid fMP4 media segment (moof + mdat)."""
    base_decode_time = seq * int(duration_ms * timescale / 1000)
    sample_duration = int(duration_ms * timescale / 1000)

    # mfhd
    mfhd_payload = struct.pack(">I", 0) + struct.pack(">I", seq + 1)
    mfhd = struct.pack(">I", 8 + len(mfhd_payload)) + b"mfhd" + bytes(mfhd_payload)

    # tfhd
    tfhd_payload = struct.pack(">I", 0x020000) + struct.pack(">I", 1)
    tfhd = struct.pack(">I", 8 + len(tfhd_payload)) + b"tfhd" + bytes(tfhd_payload)

    # tfdt (version 1)
    tfdt_payload = struct.pack(">I", 0x01000000) + struct.pack(">Q", base_decode_time)
    tfdt = struct.pack(">I", 8 + len(tfdt_payload)) + b"tfdt" + bytes(tfdt_payload)

    # trun (1 sample)
    synthetic_data = b"\x00" * 1024
    mdat = struct.pack(">I", 8 + len(synthetic_data)) + b"mdat" + synthetic_data

    trun_flags = 0x000301  # data_offset + sample_duration + sample_size
    trun_payload = struct.pack(">I", trun_flags) + struct.pack(">I", 1)  # sample_count=1

    # We need to compute the data_offset after we know the moof size
    trun_sample = struct.pack(">I", sample_duration) + struct.pack(">I", len(synthetic_data))

    traf_inner_no_offset = tfhd + tfdt
    trun_no_offset = struct.pack(">I", 8 + len(trun_payload) + 4 + len(trun_sample)) + b"trun" + trun_payload
    # Placeholder offset
    trun_with_offset = struct.pack(">I", 8 + len(trun_payload) + 4 + len(trun_sample)) + b"trun" + trun_payload

    traf_inner = traf_inner_no_offset + trun_with_offset
    traf_size = 8 + len(traf_inner) + 4 + len(trun_sample)
    moof_size = 8 + len(mfhd) + traf_size

    data_offset = moof_size + 8  # moof size + mdat header

    # Rebuild trun with correct data_offset
    trun_final = struct.pack(">I", 8 + len(trun_payload) + 4 + len(trun_sample)) + b"trun" + trun_payload + struct.pack(">i", data_offset) + trun_sample

    traf_inner_final = tfhd + tfdt + trun_final
    traf = struct.pack(">I", 8 + len(traf_inner_final)) + b"traf" + traf_inner_final

    moof_inner = mfhd + traf
    moof = struct.pack(">I", 8 + len(moof_inner)) + b"moof" + moof_inner

    return moof + mdat


def build_ts_segment(seq=0):
    """Build a minimal valid MPEG-TS segment with PAT + PMT + PES."""
    packets = bytearray()
    # PAT (PID 0)
    pat = bytearray(188)
    pat[0] = 0x47       # sync
    pat[1] = 0x40       # payload_unit_start
    pat[2] = 0x00       # PID=0
    pat[3] = 0x10       # no adaptation, has payload
    pat[4] = 0x00       # pointer field
    pat[5] = 0x00       # table_id
    pat[6] = 0xB0       # section_syntax + length
    pat[7] = 0x0D       # section length
    pat[8] = 0x00       # transport_stream_id
    pat[9] = 0x01
    pat[10] = 0xC1      # version, current
    pat[11] = 0x00      # section_number
    pat[12] = 0x00      # last_section
    pat[13] = 0x00      # program_number
    pat[14] = 0x01
    pat[15] = 0xE0      # PMT PID high
    pat[16] = 0x20      # PMT PID=0x20 (32)
    # CRC32 placeholder
    pat[17] = 0x00
    pat[18] = 0x00
    pat[19] = 0x00
    pat[20] = 0x00
    for i in range(21, 188):
        pat[i] = 0xFF
    packets.extend(pat)

    # PMT (PID 0x20)
    pmt = bytearray(188)
    pmt[0] = 0x47
    pmt[1] = 0x40
    pmt[2] = 0x20       # PID=0x20
    pmt[3] = 0x10
    pmt[4] = 0x00       # pointer field
    pmt[5] = 0x02       # table_id (PMT)
    pmt[6] = 0xB0
    pmt[7] = 0x12       # section length
    pmt[8] = 0x00       # program_number
    pmt[9] = 0x01
    pmt[10] = 0xC1
    pmt[11] = 0x00
    pmt[12] = 0x00
    pmt[13] = 0xE1      # PCR PID
    pmt[14] = 0x00
    pmt[15] = 0xF0      # program_info_length
    pmt[16] = 0x00
    # Stream entry: H.264 video on PID 0x100
    pmt[17] = 0x1B      # stream_type (H.264)
    pmt[18] = 0xE1
    pmt[19] = 0x00      # elementary PID = 0x100
    pmt[20] = 0xF0
    pmt[21] = 0x00
    for i in range(22, 188):
        pmt[i] = 0xFF
    packets.extend(pmt)

    # PES packet (PID 0x100) with synthetic payload
    pes = bytearray(188)
    pes[0] = 0x47
    pes[1] = 0x41       # payload_unit_start
    pes[2] = 0x00       # PID=0x100
    pes[3] = 0x10
    # PES header
    pes[4] = 0x00
    pes[5] = 0x00
    pes[6] = 0x01       # start code
    pes[7] = 0xE0       # stream_id (video)
    pes[8] = 0x00
    pes[9] = 0x00       # PES packet length (0 = unlimited)
    pes[10] = 0x80
    pes[11] = 0x80      # PTS flag
    pes[12] = 0x05      # header data length
    # PTS
    pts = seq * 90000 * 6  # 6 second segments
    pes[13] = 0x21 | ((pts >> 29) & 0x0E)
    pes[14] = (pts >> 22) & 0xFF
    pes[15] = 0x01 | ((pts >> 14) & 0xFE)
    pes[16] = (pts >> 7) & 0xFF
    pes[17] = 0x01 | ((pts << 1) & 0xFE)
    for i in range(18, 188):
        pes[i] = (i + seq) & 0xFF
    packets.extend(pes)

    return bytes(packets)


def build_ttml_document():
    """Build a valid IMSC1/TTML subtitle document."""
    return """<?xml version="1.0" encoding="UTF-8"?>
<tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml"
    xmlns:ttp="http://www.w3.org/ns/ttml#parameter"
    xmlns:tts="http://www.w3.org/ns/ttml#styling"
    xmlns:ttm="http://www.w3.org/ns/ttml#metadata"
    xmlns:ittp="http://www.w3.org/ns/ttml/profile/imsc1#parameter"
    ttp:profile="http://www.w3.org/ns/ttml/profile/imsc1/text"
    ttp:timeBase="media"
    ttp:cellResolution="32 15"
    ittp:progressivelyDecodable="true">
  <head>
    <layout>
      <region xml:id="bottom"
              tts:origin="10% 80%"
              tts:extent="80% 15%"
              tts:displayAlign="after"
              tts:textAlign="center"/>
    </layout>
    <styling>
      <style xml:id="default"
             tts:fontFamily="proportionalSansSerif"
             tts:fontSize="100%"
             tts:color="white"
             tts:backgroundColor="rgba(0,0,0,0.8)"/>
    </styling>
  </head>
  <body>
    <div region="bottom" style="default">
      <p begin="00:00:01.000" end="00:00:04.000">
        <span>Welcome to the HLS Kit demo.</span>
      </p>
      <p begin="00:00:05.000" end="00:00:08.000">
        <span>This is an IMSC1 subtitle sample.</span>
      </p>
      <p begin="00:00:09.000" end="00:00:12.000">
        <span>Testing TTML parsing and rendering.</span>
      </p>
      <p begin="00:00:13.000" end="00:00:16.000">
        <span>Segment 1 of the subtitle track.</span>
      </p>
    </div>
  </body>
</tt>"""


def build_hevc_annexb():
    """Build a synthetic HEVC Annex B bitstream with VPS/SPS/PPS + IDR NALUs."""
    data = bytearray()

    # VPS (NAL type 32)
    vps = bytearray([
        0x40, 0x01,  # NAL header: type=32 (VPS)
        0x0C, 0x01, 0xFF, 0xFF,
        0x02, 0x20, 0x00, 0x00, 0x03, 0x00, 0xB0, 0x00,
        0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x7B, 0xAC,
        0x09,
    ])
    data.extend(b"\x00\x00\x00\x01")
    data.extend(vps)

    # SPS (NAL type 33)
    sps = bytearray([
        0x42, 0x01,  # NAL header: type=33 (SPS)
        0x01, 0x02, 0x20, 0x00, 0x00, 0x03, 0x00, 0xB0,
        0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x7B,
        0xA0, 0x03, 0xC0, 0x80, 0x10, 0xE5, 0x96, 0x56,
        0x69, 0x24, 0xCA, 0xE0,
    ])
    data.extend(b"\x00\x00\x00\x01")
    data.extend(sps)

    # PPS (NAL type 34)
    pps = bytearray([
        0x44, 0x01,  # NAL header: type=34 (PPS)
        0xC1, 0x72, 0xB4, 0x62, 0x40,
    ])
    data.extend(b"\x00\x00\x00\x01")
    data.extend(pps)

    # IDR frames (NAL type 19)
    for i in range(5):
        idr = bytearray([0x26, 0x01])  # NAL header: type=19 (IDR_W_RADL)
        idr.extend(bytes(128))  # Synthetic frame data
        data.extend(b"\x00\x00\x00\x01")
        data.extend(idr)

    return bytes(data)


def build_vexu_init_segment():
    """Build an fMP4 init segment with vexu/stri/hero boxes for MV-HEVC."""
    ftyp = build_ftyp()

    # Build stri FullBox: 12 bytes header + 1 byte payload
    stri_payload = struct.pack(">I", 0) + bytes([0x03])  # version+flags + view_byte
    stri = struct.pack(">I", 8 + len(stri_payload)) + b"stri" + stri_payload

    # Build hero FullBox
    hero_payload = struct.pack(">I", 0) + bytes([0x00])  # version+flags + hero_eye
    hero = struct.pack(">I", 8 + len(hero_payload)) + b"hero" + hero_payload

    # Build eyes container
    eyes_inner = stri
    eyes = struct.pack(">I", 8 + len(eyes_inner)) + b"eyes" + eyes_inner

    # Build vexu container
    vexu_inner = eyes + hero
    vexu = struct.pack(">I", 8 + len(vexu_inner)) + b"vexu" + vexu_inner

    # Embed vexu in a moov similar to standard init
    moov = build_minimal_moov()
    # Append vexu to moov (simplified — in reality it goes inside hvc1)
    moov_data = bytearray(moov)
    moov_inner = moov_data[8:]  # strip moov header
    new_moov_inner = moov_inner + vexu
    new_moov = struct.pack(">I", 8 + len(new_moov_inner)) + b"moov" + bytes(new_moov_inner)

    return ftyp + new_moov


# ──────────────────────────────────────────────────────────────────────
# Manifest Templates
# ──────────────────────────────────────────────────────────────────────

MANIFESTS = {}


def _register_manifests():
    """Pre-generate all manifest content."""

    # ── VOD (0.1.0–0.2.0) ──

    MANIFESTS["/vod/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,URI="audio/en.m3u8"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="French",LANGUAGE="fr",DEFAULT=NO,AUTOSELECT=YES,URI="audio/fr.m3u8"

#EXT-X-STREAM-INF:BANDWIDTH=800000,AVERAGE-BANDWIDTH=700000,RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2",AUDIO="audio",FRAME-RATE=30.000
360p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2800000,AVERAGE-BANDWIDTH=2500000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2",AUDIO="audio",FRAME-RATE=30.000
720p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,AVERAGE-BANDWIDTH=4500000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2",AUDIO="audio",FRAME-RATE=30.000
1080p/playlist.m3u8
"""

    for quality in ["360p", "720p", "1080p"]:
        MANIFESTS[f"/vod/{quality}/playlist.m3u8"] = f"""\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-MAP:URI="init.mp4"

#EXTINF:6.000,
segment_000.m4s
#EXTINF:6.000,
segment_001.m4s
#EXTINF:6.000,
segment_002.m4s
#EXTINF:4.500,
segment_003.m4s
#EXT-X-ENDLIST
"""

    MANIFESTS["/vod/encrypted/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-SESSION-KEY:METHOD=AES-128,URI="https://example.com/key",IV=0x00000000000000000000000000000001

#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
encrypted/playlist.m3u8
"""

    MANIFESTS["/vod/encrypted/playlist.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD

#EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key",IV=0x00000000000000000000000000000001

#EXTINF:6.000,
segment_000.ts
#EXTINF:6.000,
segment_001.ts
#EXTINF:6.000,
segment_002.ts
#EXT-X-ENDLIST
"""

    MANIFESTS["/vod/iframe/playlist.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-I-FRAMES-ONLY
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-MAP:URI="init.mp4"

#EXTINF:6.000,
#EXT-X-BYTERANGE:50000@0
segment_000.m4s
#EXTINF:6.000,
#EXT-X-BYTERANGE:50000@0
segment_001.m4s
#EXT-X-ENDLIST
"""

    MANIFESTS["/vod/byterange/playlist.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-MAP:URI="init.mp4"

#EXTINF:6.000,
#EXT-X-BYTERANGE:500000@0
bigfile.m4s
#EXTINF:6.000,
#EXT-X-BYTERANGE:500000@500000
bigfile.m4s
#EXTINF:6.000,
#EXT-X-BYTERANGE:500000@1000000
bigfile.m4s
#EXT-X-ENDLIST
"""

    # ── Live (0.3.0) ──

    MANIFESTS["/live/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",LANGUAGE="en",DEFAULT=YES,URI="audio/playlist.m3u8"

#EXT-X-STREAM-INF:BANDWIDTH=2800000,AVERAGE-BANDWIDTH=2500000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2",AUDIO="audio"
stream/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,AVERAGE-BANDWIDTH=4500000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2",AUDIO="audio"
1080p/playlist.m3u8
"""

    MANIFESTS["/live/event/playlist.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:EVENT
#EXT-X-MAP:URI="init.mp4"

#EXTINF:6.000,
segment_000.m4s
#EXTINF:6.000,
segment_001.m4s
#EXTINF:6.000,
segment_002.m4s
"""

    # ── Variable Substitution (0.4.0) ──

    MANIFESTS["/var/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-DEFINE:NAME="base-url",VALUE="https://cdn.example.com/content"
#EXT-X-DEFINE:NAME="token",QUERYPARAM="token"
#EXT-X-DEFINE:IMPORT="session-id"

#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
{$base-url}/720p/playlist.m3u8?token={$token}
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
{$base-url}/1080p/playlist.m3u8?token={$token}
"""

    MANIFESTS["/var/media.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD

#EXT-X-DEFINE:NAME="cdn",VALUE="https://cdn.example.com"
#EXT-X-DEFINE:NAME="token",QUERYPARAM="token"

#EXT-X-MAP:URI="{$cdn}/init.mp4?auth={$token}"

#EXTINF:6.000,
{$cdn}/segment_000.m4s?auth={$token}
#EXTINF:6.000,
{$cdn}/segment_001.m4s?auth={$token}
#EXT-X-ENDLIST
"""

    # ── Spatial / Immersive (0.4.0) ──

    MANIFESTS["/spatial/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-STREAM-INF:BANDWIDTH=10000000,AVERAGE-BANDWIDTH=9000000,RESOLUTION=1920x1080,CODECS="hvc1.2.4.L123.B0",SUPPLEMENTAL-CODECS="dvh1.20.09/db4h",REQ-VIDEO-LAYOUT="CH-STEREO",FRAME-RATE=30.000
stereo/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,AVERAGE-BANDWIDTH=4500000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2",FRAME-RATE=30.000
2d/playlist.m3u8

#EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=500000,RESOLUTION=1920x1080,CODECS="hvc1.2.4.L123.B0",REQ-VIDEO-LAYOUT="CH-STEREO",URI="stereo/iframe.m3u8"
"""

    MANIFESTS["/spatial/immersive.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-STREAM-INF:BANDWIDTH=20000000,AVERAGE-BANDWIDTH=18000000,RESOLUTION=4096x4096,CODECS="hvc1.2.4.L153.B0",REQ-VIDEO-LAYOUT="CH-STEREO,PROJ-HEQU",FRAME-RATE=90.000
immersive/playlist.m3u8
"""

    MANIFESTS["/spatial/360.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-STREAM-INF:BANDWIDTH=15000000,AVERAGE-BANDWIDTH=13000000,RESOLUTION=3840x1920,CODECS="hvc1.2.4.L150.B0",REQ-VIDEO-LAYOUT="PROJ-EQUI",FRAME-RATE=30.000
360/playlist.m3u8
"""

    # ── IMSC1 Subtitles (0.4.0) ──

    MANIFESTS["/subs/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,CODECS="stpp.ttml.im1t",URI="en/playlist.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="French",LANGUAGE="fr",DEFAULT=NO,AUTOSELECT=YES,CODECS="stpp.ttml.im1t",URI="fr/playlist.m3u8"

#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2",SUBTITLES="subs"
720p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2",SUBTITLES="subs"
1080p/playlist.m3u8
"""

    MANIFESTS["/subs/en/playlist.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-MAP:URI="init.mp4"

#EXTINF:6.000,
sub_000.m4s
#EXTINF:6.000,
sub_001.m4s
#EXTINF:6.000,
sub_002.m4s
#EXT-X-ENDLIST
"""

    # ── Metadata / DRM / Accessibility (0.3.0) ──

    MANIFESTS["/meta/playlist.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:EVENT
#EXT-X-MAP:URI="init.mp4"

#EXT-X-DATERANGE:ID="ad-break-001",CLASS="com.example.ad",START-DATE="2026-01-01T00:00:30.000Z",DURATION=30.0,SCTE35-CMD=0xFC301600000000000000FFF0140500000BB800000000007FEFFE
#EXTINF:6.000,
segment_000.m4s
#EXTINF:6.000,
segment_001.m4s
#EXT-X-DATERANGE:ID="chapter-002",START-DATE="2026-01-01T00:00:42.000Z",PLANNED-DURATION=120.0,X-TITLE="Chapter 2"
#EXTINF:6.000,
segment_002.m4s
#EXTINF:6.000,
segment_003.m4s
"""

    MANIFESTS["/drm/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-SESSION-KEY:METHOD=SAMPLE-AES-CTR,URI="skd://fairplay.example.com/key1",KEYFORMAT="com.apple.streamingkeydelivery",KEYFORMATVERSIONS="1"
#EXT-X-SESSION-KEY:METHOD=SAMPLE-AES-CTR,URI="data:text/plain;base64,AAAA",KEYFORMAT="urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed",KEYFORMATVERSIONS="1"

#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
drm/playlist.m3u8
"""

    MANIFESTS["/a11y/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS

#EXT-X-MEDIA:TYPE=CLOSED-CAPTIONS,GROUP-ID="cc",NAME="English CC",LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,INSTREAM-ID="CC1"
#EXT-X-MEDIA:TYPE=CLOSED-CAPTIONS,GROUP-ID="cc",NAME="Spanish CC",LANGUAGE="es",DEFAULT=NO,AUTOSELECT=YES,INSTREAM-ID="CC3"
#EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a11y-audio",NAME="Audio Description",LANGUAGE="en",DEFAULT=NO,AUTOSELECT=NO,CHARACTERISTICS="public.accessibility.describes-video",URI="audio-desc/playlist.m3u8"
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English SDH",LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,CHARACTERISTICS="public.accessibility.transcribes-spoken-dialog,public.accessibility.describes-music-and-sound",URI="sdh/en.m3u8"

#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2",CLOSED-CAPTIONS="cc",AUDIO="a11y-audio",SUBTITLES="subs"
720p/playlist.m3u8
"""

    # ── Content Steering (0.3.0) ──

    MANIFESTS["/steer/master.m3u8"] = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-CONTENT-STEERING:SERVER-URI="/steer/steering.json",PATHWAY-ID="CDN-A"

#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2",PATHWAY-ID="CDN-A"
cdn-a/720p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2",PATHWAY-ID="CDN-B"
cdn-b/720p/playlist.m3u8
"""

    MANIFESTS["/steer/steering.json"] = json.dumps({
        "VERSION": 1,
        "TTL": 300,
        "RELOAD-URI": "/steer/steering.json",
        "PATHWAY-PRIORITY": ["CDN-A", "CDN-B"],
    }, indent=2)


_register_manifests()


# ──────────────────────────────────────────────────────────────────────
# Statistics Tracker
# ──────────────────────────────────────────────────────────────────────

class Stats:
    """Thread-safe request statistics."""

    def __init__(self, label="default"):
        self.label = label
        self._lock = threading.Lock()
        self.requests = 0
        self.segments = 0
        self.playlists = 0
        self.init_segments = 0
        self.bytes_received = 0
        self.bytes_sent = 0
        self.errors = 0
        self.start_time = time.time()

    def record_request(self, path, body_len=0, sent_len=0):
        with self._lock:
            self.requests += 1
            self.bytes_received += body_len
            self.bytes_sent += sent_len
            if path.endswith(".m3u8"):
                self.playlists += 1
            elif path.endswith((".m4s", ".ts")):
                self.segments += 1
            elif path.endswith(".mp4") and "init" in path:
                self.init_segments += 1

    def record_error(self):
        with self._lock:
            self.errors += 1

    def summary(self):
        elapsed = time.time() - self.start_time
        with self._lock:
            return {
                "label": self.label,
                "elapsed": elapsed,
                "requests": self.requests,
                "segments": self.segments,
                "playlists": self.playlists,
                "init_segments": self.init_segments,
                "bytes_received": self.bytes_received,
                "bytes_sent": self.bytes_sent,
                "errors": self.errors,
            }


# ──────────────────────────────────────────────────────────────────────
# Live Playlist State
# ──────────────────────────────────────────────────────────────────────

class LivePlaylistState:
    """Manages auto-updating live playlists."""

    def __init__(self):
        self._lock = threading.Lock()
        self._seq = 0
        self._segments = []
        self._parts = []
        self._window = 5
        self._target_duration = 6
        self._part_duration = 0.5
        self._last_update = time.time()

    def update(self):
        """Add a new segment, slide window."""
        with self._lock:
            self._seq += 1
            seg_name = f"segment_{self._seq:06d}.m4s"
            self._segments.append(seg_name)
            if len(self._segments) > self._window:
                self._segments = self._segments[-self._window:]
            # Generate new parts
            self._parts = []
            for i in range(4):
                self._parts.append(f"segment_{self._seq:06d}.{i}.m4s")
            self._last_update = time.time()

    @property
    def media_sequence(self):
        with self._lock:
            return max(0, self._seq - self._window + 1)

    def sliding_playlist(self):
        with self._lock:
            msn = max(0, self._seq - self._window + 1)
            lines = [
                "#EXTM3U",
                "#EXT-X-VERSION:7",
                f"#EXT-X-TARGETDURATION:{self._target_duration}",
                f"#EXT-X-MEDIA-SEQUENCE:{msn}",
                '#EXT-X-MAP:URI="init.mp4"',
                "",
            ]
            for seg in self._segments:
                lines.append(f"#EXTINF:{self._target_duration}.000,")
                lines.append(seg)
            return "\n".join(lines) + "\n"

    def dvr_playlist(self):
        with self._lock:
            lines = [
                "#EXTM3U",
                "#EXT-X-VERSION:7",
                f"#EXT-X-TARGETDURATION:{self._target_duration}",
                "#EXT-X-MEDIA-SEQUENCE:0",
                '#EXT-X-MAP:URI="init.mp4"',
                "",
            ]
            for i in range(self._seq + 1):
                lines.append(f"#EXTINF:{self._target_duration}.000,")
                lines.append(f"segment_{i:06d}.m4s")
            return "\n".join(lines) + "\n"

    def ll_playlist(self, msn=None, part=None):
        with self._lock:
            cur_msn = self._seq
            lines = [
                "#EXTM3U",
                "#EXT-X-VERSION:9",
                f"#EXT-X-TARGETDURATION:{self._target_duration}",
                f"#EXT-X-MEDIA-SEQUENCE:{max(0, cur_msn - self._window + 1)}",
                f"#EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES,CAN-SKIP-UNTIL={self._target_duration * 6},PART-HOLD-BACK={self._part_duration * 3:.1f}",
                f"#EXT-X-PART-INF:PART-TARGET={self._part_duration:.6f}",
                '#EXT-X-MAP:URI="init.mp4"',
                "",
            ]
            # Recent complete segments
            start = max(0, cur_msn - self._window + 1)
            for i in range(start, cur_msn + 1):
                # Parts for this segment
                for p in range(4):
                    independent = ",INDEPENDENT=YES" if p == 0 else ""
                    lines.append(
                        f'#EXT-X-PART:DURATION={self._part_duration:.6f},URI="segment_{i:06d}.{p}.m4s"{independent}'
                    )
                lines.append(f"#EXTINF:{self._target_duration}.000,")
                lines.append(f"segment_{i:06d}.m4s")

            # Preload hint for next segment
            next_seg = cur_msn + 1
            lines.append(
                f'#EXT-X-PRELOAD-HINT:TYPE=PART,URI="segment_{next_seg:06d}.0.m4s"'
            )
            return "\n".join(lines) + "\n"

    def delta_playlist(self):
        """Return a skip playlist with only recent segments."""
        with self._lock:
            cur_msn = self._seq
            skip_count = max(0, cur_msn - 2)
            lines = [
                "#EXTM3U",
                "#EXT-X-VERSION:9",
                f"#EXT-X-TARGETDURATION:{self._target_duration}",
                "#EXT-X-MEDIA-SEQUENCE:0",
                '#EXT-X-MAP:URI="init.mp4"',
                f"#EXT-X-SKIP:SKIPPED-SEGMENTS={skip_count}",
                "",
            ]
            start = max(0, cur_msn - 2)
            for i in range(start, cur_msn + 1):
                lines.append(f"#EXTINF:{self._target_duration}.000,")
                lines.append(f"segment_{i:06d}.m4s")
            return "\n".join(lines) + "\n"


# ──────────────────────────────────────────────────────────────────────
# Request Handler
# ──────────────────────────────────────────────────────────────────────

class HLSHandler(BaseHTTPRequestHandler):
    """HTTP request handler for all mock server modes."""

    server_mode = "serve"
    fail_mode = None
    fail_rate = 3
    s3_compat = False
    stats = None
    stats_map = {}          # For multi mode
    live_state = None
    _request_count = 0
    _request_lock = threading.Lock()

    def log_message(self, fmt, *args):
        """Override default logging to use our colored output."""
        pass  # We handle logging ourselves

    def _should_fail(self):
        """Check if this request should fail based on fail_mode."""
        if not self.fail_mode:
            return False

        if self.fail_mode == "intermittent":
            with self._request_lock:
                HLSHandler._request_count += 1
                count = HLSHandler._request_count
            if count % self.fail_rate == 0:
                return True
            return False
        return True

    def _apply_failure(self):
        """Apply the configured failure mode. Returns True if handled."""
        if not self.fail_mode:
            return False

        if self.fail_mode == "403":
            self.send_error(403, "Forbidden")
            self.stats.record_error()
            log(f"FAIL 403 → {self.path}", Color.RED)
            return True
        elif self.fail_mode == "500":
            self.send_error(500, "Internal Server Error")
            self.stats.record_error()
            log(f"FAIL 500 → {self.path}", Color.RED)
            return True
        elif self.fail_mode == "timeout":
            log(f"FAIL timeout → {self.path} (hanging...)", Color.RED)
            self.stats.record_error()
            time.sleep(300)  # Block for 5 minutes
            return True
        elif self.fail_mode == "slow":
            log(f"FAIL slow → {self.path} (5s delay...)", Color.YELLOW)
            time.sleep(5)
            return False  # Still serve after delay
        elif self.fail_mode == "disconnect":
            log(f"FAIL disconnect → {self.path}", Color.RED)
            self.stats.record_error()
            self.wfile.write(b"HTTP/1.1 200 OK\r\n")
            self.wfile.flush()
            self.connection.close()
            return True
        elif self.fail_mode == "intermittent":
            # Already checked in _should_fail
            self.send_error(503, "Service Unavailable")
            self.stats.record_error()
            log(f"FAIL intermittent → {self.path}", Color.YELLOW)
            return True

        return False

    def _cors_headers(self):
        """Add CORS headers to response."""
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PUT, POST, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization, x-amz-content-sha256, x-amz-date")

    def _send_content(self, content, content_type, path=""):
        """Send response with content."""
        if isinstance(content, str):
            data = content.encode("utf-8")
        else:
            data = content

        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self._cors_headers()
        self.end_headers()
        self.wfile.write(data)

        self.stats.record_request(path or self.path, sent_len=len(data))
        log(f"GET {self.path} → {len(data)} bytes ({content_type})", Color.GREEN)

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):
        """Handle GET requests."""
        parsed = urlparse(self.path)
        path = parsed.path
        query = parse_qs(parsed.query)

        if self._should_fail():
            if self._apply_failure():
                return

        # ── Live mode: dynamic playlists ──
        if self.server_mode in ("live", "multi") and self.live_state:
            if path == "/live/stream/playlist.m3u8":
                self._send_content(
                    self.live_state.sliding_playlist(),
                    mime_type(path), path
                )
                return
            elif path == "/live/dvr/playlist.m3u8":
                self._send_content(
                    self.live_state.dvr_playlist(),
                    mime_type(path), path
                )
                return
            elif path == "/live/ll/playlist.m3u8":
                msn = query.get("_HLS_msn", [None])[0]
                part = query.get("_HLS_part", [None])[0]
                skip = query.get("_HLS_skip", [None])[0]

                if skip == "YES":
                    self._send_content(
                        self.live_state.delta_playlist(),
                        mime_type(path), path
                    )
                    return

                if msn is not None:
                    # Blocking playlist reload
                    target_msn = int(msn)
                    deadline = time.time() + 10
                    while self.live_state._seq < target_msn and time.time() < deadline:
                        time.sleep(0.1)
                    log(f"Blocking reload: MSN={msn} (current={self.live_state._seq})", Color.CYAN)

                self._send_content(
                    self.live_state.ll_playlist(msn, part),
                    mime_type(path), path
                )
                return

        # ── Static manifests ──
        if path in MANIFESTS:
            ct = mime_type(path)
            if path.endswith(".json"):
                ct = "application/json"
            self._send_content(MANIFESTS[path], ct, path)
            return

        # ── Variable substitution with query params ──
        if path == "/var/media.m3u8":
            content = MANIFESTS.get("/var/media.m3u8", "")
            token = query.get("token", [""])[0]
            if token:
                content = content.replace("{$token}", token)
            self._send_content(content, mime_type(path), path)
            return

        # ── TTML sample ──
        if path == "/subs/sample.ttml":
            self._send_content(build_ttml_document(), mime_type(path), path)
            return

        # ── Steering JSON ──
        if path == "/steer/steering.json":
            self._send_content(MANIFESTS["/steer/steering.json"], "application/json", path)
            return

        # ── Spatial mode: MV-HEVC content ──
        if path == "/spatial/init.mp4":
            self._send_content(build_vexu_init_segment(), mime_type(path), path)
            return

        if path == "/spatial/sample.hevc":
            self._send_content(build_hevc_annexb(), mime_type(path), path)
            return

        if path.startswith("/spatial/segment_") and path.endswith(".m4s"):
            try:
                seq = int(path.split("_")[1].split(".")[0])
            except (IndexError, ValueError):
                seq = 0
            self._send_content(build_media_segment(seq), mime_type(path), path)
            return

        # ── Synthetic segments ──
        if path.endswith(".mp4") and ("init" in path or "map" in path.lower()):
            self._send_content(build_init_segment(), mime_type(path), path)
            return

        if path.endswith(".m4s"):
            try:
                seq = int(path.split("_")[-1].split(".")[0])
            except (IndexError, ValueError):
                seq = 0
            self._send_content(build_media_segment(seq), mime_type(path), path)
            return

        if path.endswith(".ts"):
            try:
                seq = int(path.split("_")[-1].split(".")[0])
            except (IndexError, ValueError):
                seq = 0
            self._send_content(build_ts_segment(seq), mime_type(path), path)
            return

        # ── Generic media playlist for unregistered paths ──
        if path.endswith(".m3u8"):
            generic = """\
#EXTM3U
#EXT-X-VERSION:7
#EXT-X-TARGETDURATION:6
#EXT-X-MEDIA-SEQUENCE:0
#EXT-X-PLAYLIST-TYPE:VOD
#EXT-X-MAP:URI="init.mp4"

#EXTINF:6.000,
segment_000.m4s
#EXTINF:6.000,
segment_001.m4s
#EXT-X-ENDLIST
"""
            self._send_content(generic, mime_type(path), path)
            return

        self.send_error(404, "Not Found")
        log(f"GET {self.path} → 404", Color.RED)

    def do_PUT(self):
        """Handle PUT requests (segment push)."""
        self._handle_push()

    def do_POST(self):
        """Handle POST requests (segment push)."""
        self._handle_push()

    def _handle_push(self):
        """Process a pushed segment."""
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length) if content_length > 0 else b""

        if self._should_fail():
            if self._apply_failure():
                return

        # S3 compatibility check
        if self.s3_compat:
            if "x-amz-content-sha256" not in self.headers:
                log(Color.warn(f"S3: missing x-amz-content-sha256 for {self.path}"), Color.YELLOW)

        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self._cors_headers()
        self.end_headers()
        self.wfile.write(b"OK")

        ct = self.headers.get("Content-Type", "unknown")
        self.stats.record_request(self.path, body_len=len(body))

        ext = os.path.splitext(self.path)[1]
        label = "segment" if ext in (".m4s", ".ts") else "playlist" if ext == ".m3u8" else "init" if ext == ".mp4" else "file"
        log(f"PUSH {label}: {self.path} ({fmt_bytes(len(body))}, {ct})", Color.MAGENTA)

        if _verbose and body:
            hex_preview = body[:64].hex()
            log_verbose(f"  hex: {hex_preview}{'...' if len(body) > 64 else ''}")


# ──────────────────────────────────────────────────────────────────────
# Server Runners
# ──────────────────────────────────────────────────────────────────────

def print_banner(mode, port, extra=""):
    """Print startup banner."""
    title = f"Mock HLS Server — {mode.upper()}"
    w = max(len(title) + 4, 50)
    print()
    print(f"{Color.CYAN}╔{'═' * w}╗{Color.RESET}")
    print(f"{Color.CYAN}║{Color.BOLD}  {title}{' ' * (w - len(title) - 2)}║{Color.RESET}")
    print(f"{Color.CYAN}╠{'═' * w}╣{Color.RESET}")
    print(f"{Color.CYAN}║{Color.RESET}  Port: {Color.GREEN}{port}{Color.RESET}{' ' * (w - 10 - len(str(port)))}║")
    if extra:
        for line in extra.strip().split("\n"):
            padded = line + " " * max(0, w - 2 - len(line))
            print(f"{Color.CYAN}║{Color.RESET}  {padded}║")
    print(f"{Color.CYAN}╚{'═' * w}╝{Color.RESET}")
    print()


def print_endpoints(port, mode):
    """Print available endpoints for the current mode."""
    base = f"http://localhost:{port}"
    print(f"{Color.BOLD}Available endpoints:{Color.RESET}")
    print()

    if mode in ("serve", "live"):
        sections = [
            ("VOD (0.1.0–0.2.0)", [
                "/vod/master.m3u8", "/vod/360p/playlist.m3u8",
                "/vod/encrypted/master.m3u8", "/vod/iframe/playlist.m3u8",
                "/vod/byterange/playlist.m3u8",
            ]),
            ("Live (0.3.0)", [
                "/live/master.m3u8",
            ]),
            ("Variables (0.4.0)", [
                "/var/master.m3u8", "/var/media.m3u8?token=abc123",
            ]),
            ("Spatial (0.4.0)", [
                "/spatial/master.m3u8", "/spatial/immersive.m3u8", "/spatial/360.m3u8",
            ]),
            ("IMSC1 Subtitles (0.4.0)", [
                "/subs/master.m3u8", "/subs/en/playlist.m3u8", "/subs/sample.ttml",
            ]),
            ("Metadata/DRM/A11y (0.3.0)", [
                "/meta/playlist.m3u8", "/drm/master.m3u8", "/a11y/master.m3u8",
            ]),
            ("Content Steering (0.3.0)", [
                "/steer/master.m3u8", "/steer/steering.json",
            ]),
        ]

        if mode == "live":
            sections.insert(2, ("Live Dynamic", [
                "/live/stream/playlist.m3u8 (sliding window, auto-updates)",
                "/live/dvr/playlist.m3u8 (DVR, grows over time)",
                "/live/ll/playlist.m3u8 (LL-HLS, supports _HLS_msn/_HLS_part/_HLS_skip)",
                "/live/event/playlist.m3u8",
            ]))

        for title, endpoints in sections:
            print(f"  {Color.YELLOW}{title}{Color.RESET}")
            for ep in endpoints:
                if ep.startswith("/"):
                    print(f"    {Color.DIM}{base}{Color.RESET}{ep}")
                else:
                    print(f"    {Color.DIM}{ep}{Color.RESET}")
            print()

    elif mode == "push":
        print(f"  {Color.YELLOW}Push Receiver{Color.RESET}")
        print(f"    PUT/POST any path to {Color.DIM}{base}{Color.RESET}")
        print(f"    Accepts: .m3u8, .m4s, .ts, .mp4, .ttml")
        print()

    elif mode == "spatial":
        print(f"  {Color.YELLOW}MV-HEVC Spatial (0.4.0){Color.RESET}")
        print(f"    {Color.DIM}{base}{Color.RESET}/spatial/init.mp4 (init with vexu/stri/hero)")
        print(f"    {Color.DIM}{base}{Color.RESET}/spatial/segment_N.m4s (media segments)")
        print(f"    {Color.DIM}{base}{Color.RESET}/spatial/sample.hevc (Annex B bitstream)")
        print(f"    {Color.DIM}{base}{Color.RESET}/spatial/master.m3u8")
        print(f"    {Color.DIM}{base}{Color.RESET}/spatial/immersive.m3u8")
        print(f"    {Color.DIM}{base}{Color.RESET}/spatial/360.m3u8")
        print()

    elif mode == "multi":
        print(f"  {Color.YELLOW}Multi-Destination Push Receiver{Color.RESET}")
        print(f"    Each port operates as an independent push receiver.")
        print()


def print_stats(stats_list):
    """Print session summary on shutdown."""
    print()
    print(f"{Color.CYAN}{'═' * 50}{Color.RESET}")
    print(f"{Color.BOLD}  Session Summary{Color.RESET}")
    print(f"{Color.CYAN}{'═' * 50}{Color.RESET}")

    for s in stats_list:
        info = s.summary()
        elapsed = info["elapsed"]
        mins = int(elapsed // 60)
        secs = elapsed % 60

        print(f"\n  {Color.YELLOW}{info['label']}{Color.RESET}")
        print(f"    Duration:      {mins}m {secs:.1f}s")
        print(f"    Requests:      {info['requests']}")
        print(f"    Segments:      {info['segments']}")
        print(f"    Playlists:     {info['playlists']}")
        print(f"    Init segments: {info['init_segments']}")
        print(f"    Received:      {fmt_bytes(info['bytes_received'])}")
        print(f"    Sent:          {fmt_bytes(info['bytes_sent'])}")
        if info["errors"] > 0:
            print(f"    Errors:        {Color.RED}{info['errors']}{Color.RESET}")
        else:
            print(f"    Errors:        0")

    print(f"\n{Color.CYAN}{'═' * 50}{Color.RESET}")
    print()


def run_server(args):
    """Run the mock server in the specified mode."""
    global _verbose
    _verbose = args.verbose

    mode = args.mode
    port = args.port
    fail = getattr(args, "fail", None)
    fail_rate = getattr(args, "fail_rate", 3)
    s3 = getattr(args, "s3_compat", False)

    stats_list = []
    servers = []

    # Main stats
    main_stats = Stats(label=f"Port {port}")
    stats_list.append(main_stats)

    # Configure handler
    HLSHandler.server_mode = mode
    HLSHandler.fail_mode = fail
    HLSHandler.fail_rate = fail_rate
    HLSHandler.s3_compat = s3
    HLSHandler.stats = main_stats

    # Live state
    live_state = None
    if mode in ("live", "multi"):
        live_state = LivePlaylistState()
        HLSHandler.live_state = live_state

    # Extra banner info
    extra_lines = []
    if fail:
        extra_lines.append(f"Fail mode: {Color.RED}{fail}{Color.RESET}")
        if fail == "intermittent":
            extra_lines.append(f"Fail rate: every {fail_rate} requests")
    if s3:
        extra_lines.append(f"S3 compat: {Color.GREEN}enabled{Color.RESET}")
    if _verbose:
        extra_lines.append(f"Verbose: {Color.GREEN}enabled{Color.RESET}")
    extra = "\n".join(extra_lines)

    print_banner(mode, port, extra)
    print_endpoints(port, mode)

    # Main server
    HTTPServer.allow_reuse_address = True
    server = HTTPServer(("0.0.0.0", port), HLSHandler)
    server.timeout = 1
    servers.append(server)

    # Multi mode: additional ports
    if mode == "multi":
        for attr, fail_attr in [("port2", "fail2"), ("port3", "fail3")]:
            extra_port = getattr(args, attr, None)
            if extra_port:
                extra_stats = Stats(label=f"Port {extra_port}")
                stats_list.append(extra_stats)

                # Create a new handler class per port for independent stats/fail
                extra_fail = getattr(args, fail_attr, None)

                class PortHandler(HLSHandler):
                    pass

                PortHandler.stats = extra_stats
                PortHandler.fail_mode = extra_fail

                extra_server = HTTPServer(("0.0.0.0", extra_port), PortHandler)
                extra_server.timeout = 1
                servers.append(extra_server)

                log(Color.info(f"Multi-destination port {extra_port} ready" + (f" (fail: {extra_fail})" if extra_fail else "")))

    # Live update thread
    live_thread = None
    if live_state:
        live_running = threading.Event()
        live_running.set()

        def update_live():
            while live_running.is_set():
                live_state.update()
                log_verbose(f"Live: segment {live_state._seq} generated")
                time.sleep(2)

        live_thread = threading.Thread(target=update_live, daemon=True)
        live_thread.start()
        log(Color.info("Live playlist update thread started (2s interval)"))

    # Server threads
    running = threading.Event()
    running.set()

    def serve_forever(srv):
        while running.is_set():
            srv.handle_request()

    threads = []
    for srv in servers:
        t = threading.Thread(target=serve_forever, args=(srv,), daemon=True)
        t.start()
        threads.append(t)

    log(Color.success(f"Server listening on port {port}"))
    print(f"\n{Color.DIM}Press Ctrl+C to stop{Color.RESET}\n")

    # Signal handling
    def shutdown(signum, frame):
        print(f"\n{Color.YELLOW}Shutting down...{Color.RESET}")
        running.clear()
        if live_state and live_thread:
            live_running.clear()
        for srv in servers:
            srv.server_close()
        print_stats(stats_list)
        sys.exit(0)

    signal.signal(signal.SIGINT, shutdown)
    signal.signal(signal.SIGTERM, shutdown)

    # Block main thread
    try:
        while running.is_set():
            time.sleep(0.5)
    except KeyboardInterrupt:
        shutdown(None, None)


# ──────────────────────────────────────────────────────────────────────
# Argument Parsing
# ──────────────────────────────────────────────────────────────────────

def build_parser():
    """Build the argument parser with rich help text."""
    epilog = f"""\
{Color.BOLD}Examples:{Color.RESET}

  {Color.YELLOW}Serve mode{Color.RESET} — test parsing, validation, info commands:
    python3 mock-hls-server.py --mode serve --port 8080
    hlskit-cli info http://localhost:8080/vod/master.m3u8
    hlskit-cli validate http://localhost:8080/var/master.m3u8
    hlskit-cli manifest parse http://localhost:8080/spatial/master.m3u8
    hlskit-cli imsc1 parse http://localhost:8080/subs/sample.ttml

  {Color.YELLOW}Push mode{Color.RESET} — test HTTP push with failure simulation:
    python3 mock-hls-server.py --mode push --port 8080
    python3 mock-hls-server.py --mode push --port 8080 --fail slow
    python3 mock-hls-server.py --mode push --port 8080 --fail intermittent --fail-rate 5

  {Color.YELLOW}Live mode{Color.RESET} — test live pipeline, LL-HLS, DVR:
    python3 mock-hls-server.py --mode live --port 8080
    curl "http://localhost:8080/live/ll/playlist.m3u8?_HLS_msn=5&_HLS_part=2"
    curl "http://localhost:8080/live/stream/playlist.m3u8"

  {Color.YELLOW}Multi mode{Color.RESET} — test multi-destination push:
    python3 mock-hls-server.py --mode multi --port 8080 --port2 8081 --port3 8082
    python3 mock-hls-server.py --mode multi --port 8080 --port2 8081 --fail2 timeout

  {Color.YELLOW}Spatial mode{Color.RESET} — test MV-HEVC packaging:
    python3 mock-hls-server.py --mode spatial --port 8080
    curl http://localhost:8080/spatial/sample.hevc -o /tmp/sample.hevc
    hlskit-cli mvhevc package /tmp/sample.hevc -o /tmp/mvhevc/
    hlskit-cli mvhevc info /tmp/mvhevc/init.mp4

  {Color.YELLOW}S3-compatible push{Color.RESET}:
    python3 mock-hls-server.py --mode push --port 8080 --s3-compat
"""

    parser = argparse.ArgumentParser(
        prog="mock-hls-server.py",
        description="Mock HLS Server for swift-hls-kit manual testing.",
        epilog=epilog,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--mode", "-m",
        choices=["push", "serve", "live", "multi", "spatial"],
        default="serve",
        help="Server mode (default: serve)",
    )
    parser.add_argument(
        "--port", "-p",
        type=int, default=8080,
        help="Listen port (default: 8080)",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging with hex dumps",
    )

    # Push/failure options
    parser.add_argument(
        "--fail",
        choices=["403", "500", "timeout", "slow", "disconnect", "intermittent"],
        help="Failure simulation mode",
    )
    parser.add_argument(
        "--fail-rate",
        type=int, default=3,
        help="For --fail intermittent: fail every Nth request (default: 3)",
    )
    parser.add_argument(
        "--s3-compat",
        action="store_true",
        help="Expect S3-compatible headers on push requests",
    )

    # Multi mode
    parser.add_argument(
        "--port2",
        type=int,
        help="Second port for multi mode",
    )
    parser.add_argument(
        "--port3",
        type=int,
        help="Third port for multi mode",
    )
    parser.add_argument(
        "--fail2",
        choices=["403", "500", "timeout", "slow", "disconnect", "intermittent"],
        help="Failure mode for port2",
    )
    parser.add_argument(
        "--fail3",
        choices=["403", "500", "timeout", "slow", "disconnect", "intermittent"],
        help="Failure mode for port3",
    )

    return parser


# ──────────────────────────────────────────────────────────────────────
# Main
# ──────────────────────────────────────────────────────────────────────

def main():
    parser = build_parser()
    args = parser.parse_args()

    # Validate multi mode args
    if args.mode == "multi" and not args.port2:
        parser.error("--mode multi requires at least --port2")

    run_server(args)


if __name__ == "__main__":
    main()
