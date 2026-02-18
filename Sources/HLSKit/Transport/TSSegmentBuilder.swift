// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Sample data for TS segment building.
public struct SampleData: Sendable {
    /// Raw sample bytes from MP4 mdat.
    public let data: Data
    /// Presentation timestamp (90 kHz).
    public let pts: UInt64
    /// Decoding timestamp (90 kHz), nil if same as PTS.
    public let dts: UInt64?
    /// Duration in 90 kHz units.
    public let duration: UInt32
    /// Whether this is a sync sample (keyframe).
    public let isSync: Bool

    /// Creates sample data.
    ///
    /// - Parameters:
    ///   - data: Raw sample bytes.
    ///   - pts: Presentation timestamp (90 kHz).
    ///   - dts: Decoding timestamp, nil if same as PTS.
    ///   - duration: Duration in 90 kHz units.
    ///   - isSync: Whether this is a keyframe.
    public init(
        data: Data,
        pts: UInt64,
        dts: UInt64?,
        duration: UInt32,
        isSync: Bool
    ) {
        self.data = data
        self.pts = pts
        self.dts = dts
        self.duration = duration
        self.isSync = isSync
    }
}

/// Codec configuration extracted from MP4 for TS packaging.
public struct TSCodecConfig: Sendable {
    /// H.264 SPS in Annex B format (nil for audio-only).
    public let sps: Data?
    /// H.264 PPS in Annex B format (nil for audio-only).
    public let pps: Data?
    /// AAC configuration (nil for video-only).
    public let aacConfig: ADTSConverter.AACConfig?
    /// Video stream type.
    public let videoStreamType: ProgramTableGenerator.StreamType?
    /// Audio stream type.
    public let audioStreamType: ProgramTableGenerator.StreamType?

    /// Creates a TS codec configuration.
    ///
    /// - Parameters:
    ///   - sps: SPS in Annex B format.
    ///   - pps: PPS in Annex B format.
    ///   - aacConfig: AAC audio configuration.
    ///   - videoStreamType: Video stream type for PMT.
    ///   - audioStreamType: Audio stream type for PMT.
    public init(
        sps: Data?,
        pps: Data?,
        aacConfig: ADTSConverter.AACConfig?,
        videoStreamType: ProgramTableGenerator.StreamType?,
        audioStreamType: ProgramTableGenerator.StreamType?
    ) {
        self.sps = sps
        self.pps = pps
        self.aacConfig = aacConfig
        self.videoStreamType = videoStreamType
        self.audioStreamType = audioStreamType
    }
}

// MARK: - TS Segment Builder

/// Builds a complete MPEG-TS segment from MP4 sample data.
///
/// Handles the conversion pipeline:
/// MP4 samples → codec conversion → PES packetization
/// → TS packets → segment bytes.
public struct TSSegmentBuilder: Sendable {

    /// Creates a new TS segment builder.
    public init() {}

    /// Build a .ts segment for video + optional audio samples.
    ///
    /// - Parameters:
    ///   - videoSamples: Video sample data and metadata.
    ///   - audioSamples: Audio sample data (nil for video-only).
    ///   - config: Codec configuration (SPS/PPS, AAC config).
    ///   - sequenceNumber: Segment sequence number.
    /// - Returns: Complete .ts segment data.
    public func buildSegment(
        videoSamples: [SampleData],
        audioSamples: [SampleData]?,
        config: TSCodecConfig,
        sequenceNumber: UInt32
    ) -> Data {
        var ctx = WritingContext(config: config)

        // 1. Write PAT + PMT
        writePSITables(&ctx)

        // 2. Interleave video and audio by PTS
        let merged = mergeSamples(
            videoSamples: videoSamples,
            audioSamples: audioSamples
        )

        // 3. Packetize each sample
        for entry in merged {
            switch entry {
            case .video(let sample):
                writeVideoSample(sample, ctx: &ctx)
            case .audio(let sample):
                writeAudioSample(sample, ctx: &ctx)
            }
        }

        return ctx.output
    }

    /// Build a .ts segment for audio-only content.
    ///
    /// - Parameters:
    ///   - audioSamples: Audio sample data and metadata.
    ///   - config: Codec configuration (AAC config).
    ///   - sequenceNumber: Segment sequence number.
    /// - Returns: Complete .ts segment data.
    public func buildAudioOnlySegment(
        audioSamples: [SampleData],
        config: TSCodecConfig,
        sequenceNumber: UInt32
    ) -> Data {
        var ctx = WritingContext(config: config)

        writePSITables(&ctx)

        var isFirst = true
        for sample in audioSamples {
            let pcr: UInt64? = isFirst ? sample.pts * 300 : nil
            writeAudioSampleCore(
                sample, pcr: pcr, ctx: &ctx
            )
            isFirst = false
        }

        return ctx.output
    }
}

// MARK: - Writing Context

extension TSSegmentBuilder {

