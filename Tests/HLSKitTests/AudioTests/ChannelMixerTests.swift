// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ChannelMixer", .timeLimit(.minutes(1)))
struct ChannelMixerTests {

    let mixer = ChannelMixer()

    // MARK: - Helpers

    private func makeFloat32(_ values: [Float]) -> Data {
        var data = Data(capacity: values.count * 4)
        for v in values {
            withUnsafeBytes(of: v) { data.append(contentsOf: $0) }
        }
        return data
    }

    private func readFloat32(_ data: Data) -> [Float] {
        data.withUnsafeBytes { raw in
            Array(raw.bindMemory(to: Float.self))
        }
    }

    // MARK: - Mono → Stereo

    @Test("monoToStereo duplicate: each sample appears twice")
    func monoToStereoDuplicate() {
        let data = makeFloat32([0.5, -0.3, 0.8])
        let stereo = readFloat32(mixer.monoToStereo(data, mode: .duplicate))
        #expect(stereo.count == 6)
        #expect(stereo[0] == 0.5)
        #expect(stereo[1] == 0.5)
        #expect(stereo[2] == -0.3)
        #expect(stereo[3] == -0.3)
    }

    @Test("monoToStereo center: each sample × 0.707")
    func monoToStereoCenter() {
        let data = makeFloat32([1.0])
        let stereo = readFloat32(mixer.monoToStereo(data, mode: .center))
        let expected = Float(1.0 / sqrt(2.0))
        #expect(abs(stereo[0] - expected) < 1e-5)
        #expect(abs(stereo[1] - expected) < 1e-5)
    }

    // MARK: - Stereo → Mono

    @Test("stereoToMono average: (L+R)/2")
    func stereoToMonoAverage() {
        let data = makeFloat32([0.4, 0.6, -0.2, 0.8])
        let mono = readFloat32(mixer.stereoToMono(data, mode: .average))
        #expect(mono.count == 2)
        #expect(abs(mono[0] - 0.5) < 1e-5)
        #expect(abs(mono[1] - 0.3) < 1e-5)
    }

    @Test("stereoToMono left: L only")
    func stereoToMonoLeft() {
        let data = makeFloat32([0.4, 0.6])
        let mono = readFloat32(mixer.stereoToMono(data, mode: .left))
        #expect(abs(mono[0] - 0.4) < 1e-5)
    }

    @Test("stereoToMono right: R only")
    func stereoToMonoRight() {
        let data = makeFloat32([0.4, 0.6])
        let mono = readFloat32(mixer.stereoToMono(data, mode: .right))
        #expect(abs(mono[0] - 0.6) < 1e-5)
    }

    // MARK: - Round-Trip

    @Test("mono→stereo→mono round-trip: approximately equal")
    func monoStereoRoundTrip() {
        let original = makeFloat32([0.5, -0.3, 0.7])
        let stereo = mixer.monoToStereo(original, mode: .duplicate)
        let back = readFloat32(mixer.stereoToMono(stereo, mode: .average))
        let originals = readFloat32(original)
        for i in 0..<originals.count {
            #expect(abs(back[i] - originals[i]) < 1e-5)
        }
    }

    // MARK: - 5.1 Surround

    @Test("surroundToStereo: L_out = L + 0.707*C + 0.707*Ls")
    func surroundToStereoLeft() {
        // L=0.5, R=0, C=0.3, LFE=0, Ls=0.2, Rs=0
        let data = makeFloat32([0.5, 0.0, 0.3, 0.0, 0.2, 0.0])
        let stereo = readFloat32(mixer.surroundToStereo(data))
        let coeff = Float(1.0 / sqrt(2.0))
        let expected = 0.5 + coeff * 0.3 + coeff * 0.2
        #expect(abs(stereo[0] - expected) < 1e-4)
    }

    @Test("surroundToStereo: R_out = R + 0.707*C + 0.707*Rs")
    func surroundToStereoRight() {
        // L=0, R=0.6, C=0.4, LFE=0, Ls=0, Rs=0.1
        let data = makeFloat32([0.0, 0.6, 0.4, 0.0, 0.0, 0.1])
        let stereo = readFloat32(mixer.surroundToStereo(data))
        let coeff = Float(1.0 / sqrt(2.0))
        let expected = 0.6 + coeff * 0.4 + coeff * 0.1
        #expect(abs(stereo[1] - expected) < 1e-4)
    }

    @Test("surroundToStereo with LFE")
    func surroundToStereoWithLFE() {
        // L=0, R=0, C=0, LFE=0.8, Ls=0, Rs=0
        let data = makeFloat32([0.0, 0.0, 0.0, 0.8, 0.0, 0.0])
        let stereo = readFloat32(
            mixer.surroundToStereo(data, includeLFE: true, lfeGain: 0.5)
        )
        #expect(abs(stereo[0] - 0.4) < 1e-5)
        #expect(abs(stereo[1] - 0.4) < 1e-5)
    }

