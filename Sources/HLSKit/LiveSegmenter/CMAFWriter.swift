// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates CMAF-compliant fMP4 initialization and media segments
/// from ``EncodedFrame`` data.
///
/// CMAFWriter produces proper ISOBMFF boxes for:
/// - **Init segments**: ftyp + moov (codec configuration, empty samples)
/// - **Media segments**: styp + moof + mdat (fragmented samples)
/// - **Partial segments**: moof + mdat (no styp, for LL-HLS)
///
/// ## Audio
/// ```swift
/// let writer = CMAFWriter()
/// let config = CMAFWriter.AudioConfig(
///     sampleRate: 48000, channels: 2, profile: .lc
/// )
/// let initSeg = writer.generateAudioInitSegment(config: config)
/// ```
///
/// ## Video
/// ```swift
/// let videoConfig = CMAFWriter.VideoConfig(
///     codec: .h264, width: 1920, height: 1080,
///     sps: spsData, pps: ppsData
/// )
/// let initSeg = writer.generateVideoInitSegment(config: videoConfig)
/// ```
public struct CMAFWriter: Sendable {

    /// Creates a new CMAF writer.
    public init() {}

    // MARK: - Init Segments

    /// Generate an audio initialization segment (ftyp + moov).
    ///
    /// - Parameter config: Audio codec configuration.
    /// - Returns: The init segment data.
    public func generateAudioInitSegment(
        config: AudioConfig
    ) -> Data {
        var writer = BinaryWriter()
        writer.writeData(buildCMAFFtyp())
        writer.writeData(
            buildAudioMoov(config: config)
        )
        return writer.data
    }

    /// Generate a video initialization segment (ftyp + moov).
    ///
    /// - Parameter config: Video codec configuration.
    /// - Returns: The init segment data.
    public func generateVideoInitSegment(
        config: VideoConfig
    ) -> Data {
        var writer = BinaryWriter()
        writer.writeData(buildCMAFFtyp())
        writer.writeData(
            buildVideoMoov(config: config)
        )
        return writer.data
    }

    // MARK: - Media Segments

    /// Generate a media segment (styp + moof + mdat) from encoded
    /// frames.
    ///
    /// - Parameters:
    ///   - frames: Encoded frames to package.
    ///   - sequenceNumber: Fragment sequence number (1-based).
    ///   - trackID: Track identifier (default 1).
    ///   - timescale: Media timescale for timestamp calculations.
    /// - Returns: The media segment data.
    public func generateMediaSegment(
        frames: [EncodedFrame],
        sequenceNumber: UInt32,
        trackID: UInt32 = 1,
        timescale: UInt32
    ) -> Data {
        let mdatPayload = frames.reduce(into: Data()) {
            $0.append($1.data)
        }
        let trafData = buildTraf(
            frames: frames,
            trackID: trackID,
            timescale: timescale
        )
        let moof = assembleMoof(
            sequenceNumber: sequenceNumber,
            traf: trafData,
            mdatPayloadSize: mdatPayload.count
        )
        var result = BinaryWriter()
        result.writeData(buildStyp())
        result.writeData(moof)
        result.writeData(buildMdat(payload: mdatPayload))
        return result.data
    }

    /// Generate a partial segment (moof + mdat, no styp) for LL-HLS.
    ///
    /// - Parameters:
    ///   - frames: Encoded frames to package.
    ///   - sequenceNumber: Fragment sequence number.
    ///   - trackID: Track identifier (default 1).
    ///   - timescale: Media timescale.
    /// - Returns: The partial segment data.
    public func generatePartialSegment(
        frames: [EncodedFrame],
        sequenceNumber: UInt32,
        trackID: UInt32 = 1,
        timescale: UInt32
    ) -> Data {
        let mdatPayload = frames.reduce(into: Data()) {
            $0.append($1.data)
        }
        let trafData = buildTraf(
            frames: frames,
            trackID: trackID,
            timescale: timescale
        )
        let moof = assembleMoof(
            sequenceNumber: sequenceNumber,
            traf: trafData,
            mdatPayloadSize: mdatPayload.count
        )
        var result = BinaryWriter()
        result.writeData(moof)
        result.writeData(buildMdat(payload: mdatPayload))
        return result.data
    }
}

// MARK: - Configuration Types

extension CMAFWriter {

    /// Audio codec configuration for init segment generation.
    public struct AudioConfig: Sendable, Equatable {

        /// Sample rate in Hz.
        public let sampleRate: Double

        /// Number of audio channels.
        public let channels: Int

        /// AAC profile.
        public let profile: AACProfile

        /// Track ID. Defaults to 1.
        public let trackID: UInt32