    /// Groups mutable state and tools for segment writing.
    private struct WritingContext {
        var writer = TSPacketWriter()
        var output = Data()
        let pesPacketizer = PESPacketizer()
        let annexBConverter = AnnexBConverter()
        let adtsConverter = ADTSConverter()
        let config: TSCodecConfig
        var isFirstVideo = true
    }
}

// MARK: - PSI Tables

extension TSSegmentBuilder {

    private func writePSITables(
        _ ctx: inout WritingContext
    ) {
        let gen = ProgramTableGenerator()
        let pat = gen.generatePAT()
        let patPackets = ctx.writer.writePSI(
            pat, pid: TSPacket.PID.pat
        )
        for packet in patPackets {
            ctx.output.append(packet.serialize())
        }

        let streams = buildStreamEntries(
            config: ctx.config
        )
        let pcrPid: UInt16
        if ctx.config.videoStreamType != nil {
            pcrPid = TSPacket.PID.video
        } else {
            pcrPid = TSPacket.PID.audio
        }
        let pmt = gen.generatePMT(
            pcrPid: pcrPid, streams: streams
        )
        let pmtPackets = ctx.writer.writePSI(
            pmt, pid: TSPacket.PID.pmt
        )
        for packet in pmtPackets {
            ctx.output.append(packet.serialize())
        }
    }

    private func buildStreamEntries(
        config: TSCodecConfig
    ) -> [ProgramTableGenerator.StreamEntry] {
        var streams: [ProgramTableGenerator.StreamEntry] = []
        if let videoType = config.videoStreamType {
            streams.append(
                ProgramTableGenerator.StreamEntry(
                    streamType: videoType,
                    pid: TSPacket.PID.video
                )
            )
        }
        if let audioType = config.audioStreamType {
            streams.append(
                ProgramTableGenerator.StreamEntry(
                    streamType: audioType,
                    pid: TSPacket.PID.audio
                )
            )
        }
        return streams
    }
}

// MARK: - Sample Merging

extension TSSegmentBuilder {

    private enum MergedSample {
        case video(SampleData)
        case audio(SampleData)
    }

    private func mergeSamples(
        videoSamples: [SampleData],
        audioSamples: [SampleData]?
    ) -> [MergedSample] {
        guard let audioSamples, !audioSamples.isEmpty else {
            return videoSamples.map { .video($0) }
        }
        var merged: [MergedSample] = []
        merged.reserveCapacity(
            videoSamples.count + audioSamples.count
        )
        var vi = 0
        var ai = 0
        while vi < videoSamples.count, ai < audioSamples.count {
            if videoSamples[vi].pts <= audioSamples[ai].pts {
                merged.append(.video(videoSamples[vi]))
                vi += 1
            } else {
                merged.append(.audio(audioSamples[ai]))
                ai += 1
            }
        }
        while vi < videoSamples.count {
            merged.append(.video(videoSamples[vi]))
            vi += 1
        }
        while ai < audioSamples.count {
            merged.append(.audio(audioSamples[ai]))
            ai += 1
        }
        return merged
    }
}

// MARK: - Video Sample Writing

extension TSSegmentBuilder {

    private func writeVideoSample(
        _ sample: SampleData,
        ctx: inout WritingContext
    ) {
        let annexBData: Data
        if sample.isSync,
            let sps = ctx.config.sps,
            let pps = ctx.config.pps
        {
            annexBData =
                ctx.annexBConverter.buildKeyframeAccessUnit(
                    sampleData: sample.data,
                    sps: sps, pps: pps
                )
        } else {
            annexBData = ctx.annexBConverter.convertToAnnexB(
                sample.data
            )
        }

        let dts = sample.dts != sample.pts ? sample.dts : nil
        let pesData = ctx.pesPacketizer.packetize(
            videoData: annexBData, pts: sample.pts, dts: dts
        )

        let pcr: UInt64? =
            ctx.isFirstVideo ? sample.pts * 300 : nil
        let packets = ctx.writer.writePES(
            pesData,
            pid: TSPacket.PID.video,
            isKeyframe: sample.isSync,
            pcr: pcr
        )
        for packet in packets {
            ctx.output.append(packet.serialize())
        }
        ctx.isFirstVideo = false
    }
}

// MARK: - Audio Sample Writing

extension TSSegmentBuilder {

    private func writeAudioSample(
        _ sample: SampleData,
        ctx: inout WritingContext
    ) {
        writeAudioSampleCore(
            sample, pcr: nil, ctx: &ctx
        )
    }

    private func writeAudioSampleCore(
        _ sample: SampleData,
        pcr: UInt64?,
        ctx: inout WritingContext
    ) {
        guard let aacConfig = ctx.config.aacConfig else {
            return
        }
        let adtsFrame = ctx.adtsConverter.wrapWithADTS(
            frame: sample.data, config: aacConfig
        )
        let pesData = ctx.pesPacketizer.packetize(
            audioData: adtsFrame, pts: sample.pts
        )
        let packets = ctx.writer.writePES(
            pesData,
            pid: TSPacket.PID.audio,
            pcr: pcr
        )
        for packet in packets {
            ctx.output.append(packet.serialize())
        }
    }
}
