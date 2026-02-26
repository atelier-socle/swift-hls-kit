// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - MultiChannelLayout

@Suite("MultiChannelLayout — Channel Counts")
struct MultiChannelLayoutCountTests {

    @Test("Mono has 1 channel")
    func monoCount() {
        #expect(MultiChannelLayout.mono.channelCount == 1)
    }

    @Test("Stereo has 2 channels")
    func stereoCount() {
        #expect(MultiChannelLayout.stereo.channelCount == 2)
    }

    @Test("3.0 surround has 3 channels")
    func surround30Count() {
        #expect(MultiChannelLayout.surround3_0.channelCount == 3)
    }

    @Test("4.0 surround has 4 channels")
    func surround40Count() {
        #expect(MultiChannelLayout.surround4_0.channelCount == 4)
    }

    @Test("5.0 surround has 5 channels")
    func surround50Count() {
        #expect(MultiChannelLayout.surround5_0.channelCount == 5)
    }

    @Test("5.1 surround has 6 channels")
    func surround51Count() {
        #expect(MultiChannelLayout.surround5_1.channelCount == 6)
    }

    @Test("6.1 surround has 7 channels")
    func surround61Count() {
        #expect(MultiChannelLayout.surround6_1.channelCount == 7)
    }

    @Test("7.1 surround has 8 channels")
    func surround71Count() {
        #expect(MultiChannelLayout.surround7_1.channelCount == 8)
    }

    @Test("Atmos 7.1.4 has 12 channels")
    func atmos714Count() {
        #expect(MultiChannelLayout.atmos7_1_4.channelCount == 12)
    }
}

@Suite("MultiChannelLayout — HLS Attributes")
struct MultiChannelLayoutHLSTests {

    @Test("Mono HLS channels is 1")
    func monoHLS() {
        #expect(MultiChannelLayout.mono.hlsChannelsAttribute == "1")
    }

    @Test("Stereo HLS channels is 2")
    func stereoHLS() {
        #expect(MultiChannelLayout.stereo.hlsChannelsAttribute == "2")
    }

    @Test("5.1 HLS channels is 6")
    func surround51HLS() {
        #expect(MultiChannelLayout.surround5_1.hlsChannelsAttribute == "6")
    }

    @Test("7.1 HLS channels is 8")
    func surround71HLS() {
        #expect(MultiChannelLayout.surround7_1.hlsChannelsAttribute == "8")
    }

    @Test("Atmos 7.1.4 HLS channels is 16/JOC")
    func atmos714HLS() {
        #expect(MultiChannelLayout.atmos7_1_4.hlsChannelsAttribute == "16/JOC")
    }

    @Test("3.0 HLS channels is 3")
    func surround30HLS() {
        #expect(MultiChannelLayout.surround3_0.hlsChannelsAttribute == "3")
    }

    @Test("4.0 HLS channels is 4")
    func surround40HLS() {
        #expect(MultiChannelLayout.surround4_0.hlsChannelsAttribute == "4")
    }

    @Test("5.0 HLS channels is 5")
    func surround50HLS() {
        #expect(MultiChannelLayout.surround5_0.hlsChannelsAttribute == "5")
    }

    @Test("6.1 HLS channels is 7")
    func surround61HLS() {
        #expect(MultiChannelLayout.surround6_1.hlsChannelsAttribute == "7")
    }
}

@Suite("MultiChannelLayout — Properties")
struct MultiChannelLayoutPropertyTests {

    @Test("Only atmos7_1_4 is object-based")
    func objectBased() {
        #expect(MultiChannelLayout.atmos7_1_4.isObjectBased == true)
        #expect(MultiChannelLayout.surround7_1.isObjectBased == false)
        #expect(MultiChannelLayout.stereo.isObjectBased == false)
    }

    @Test("Surround layouts have isSurround true")
    func isSurround() {
        #expect(MultiChannelLayout.surround5_1.isSurround == true)
        #expect(MultiChannelLayout.surround3_0.isSurround == true)
        #expect(MultiChannelLayout.atmos7_1_4.isSurround == true)
    }

    @Test("Mono and stereo are not surround")
    func notSurround() {
        #expect(MultiChannelLayout.mono.isSurround == false)
        #expect(MultiChannelLayout.stereo.isSurround == false)
    }

    @Test("Channel names for stereo")
    func stereoNames() {
        #expect(MultiChannelLayout.stereo.channelNames == ["L", "R"])
    }

    @Test("Channel names for 5.1")
    func surround51Names() {
        let names = MultiChannelLayout.surround5_1.channelNames
        #expect(names == ["L", "R", "C", "LFE", "Ls", "Rs"])
    }

    @Test("Channel names for 7.1.4 Atmos")
    func atmos714Names() {
        let names = MultiChannelLayout.atmos7_1_4.channelNames
        #expect(names.count == 12)
        #expect(names.contains("Ltf"))
        #expect(names.contains("Rtb"))
    }

    @Test("Channel names for mono")
    func monoNames() {
        #expect(MultiChannelLayout.mono.channelNames == ["C"])
    }

    @Test("Channel names for 7.1")
    func surround71Names() {
        let names = MultiChannelLayout.surround7_1.channelNames
        #expect(names.count == 8)
        #expect(names.contains("Lrs"))
        #expect(names.contains("Rrs"))
    }
}

@Suite("MultiChannelLayout — canEncode")
struct MultiChannelLayoutEncodeTests {

    @Test("7.1 can encode to 5.1 (downmix)")
    func downmix71to51() {
        #expect(
            MultiChannelLayout.surround7_1.canEncode(
                to: .surround5_1
            ) == true)
    }

    @Test("Stereo cannot encode to 5.1 (upmix)")
    func stereoTo51() {
        #expect(
            MultiChannelLayout.stereo.canEncode(
                to: .surround5_1
            ) == false)
    }

    @Test("Atmos can encode to stereo (downmix)")
    func atmosToStereo() {
        #expect(
            MultiChannelLayout.atmos7_1_4.canEncode(
                to: .stereo
            ) == true)
    }

    @Test("Same layout can encode to itself")
    func sameLayout() {
        #expect(
            MultiChannelLayout.surround5_1.canEncode(
                to: .surround5_1
            ) == true)
    }

    @Test("Mono cannot encode to stereo")
    func monoToStereo() {
        #expect(
            MultiChannelLayout.mono.canEncode(
                to: .stereo
            ) == false)
    }
}

@Suite("MultiChannelLayout — Conformances")
struct MultiChannelLayoutConformanceTests {

    @Test("Equatable conformance")
    func equatable() {
        #expect(MultiChannelLayout.surround5_1 == MultiChannelLayout.surround5_1)
        #expect(MultiChannelLayout.stereo != MultiChannelLayout.mono)
    }

    @Test("Hashable conformance")
    func hashable() {
        let set: Set<MultiChannelLayout> = [.mono, .stereo, .surround5_1]
        #expect(set.count == 3)
    }

    @Test("LayoutIdentifier is CaseIterable with 9 cases")
    func caseIterable() {
        #expect(MultiChannelLayout.LayoutIdentifier.allCases.count == 9)
    }

    @Test("Init from identifier")
    func initFromIdentifier() {
        let layout = MultiChannelLayout(identifier: .surround6_1)
        #expect(layout.channelCount == 7)
    }
}
