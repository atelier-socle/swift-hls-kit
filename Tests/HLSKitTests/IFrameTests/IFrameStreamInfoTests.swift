// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("IFrameStreamInfo", .timeLimit(.minutes(1)))
struct IFrameStreamInfoTests {

    // MARK: - Render

    @Test("Render with all attributes")
    func renderAllAttributes() {
        let info = IFrameStreamInfo(
            bandwidth: 86000,
            uri: "iframe-low.m3u8",
            averageBandwidth: 80000,
            codecs: "avc1.640028",
            resolution: .init(width: 640, height: 360),
            hdcpLevel: "NONE",
            videoRange: "SDR"
        )
        let tag = info.render()
        #expect(tag.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:"))
        #expect(tag.contains("BANDWIDTH=86000"))
        #expect(tag.contains("AVERAGE-BANDWIDTH=80000"))
        #expect(tag.contains("CODECS=\"avc1.640028\""))
        #expect(tag.contains("RESOLUTION=640x360"))
        #expect(tag.contains("HDCP-LEVEL=NONE"))
        #expect(tag.contains("VIDEO-RANGE=SDR"))
        #expect(tag.contains("URI=\"iframe-low.m3u8\""))
    }

    @Test("Render with minimal attributes")
    func renderMinimalAttributes() {
        let info = IFrameStreamInfo(bandwidth: 50000, uri: "iframe.m3u8")
        let tag = info.render()
        #expect(tag.contains("BANDWIDTH=50000"))
        #expect(tag.contains("URI=\"iframe.m3u8\""))
        #expect(!tag.contains("AVERAGE-BANDWIDTH"))
        #expect(!tag.contains("CODECS"))
        #expect(!tag.contains("RESOLUTION"))
        #expect(!tag.contains("HDCP-LEVEL"))
        #expect(!tag.contains("VIDEO-RANGE"))
    }

    // MARK: - Resolution

    @Test("Resolution stores width and height")
    func resolutionProperties() {
        let res = IFrameStreamInfo.Resolution(width: 1920, height: 1080)
        #expect(res.width == 1920)
        #expect(res.height == 1080)
    }

    @Test("Resolution Equatable")
    func resolutionEquatable() {
        let a = IFrameStreamInfo.Resolution(width: 640, height: 360)
        let b = IFrameStreamInfo.Resolution(width: 640, height: 360)
        let c = IFrameStreamInfo.Resolution(width: 1280, height: 720)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - Equatable

    @Test("IFrameStreamInfo Equatable")
    func equatable() {
        let a = IFrameStreamInfo(
            bandwidth: 86000, uri: "iframe.m3u8", codecs: "avc1.640028"
        )
        let b = IFrameStreamInfo(
            bandwidth: 86000, uri: "iframe.m3u8", codecs: "avc1.640028"
        )
        let c = IFrameStreamInfo(
            bandwidth: 100000, uri: "iframe-hi.m3u8"
        )
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - URI Position

    @Test("URI is last attribute in rendered tag")
    func uriIsLastAttribute() {
        let info = IFrameStreamInfo(
            bandwidth: 50000, uri: "iframe.m3u8", codecs: "avc1.42e01e"
        )
        let tag = info.render()
        #expect(tag.hasSuffix("URI=\"iframe.m3u8\""))
    }

    // MARK: - Multiple Variants

    @Test("Multiple variants render independently")
    func multipleVariants() {
        let low = IFrameStreamInfo(
            bandwidth: 86000, uri: "iframe-low.m3u8",
            resolution: .init(width: 640, height: 360)
        )
        let high = IFrameStreamInfo(
            bandwidth: 300000, uri: "iframe-high.m3u8",
            resolution: .init(width: 1920, height: 1080)
        )
        let tagLow = low.render()
        let tagHigh = high.render()
        #expect(tagLow.contains("BANDWIDTH=86000"))
        #expect(tagHigh.contains("BANDWIDTH=300000"))
        #expect(tagLow.contains("RESOLUTION=640x360"))
        #expect(tagHigh.contains("RESOLUTION=1920x1080"))
    }
}
