// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("VideoRange")
struct VideoRangeTests {

    // MARK: - Cases

    @Test("VideoRange: all cases")
    func videoRangeAllCases() {
        let cases = VideoRange.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.sdr))
        #expect(cases.contains(.pq))
        #expect(cases.contains(.hlg))
    }

    @Test("VideoRange: raw values match HLS spec")
    func videoRangeRawValues() {
        #expect(VideoRange.sdr.rawValue == "SDR")
        #expect(VideoRange.pq.rawValue == "PQ")
        #expect(VideoRange.hlg.rawValue == "HLG")
    }

    // MARK: - Parsing

    @Test("VideoRange: parse SDR")
    func parseSDR() {
        let range = VideoRange(rawValue: "SDR")
        #expect(range == .sdr)
    }

    @Test("VideoRange: parse PQ")
    func parsePQ() {
        let range = VideoRange(rawValue: "PQ")
        #expect(range == .pq)
    }

    @Test("VideoRange: parse HLG")
    func parseHLG() {
        let range = VideoRange(rawValue: "HLG")
        #expect(range == .hlg)
    }

    @Test("VideoRange: parse invalid returns nil")
    func parseInvalid() {
        let range = VideoRange(rawValue: "INVALID")
        #expect(range == nil)
    }

    @Test("VideoRange: case sensitive")
    func caseSensitive() {
        #expect(VideoRange(rawValue: "sdr") == nil)
        #expect(VideoRange(rawValue: "Sdr") == nil)
        #expect(VideoRange(rawValue: "pq") == nil)
    }

    // MARK: - Codable

    @Test("VideoRange: Codable round-trip")
    func codableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for range in VideoRange.allCases {
            let data = try encoder.encode(range)
            let decoded = try decoder.decode(VideoRange.self, from: data)
            #expect(decoded == range)
        }
    }

    @Test("VideoRange: JSON encoding produces raw value")
    func jsonEncoding() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(VideoRange.pq)
        let string = String(data: data, encoding: .utf8)
        #expect(string == "\"PQ\"")
    }

    // MARK: - Variant Integration

    @Test("Variant: videoRange property exists")
    func variantVideoRangeProperty() {
        let variant = Variant(
            bandwidth: 2_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "hdr/playlist.m3u8",
            videoRange: .pq
        )
        #expect(variant.videoRange == .pq)
    }

    @Test("Variant: videoRange nil by default")
    func variantVideoRangeNilDefault() {
        let variant = Variant(
            bandwidth: 2_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "sdr/playlist.m3u8"
        )
        #expect(variant.videoRange == nil)
    }

    // MARK: - Conformances

    @Test("VideoRange: Hashable")
    func hashable() {
        var set = Set<VideoRange>()
        set.insert(.sdr)
        set.insert(.pq)
        set.insert(.hlg)
        set.insert(.sdr)
        #expect(set.count == 3)
    }

    @Test("VideoRange: Sendable")
    func sendable() async {
        let range: VideoRange = .pq
        await Task {
            #expect(range == .pq)
        }.value
    }
}
