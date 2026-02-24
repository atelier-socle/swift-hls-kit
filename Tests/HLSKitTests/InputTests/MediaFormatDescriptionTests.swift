// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MediaFormatDescription")
struct MediaFormatDescriptionTests {

    // MARK: - VideoCodec

    @Test("VideoCodec: all cases")
    func videoCodecAllCases() {
        let cases = VideoCodec.allCases
        #expect(cases.count == 4)
        #expect(cases.contains(.h264))
        #expect(cases.contains(.h265))
        #expect(cases.contains(.av1))
        #expect(cases.contains(.vp9))
    }

    @Test("VideoCodec: raw values")
    func videoCodecRawValues() {
        #expect(VideoCodec.h264.rawValue == "h264")
        #expect(VideoCodec.h265.rawValue == "h265")
        #expect(VideoCodec.av1.rawValue == "av1")
        #expect(VideoCodec.vp9.rawValue == "vp9")
    }

    @Test("VideoCodec: Codable round-trip")
    func videoCodecCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for codec in VideoCodec.allCases {
            let data = try encoder.encode(codec)
            let decoded = try decoder.decode(VideoCodec.self, from: data)
            #expect(decoded == codec)
        }
    }

    // MARK: - VideoFormatInfo

    @Test("VideoFormatInfo: basic initialization")
    func videoFormatInfoBasicInit() {
        let info = VideoFormatInfo(
            codec: .h264,
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )
        #expect(info.codec == .h264)
        #expect(info.width == 1920)
        #expect(info.height == 1080)
        #expect(info.frameRate == 30.0)
        #expect(info.bitDepth == 8)
        #expect(info.colorSpace == nil)
    }

    @Test("VideoFormatInfo: full initialization with HDR")
    func videoFormatInfoFullInit() {
        let info = VideoFormatInfo(
            codec: .h265,
            width: 3840,
            height: 2160,
            frameRate: 60.0,
            bitDepth: 10,
            colorSpace: .hdr10
        )
        #expect(info.codec == .h265)
        #expect(info.width == 3840)
        #expect(info.height == 2160)
        #expect(info.frameRate == 60.0)
        #expect(info.bitDepth == 10)
        #expect(info.colorSpace == .hdr10)
    }

    @Test("VideoFormatInfo: resolution computed property")
    func videoFormatInfoResolution() {
        let info = VideoFormatInfo(
            codec: .h264,
            width: 1280,
            height: 720,
            frameRate: 30.0
        )
        let resolution = info.resolution
        #expect(resolution.width == 1280)
        #expect(resolution.height == 720)
    }

    @Test("VideoFormatInfo: Equatable conformance")
    func videoFormatInfoEquatable() {
        let info1 = VideoFormatInfo(codec: .h264, width: 1920, height: 1080, frameRate: 30.0)
        let info2 = VideoFormatInfo(codec: .h264, width: 1920, height: 1080, frameRate: 30.0)
        let info3 = VideoFormatInfo(codec: .h265, width: 1920, height: 1080, frameRate: 30.0)
        #expect(info1 == info2)
        #expect(info1 != info3)
    }

    // MARK: - VideoColorSpace

    @Test("VideoColorSpace: SDR preset")
    func videoColorSpaceSDR() {
        let sdr = VideoColorSpace.sdr
        #expect(sdr.primaries == .bt709)
        #expect(sdr.transfer == .bt709)
        #expect(sdr.matrix == .bt709)
    }

    @Test("VideoColorSpace: HDR10 preset")
    func videoColorSpaceHDR10() {
        let hdr10 = VideoColorSpace.hdr10
        #expect(hdr10.primaries == .bt2020)
        #expect(hdr10.transfer == .pq)
        #expect(hdr10.matrix == .bt2020NonConstant)
    }

    @Test("VideoColorSpace: HLG preset")
    func videoColorSpaceHLG() {
        let hlg = VideoColorSpace.hlg
        #expect(hlg.primaries == .bt2020)
        #expect(hlg.transfer == .hlg)
        #expect(hlg.matrix == .bt2020NonConstant)
    }

    @Test("VideoColorSpace: custom initialization")
    func videoColorSpaceCustom() {
        let custom = VideoColorSpace(
            primaries: .displayP3,
            transfer: .linear,
            matrix: .bt709
        )
        #expect(custom.primaries == .displayP3)
        #expect(custom.transfer == .linear)
        #expect(custom.matrix == .bt709)
    }

    @Test("VideoColorSpace: ColorPrimaries raw values")
    func colorPrimariesRawValues() {
        #expect(VideoColorSpace.ColorPrimaries.bt709.rawValue == "bt709")
        #expect(VideoColorSpace.ColorPrimaries.bt2020.rawValue == "bt2020")
        #expect(VideoColorSpace.ColorPrimaries.displayP3.rawValue == "displayP3")
    }

    @Test("VideoColorSpace: TransferCharacteristics raw values")
    func transferCharacteristicsRawValues() {
        #expect(VideoColorSpace.TransferCharacteristics.bt709.rawValue == "bt709")
        #expect(VideoColorSpace.TransferCharacteristics.pq.rawValue == "pq")
        #expect(VideoColorSpace.TransferCharacteristics.hlg.rawValue == "hlg")
        #expect(VideoColorSpace.TransferCharacteristics.linear.rawValue == "linear")
    }

    @Test("VideoColorSpace: MatrixCoefficients raw values")
    func matrixCoefficientsRawValues() {
        #expect(VideoColorSpace.MatrixCoefficients.bt709.rawValue == "bt709")
        #expect(VideoColorSpace.MatrixCoefficients.bt2020NonConstant.rawValue == "bt2020NonConstant")
        #expect(VideoColorSpace.MatrixCoefficients.bt2020Constant.rawValue == "bt2020Constant")
    }

    // MARK: - MediaFormatDescription

    @Test("MediaFormatDescription: audio only")
    func mediaFormatDescriptionAudioOnly() {
        let audioFormat = AudioFormat.aac()
        let desc = MediaFormatDescription(audioFormat: audioFormat, videoFormat: nil)
        #expect(desc.audioFormat != nil)
        #expect(desc.videoFormat == nil)
    }

    @Test("MediaFormatDescription: video only")
    func mediaFormatDescriptionVideoOnly() {
        let videoFormat = VideoFormatInfo(codec: .h264, width: 1920, height: 1080, frameRate: 30.0)
        let desc = MediaFormatDescription(audioFormat: nil, videoFormat: videoFormat)
        #expect(desc.audioFormat == nil)
        #expect(desc.videoFormat != nil)
    }

    @Test("MediaFormatDescription: audio and video")
    func mediaFormatDescriptionBoth() {
        let audioFormat = AudioFormat.aac()
        let videoFormat = VideoFormatInfo(codec: .h264, width: 1920, height: 1080, frameRate: 30.0)
        let desc = MediaFormatDescription(audioFormat: audioFormat, videoFormat: videoFormat)
        #expect(desc.audioFormat != nil)
        #expect(desc.videoFormat != nil)
    }

    @Test("MediaFormatDescription: Sendable conformance")
    func mediaFormatDescriptionSendable() async {
        let desc = MediaFormatDescription(
            audioFormat: AudioFormat.aac(),
            videoFormat: VideoFormatInfo(codec: .h264, width: 1920, height: 1080, frameRate: 30.0)
        )
        await Task {
            #expect(desc.audioFormat?.codec == .aac)
        }.value
    }
}
