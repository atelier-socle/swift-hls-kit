// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Track Config for Builders

struct AVTrackConfig {
    let samples: Int
    let sampleDelta: UInt32
    let timescale: UInt32
    let duration: UInt32
    let sampleSize: UInt32
    let stcoOffset: UInt32
}

struct VideoMoovConfig {
    let videoSamples: Int
    let sampleDelta: UInt32
    let timescale: UInt32
    let duration: UInt32
    let sizes: [UInt32]
    let syncSamples: [UInt32]
    let stcoOffset: UInt32
}

// MARK: - MP4 With Actual mdat Data

extension MP4TestDataBuilder {

    /// Build a complete MP4 with actual mdat sample bytes.
    static func segmentableMP4WithData(
        videoSamples: Int = 90,
        keyframeInterval: Int = 30,
        sampleDelta: UInt32 = 3000,
        timescale: UInt32 = 90000,
        sampleSize: UInt32 = 100
    ) -> Data {
        let duration = UInt32(videoSamples) * sampleDelta
        let sizes = [UInt32](
            repeating: sampleSize, count: videoSamples
        )
        let syncSamples = buildSyncSamples(
            count: videoSamples, interval: keyframeInterval
        )
        let mdatPayload = buildSamplePayload(
            sampleCount: videoSamples,
            sampleSize: Int(sampleSize),
            byteOffset: 0
        )
        let ftypData = ftyp()
        let config = VideoMoovConfig(
            videoSamples: videoSamples,
            sampleDelta: sampleDelta,
            timescale: timescale,
            duration: duration,
            sizes: sizes,
            syncSamples: syncSamples,
            stcoOffset: 0
        )
        let moovPlaceholder = buildMoovForData(config: config)
        let mdatHeaderSize = 8
        let stcoOffset = UInt32(
            ftypData.count + moovPlaceholder.count + mdatHeaderSize
        )
        let finalConfig = VideoMoovConfig(
            videoSamples: videoSamples,
            sampleDelta: sampleDelta,
            timescale: timescale,
            duration: duration,
            sizes: sizes,
            syncSamples: syncSamples,
            stcoOffset: stcoOffset
        )
        let moov = buildMoovForData(config: finalConfig)
        let mdatBox = box(type: "mdat", payload: mdatPayload)
        var data = Data()
        data.append(ftypData)
        data.append(moov)
        data.append(mdatBox)
        return data
    }

    private static func buildMoovForData(
        config: VideoMoovConfig
    ) -> Data {
        let stblBox = stbl(
            codec: "avc1",
            sttsEntries: [
                (UInt32(config.videoSamples), config.sampleDelta)
            ],
            stszSizes: config.sizes,
            stcoOffsets: [config.stcoOffset],
            stscEntries: [
                StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(config.videoSamples),
                    descIndex: 1
                )
            ],
            stssSyncSamples: config.syncSamples
        )
        let minfBox = containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = containerBox(
            type: "mdia",
            children: [
                mdhd(
                    timescale: config.timescale,
                    duration: config.duration
                ),
                hdlr(handlerType: "vide"),
                minfBox
            ]
        )
        let trakBox = containerBox(
            type: "trak",
            children: [
                tkhd(
                    trackId: 1, duration: config.duration,
                    width: 1920, height: 1080
                ),
                mdiaBox
            ]
        )
        return containerBox(
            type: "moov",
            children: [
                mvhd(
                    timescale: config.timescale,
                    duration: config.duration
                ),
                trakBox
            ]
        )
    }

    static func buildSyncSamples(
        count: Int, interval: Int
    ) -> [UInt32] {
        var result: [UInt32] = []
        for i in stride(from: 0, to: count, by: interval) {
            result.append(UInt32(i + 1))
        }
        return result
    }

    static func buildSamplePayload(
        sampleCount: Int, sampleSize: Int, byteOffset: Int
    ) -> Data {
        var payload = Data()
        for i in 0..<sampleCount {
            let byte = UInt8((i + byteOffset) & 0xFF)
            payload.append(
                Data(repeating: byte, count: sampleSize)
            )
        }
        return payload
    }
}

// MARK: - AV MP4 With mdat Data

extension MP4TestDataBuilder {

