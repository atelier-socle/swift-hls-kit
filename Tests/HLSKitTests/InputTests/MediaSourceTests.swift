// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MediaSource Protocol")
struct MediaSourceTests {

    // MARK: - MediaSourceType

    @Test("MediaSourceType: all cases")
    func mediaSourceTypeCases() {
        let cases = MediaSourceType.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.audio))
        #expect(cases.contains(.video))
        #expect(cases.contains(.audioVideo))
    }

    @Test("MediaSourceType: raw values")
    func mediaSourceTypeRawValues() {
        #expect(MediaSourceType.audio.rawValue == "audio")
        #expect(MediaSourceType.video.rawValue == "video")
        #expect(MediaSourceType.audioVideo.rawValue == "audioVideo")
    }

    @Test("MediaSourceType: Codable round-trip")
    func mediaSourceTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for type in MediaSourceType.allCases {
            let data = try encoder.encode(type)
            let decoded = try decoder.decode(MediaSourceType.self, from: data)
            #expect(decoded == type)
        }
    }

    @Test("MediaSourceType: audio includes audio")
    func mediaSourceTypeAudioIncludesAudio() {
        #expect(MediaSourceType.audio == .audio)
        #expect(MediaSourceType.audioVideo == .audioVideo)
    }

    @Test("MediaSourceType: video includes video")
    func mediaSourceTypeVideoIncludesVideo() {
        #expect(MediaSourceType.video == .video)
        #expect(MediaSourceType.audioVideo == .audioVideo)
    }

    @Test("MediaSourceType: Hashable conformance")
    func mediaSourceTypeHashable() {
        var set = Set<MediaSourceType>()
        set.insert(.audio)
        set.insert(.video)
        set.insert(.audioVideo)
        #expect(set.count == 3)
    }

    @Test("MediaSourceType: Sendable conformance compiles")
    func mediaSourceTypeSendable() async {
        let type: MediaSourceType = .audioVideo
        await Task {
            #expect(type == .audioVideo)
        }.value
    }
}