        /// Creates an audio configuration.
        ///
        /// - Parameters:
        ///   - sampleRate: Sample rate in Hz.
        ///   - channels: Number of audio channels.
        ///   - profile: AAC profile. Defaults to `.lc`.
        ///   - trackID: Track ID. Defaults to 1.
        public init(
            sampleRate: Double,
            channels: Int,
            profile: AACProfile = .lc,
            trackID: UInt32 = 1
        ) {
            self.sampleRate = sampleRate
            self.channels = channels
            self.profile = profile
            self.trackID = trackID
        }

        /// Timescale derived from sample rate.
        public var timescale: UInt32 {
            UInt32(sampleRate)
        }
    }

    /// Video codec configuration for init segment generation.
    public struct VideoConfig: Sendable, Equatable {

        /// Video codec type.
        public let codec: EncodedCodec

        /// Frame width in pixels.
        public let width: Int

        /// Frame height in pixels.
        public let height: Int

        /// H.264 Sequence Parameter Set.
        public let sps: Data

        /// H.264 Picture Parameter Set.
        public let pps: Data

        /// Track ID. Defaults to 1.
        public let trackID: UInt32

        /// Video timescale. Defaults to 90000.
        public let timescale: UInt32

        /// Creates a video configuration.
        ///
        /// - Parameters:
        ///   - codec: Video codec (`.h264` or `.h265`).
        ///   - width: Frame width.
        ///   - height: Frame height.
        ///   - sps: Sequence Parameter Set data.
        ///   - pps: Picture Parameter Set data.
        ///   - trackID: Track ID. Defaults to 1.
        ///   - timescale: Video timescale. Defaults to 90000.
        public init(
            codec: EncodedCodec,
            width: Int,
            height: Int,
            sps: Data,
            pps: Data,
            trackID: UInt32 = 1,
            timescale: UInt32 = 90_000
        ) {
            self.codec = codec
            self.width = width
            self.height = height
            self.sps = sps
            self.pps = pps
            self.trackID = trackID
            self.timescale = timescale
        }
    }
}

// MARK: - ftyp / styp

extension CMAFWriter {

    func buildCMAFFtyp() -> Data {
        var payload = BinaryWriter()
        payload.writeFourCC("cmfc")
        payload.writeUInt32(0)
        payload.writeFourCC("cmfc")
        payload.writeFourCC("iso6")
        payload.writeFourCC("isom")
        var box = BinaryWriter()
        box.writeBox(type: "ftyp", payload: payload.data)
        return box.data
    }

    func buildStyp() -> Data {
        var payload = BinaryWriter()
        payload.writeFourCC("msdh")
        payload.writeUInt32(0)
        payload.writeFourCC("msdh")
        payload.writeFourCC("msix")
        payload.writeFourCC("isom")
        var box = BinaryWriter()
        box.writeBox(type: "styp", payload: payload.data)
        return box.data
    }
}

// MARK: - Audio moov

extension CMAFWriter {

    private func buildAudioMoov(
        config: AudioConfig
    ) -> Data {
        let mvhd = buildMvhd(
            timescale: config.timescale,
            nextTrackID: config.trackID + 1
        )
        let trak = buildAudioTrak(config: config)
        let mvex = buildMvex(trackID: config.trackID)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "moov",
            children: [mvhd, trak, mvex]
        )
        return writer.data
    }

    private func buildAudioTrak(
        config: AudioConfig
    ) -> Data {
        let tkhd = buildTkhd(
            trackID: config.trackID,
            isAudio: true,
            width: 0, height: 0
        )
        let mdia = buildAudioMdia(config: config)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "trak",
            children: [tkhd, mdia]
        )
        return writer.data
    }

    private func buildAudioMdia(
        config: AudioConfig
    ) -> Data {
        let mdhd = buildMdhd(timescale: config.timescale)
        let hdlr = buildHdlr(type: "soun", name: "SoundHandler")
        let minf = buildAudioMinf(config: config)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mdia",
            children: [mdhd, hdlr, minf]
        )
        return writer.data
    }

    private func buildAudioMinf(
        config: AudioConfig
    ) -> Data {
        let smhd = buildSmhd()
        let dinf = buildDinf()
        let stbl = buildAudioStbl(config: config)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "minf",
            children: [smhd, dinf, stbl]
        )
        return writer.data
    }

    private func buildAudioStbl(
        config: AudioConfig
    ) -> Data {
        let stsd = buildAudioStsd(config: config)
        let emptyBoxes = buildEmptySampleTables()
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "stbl",
            children: [stsd] + emptyBoxes
        )
        return writer.data
    }

    private func buildAudioStsd(
        config: AudioConfig
    ) -> Data {
        let mp4a = buildMp4aSampleEntry(config: config)
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(1)  // entry count
        payload.writeData(mp4a)
        var box = BinaryWriter()
        box.writeBox(type: "stsd", payload: payload.data)
        return box.data
    }
}

// MARK: - Video moov (in CMAFWriterVideoMoov.swift)