    @Test("surroundToStereo without LFE: LFE discarded")
    func surroundToStereoNoLFE() {
        // L=0, R=0, C=0, LFE=0.8, Ls=0, Rs=0
        let data = makeFloat32([0.0, 0.0, 0.0, 0.8, 0.0, 0.0])
        let stereo = readFloat32(mixer.surroundToStereo(data))
        #expect(abs(stereo[0]) < 1e-5)
        #expect(abs(stereo[1]) < 1e-5)
    }

    // MARK: - 7.1 Surround

    @Test("surround71ToStereo: correct downmix")
    func surround71ToStereo() {
        // L=0.5, R=0.3, C=0, LFE=0, Ls=0, Rs=0, Lrs=0.2, Rrs=0.1
        let data = makeFloat32([0.5, 0.3, 0.0, 0.0, 0.0, 0.0, 0.2, 0.1])
        let stereo = readFloat32(mixer.surround71ToStereo(data))
        let coeff = Float(1.0 / sqrt(2.0))
        #expect(abs(stereo[0] - (0.5 + coeff * 0.2)) < 1e-4)
        #expect(abs(stereo[1] - (0.3 + coeff * 0.1)) < 1e-4)
    }

    // MARK: - Custom Matrix

    @Test("applyMatrix with identity matrix: output equals input")
    func matrixIdentity() {
        let data = makeFloat32([0.5, -0.3, 0.7, 0.1])
        let identity = ChannelMixer.MixMatrix(gains: [
            [1.0, 0.0],
            [0.0, 1.0]
        ])
        let result = readFloat32(mixer.applyMatrix(data, matrix: identity))
        let original = readFloat32(data)
        for i in 0..<original.count {
            #expect(abs(result[i] - original[i]) < 1e-5)
        }
    }

    @Test("applyMatrix with custom gains")
    func matrixCustomGains() {
        // 2 channels → 1 channel: L*0.8 + R*0.2
        let data = makeFloat32([1.0, 0.0])
        let matrix = ChannelMixer.MixMatrix(gains: [[0.8, 0.2]])
        let result = readFloat32(mixer.applyMatrix(data, matrix: matrix))
        #expect(abs(result[0] - 0.8) < 1e-5)
    }

    // MARK: - MixMatrix

    @Test("MixMatrix validation: correct dimensions")
    func matrixValid() {
        let m = ChannelMixer.MixMatrix(gains: [[0.5, 0.5], [0.5, 0.5]])
        #expect(m.isValid)
        #expect(m.inputChannels == 2)
        #expect(m.outputChannels == 2)
    }

    @Test("MixMatrix validation: mismatched dimensions")
    func matrixInvalid() {
        let m = ChannelMixer.MixMatrix(gains: [[0.5, 0.5], [0.5]])
        #expect(!m.isValid)
    }

    @Test("MixMatrix validation: empty")
    func matrixEmpty() {
        let m = ChannelMixer.MixMatrix(gains: [])
        #expect(!m.isValid)
    }

    // MARK: - Standard Matrices

    @Test("stereoToMonoMatrix preset average")
    func stereoToMonoMatrixPreset() {
        let m = ChannelMixer.stereoToMonoMatrix()
        #expect(m.inputChannels == 2)
        #expect(m.outputChannels == 1)
        #expect(m.gains == [[0.5, 0.5]])
    }

    @Test("monoToStereoMatrix preset")
    func monoToStereoMatrixPreset() {
        let m = ChannelMixer.monoToStereoMatrix()
        #expect(m.inputChannels == 1)
        #expect(m.outputChannels == 2)
    }

    @Test("surround51ToStereoMatrix preset")
    func surround51MatrixPreset() {
        let m = ChannelMixer.surround51ToStereoMatrix()
        #expect(m.inputChannels == 6)
        #expect(m.outputChannels == 2)
        #expect(m.isValid)
    }

    // MARK: - Clamping

    @Test("Clamping: mixed values > 1.0 clamped")
    func clampingAfterMix() {
        // All channels at 1.0 → after downmix with 0.707 coefficients, sum > 1.0
        let data = makeFloat32([1.0, 1.0, 1.0, 0.0, 1.0, 1.0])
        let stereo = readFloat32(mixer.surroundToStereo(data))
        #expect(stereo[0] <= 1.0)
        #expect(stereo[0] >= -1.0)
    }

    // MARK: - Utilities

    @Test("outputDataSize calculation")
    func outputDataSizeCalc() {
        let size = mixer.outputDataSize(
            inputSize: 100 * 2 * 4, inputChannels: 2, outputChannels: 1
        )
        #expect(size == 100 * 1 * 4)
    }

    @Test("validateDataSize: correct and incorrect sizes")
    func validateDataSizeCheck() {
        let good = makeFloat32([0.5, -0.5])
        #expect(mixer.validateDataSize(good, channels: 2, sampleFormat: .float32))
        let bad = Data([0x00, 0x01, 0x02])
        #expect(!mixer.validateDataSize(bad, channels: 2, sampleFormat: .float32))
    }
}