    /// Build an MP4 with video + audio tracks and mdat data.
    static func avMP4WithData(
        videoSamples: Int = 90,
        keyframeInterval: Int = 30,
        videoSampleDelta: UInt32 = 3000,
        videoTimescale: UInt32 = 90000,
        videoSampleSize: UInt32 = 100,
        audioSamples: Int = 430,
        audioSampleDelta: UInt32 = 1024,
        audioTimescale: UInt32 = 44100,
        audioSampleSize: UInt32 = 50
    ) -> Data {
        let vidDuration = UInt32(videoSamples) * videoSampleDelta
        let audDuration = UInt32(audioSamples) * audioSampleDelta
        let mdatPayload = buildAVMdatPayload(
            videoSamples: videoSamples,
            videoSampleSize: Int(videoSampleSize),
            audioSamples: audioSamples,
            audioSampleSize: Int(audioSampleSize)
        )
        let audioStart = videoSamples * Int(videoSampleSize)
        let ftypData = ftyp()
        let videoConfig = AVTrackConfig(
            samples: videoSamples,
            sampleDelta: videoSampleDelta,
            timescale: videoTimescale,
            duration: vidDuration,
            sampleSize: videoSampleSize,
            stcoOffset: 0
        )
        let audioConfig = AVTrackConfig(
            samples: audioSamples,
            sampleDelta: audioSampleDelta,
            timescale: audioTimescale,
            duration: audDuration,
            sampleSize: audioSampleSize,
            stcoOffset: 0
        )
        let moov0 = buildAVMoov(
            video: videoConfig, audio: audioConfig,
            keyframeInterval: keyframeInterval
        )
        let mdatHeaderSize = 8
        let base = UInt32(
            ftypData.count + moov0.count + mdatHeaderSize
        )
        let finalVideo = AVTrackConfig(
            samples: videoSamples,
            sampleDelta: videoSampleDelta,
            timescale: videoTimescale,
            duration: vidDuration,
            sampleSize: videoSampleSize,
            stcoOffset: base
        )
        let finalAudio = AVTrackConfig(
            samples: audioSamples,
            sampleDelta: audioSampleDelta,
            timescale: audioTimescale,
            duration: audDuration,
            sampleSize: audioSampleSize,
            stcoOffset: base + UInt32(audioStart)
        )
        let moov = buildAVMoov(
            video: finalVideo, audio: finalAudio,
            keyframeInterval: keyframeInterval
        )
        let mdatBox = box(type: "mdat", payload: mdatPayload)
        var data = Data()
        data.append(ftypData)
        data.append(moov)
        data.append(mdatBox)
        return data
    }

    private static func buildAVMdatPayload(
        videoSamples: Int, videoSampleSize: Int,
        audioSamples: Int, audioSampleSize: Int
    ) -> Data {
        var payload = buildSamplePayload(
            sampleCount: videoSamples,
            sampleSize: videoSampleSize,
            byteOffset: 0
        )
        payload.append(
            buildSamplePayload(
                sampleCount: audioSamples,
                sampleSize: audioSampleSize,
                byteOffset: 0x80
            )
        )
        return payload
    }

    private static func buildAVMoov(
        video: AVTrackConfig,
        audio: AVTrackConfig,
        keyframeInterval: Int
    ) -> Data {
        let videoTrak = buildVideoTrak(
            config: video,
            keyframeInterval: keyframeInterval
        )
        let audioTrak = buildAudioTrak(config: audio)
        return containerBox(
            type: "moov",
            children: [
                mvhd(
                    timescale: video.timescale,
                    duration: video.duration
                ),
                videoTrak,
                audioTrak
            ]
        )
    }

    private static func buildVideoTrak(
        config: AVTrackConfig,
        keyframeInterval: Int
    ) -> Data {
        let syncSamples = buildSyncSamples(
            count: config.samples, interval: keyframeInterval
        )
        let videoStbl = stbl(
            codec: "avc1",
            sttsEntries: [
                (UInt32(config.samples), config.sampleDelta)
            ],
            stszSizes: [UInt32](
                repeating: config.sampleSize,
                count: config.samples
            ),
            stcoOffsets: [config.stcoOffset],
            stscEntries: [
                StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(config.samples),
                    descIndex: 1
                )
            ],
            stssSyncSamples: syncSamples
        )
        let videoMinf = containerBox(
            type: "minf", children: [videoStbl]
        )
        let videoMdia = containerBox(
            type: "mdia",
            children: [
                mdhd(
                    timescale: config.timescale,
                    duration: config.duration
                ),
                hdlr(handlerType: "vide"),
                videoMinf
            ]
        )
        return containerBox(
            type: "trak",
            children: [
                tkhd(
                    trackId: 1, duration: config.duration,
                    width: 1920, height: 1080
                ),
                videoMdia
            ]
        )
    }

    private static func buildAudioTrak(
        config: AVTrackConfig
    ) -> Data {
        let audioStbl = stbl(
            codec: "mp4a",
            sttsEntries: [
                (UInt32(config.samples), config.sampleDelta)
            ],
            stszSizes: [UInt32](
                repeating: config.sampleSize,
                count: config.samples
            ),
            stcoOffsets: [config.stcoOffset],
            stscEntries: [
                StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(config.samples),
                    descIndex: 1
                )
            ]
        )
        let audioMinf = containerBox(
            type: "minf", children: [audioStbl]
        )
        let audioMdia = containerBox(
            type: "mdia",
            children: [
                mdhd(
                    timescale: config.timescale,
                    duration: config.duration
                ),
                hdlr(handlerType: "soun"),
                audioMinf
            ]
        )
        return containerBox(
            type: "trak",
            children: [
                tkhd(trackId: 2, duration: config.duration),
                audioMdia
            ]
        )
    }
}
