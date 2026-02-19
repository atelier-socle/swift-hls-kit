// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SampleEncryptor")
struct SampleEncryptorTests {

    private let encryptor = SampleEncryptor()
    private let key = Data(repeating: 0xAB, count: 16)
    private let iv = Data(repeating: 0xCD, count: 16)

    // MARK: - Video NAL Type 1 (non-IDR)

    @Test("Encrypt video NAL type 1: body encrypted, header intact")
    func encryptNALType1() throws {
        let data = buildAnnexBData(nalType: 1, bodySize: 100)
        let encrypted = try encryptor.encryptVideoSamples(
            data, key: key, iv: iv
        )
        #expect(encrypted.count == data.count)
        // Start code + NAL header unchanged
        #expect(encrypted[0..<5] == data[0..<5])
        // First 32 bytes of body unchanged
        #expect(encrypted[5..<37] == data[5..<37])
        // Encrypted region differs
        #expect(encrypted[37..<53] != data[37..<53])
    }

    // MARK: - Video NAL Type 5 (IDR)

    @Test("Encrypt video NAL type 5: body encrypted, header intact")
    func encryptNALType5() throws {
        let data = buildAnnexBData(nalType: 5, bodySize: 100)
        let encrypted = try encryptor.encryptVideoSamples(
            data, key: key, iv: iv
        )
        #expect(encrypted.count == data.count)
        #expect(encrypted[0..<5] == data[0..<5])
        #expect(encrypted[5..<37] == data[5..<37])
        #expect(encrypted[37..<53] != data[37..<53])
    }

    // MARK: - Skip Non-Slice NAL Types

    @Test("Skip video NAL types other than 1 and 5")
    func skipNonSliceNAL() throws {
        // SPS = type 7, PPS = type 8, SEI = type 6
        for nalType: UInt8 in [6, 7, 8] {
            let data = buildAnnexBData(
                nalType: nalType, bodySize: 100
            )
            let encrypted = try encryptor.encryptVideoSamples(
                data, key: key, iv: iv
            )
            #expect(encrypted == data)
        }
    }

    // MARK: - Unencrypted Leading Bytes

    @Test("First 32 bytes of NAL body remain unencrypted")
    func first32BytesUnencrypted() throws {
        let data = buildAnnexBData(nalType: 1, bodySize: 200)
        let encrypted = try encryptor.encryptVideoSamples(
            data, key: key, iv: iv
        )
        // 4 bytes start code + 1 byte NAL header + 32 bytes
        let clearEnd = 4 + 1 + 32
        #expect(encrypted[0..<clearEnd] == data[0..<clearEnd])
    }

    // MARK: - Trailing Bytes

    @Test("Trailing bytes (< 16) remain unencrypted")
    func trailingBytesUnencrypted() throws {
        // Body = 32 (skip) + 16 (one block) + 5 (trailing)
        let data = buildAnnexBData(nalType: 1, bodySize: 53)
        let encrypted = try encryptor.encryptVideoSamples(
            data, key: key, iv: iv
        )
        let totalLen = 4 + 1 + 53
        #expect(encrypted.count == totalLen)
        // Trailing 5 bytes unchanged
        let trailStart = totalLen - 5
        #expect(
            encrypted[trailStart..<totalLen]
                == data[trailStart..<totalLen]
        )
    }

    // MARK: - Short NAL Unit

    @Test("Short NAL unit (< 48 bytes body): left unencrypted")
    func shortNALUnencrypted() throws {
        let data = buildAnnexBData(nalType: 1, bodySize: 40)
        let encrypted = try encryptor.encryptVideoSamples(
            data, key: key, iv: iv
        )
        #expect(encrypted == data)
    }

    // MARK: - Multiple NAL Units

    @Test("Multiple NAL units: each encrypted independently")
    func multipleNALUnits() throws {
        var data = Data()
        data.append(buildAnnexBData(nalType: 7, bodySize: 20))
        data.append(buildAnnexBData(nalType: 5, bodySize: 100))
        data.append(buildAnnexBData(nalType: 1, bodySize: 100))
        let encrypted = try encryptor.encryptVideoSamples(
            data, key: key, iv: iv
        )
        #expect(encrypted.count == data.count)
        // SPS (type 7) should be unchanged
        #expect(encrypted[0..<25] == data[0..<25])
        // IDR and non-IDR should have some encrypted regions
        #expect(encrypted != data)
    }

    // MARK: - Audio ADTS Encryption

    @Test("Encrypt ADTS frame: header intact, body encrypted")
    func encryptADTSFrame() throws {
        let data = buildADTSFrame(bodySize: 100)
        let encrypted = try encryptor.encryptAudioSamples(
            data, key: key, iv: iv
        )
        #expect(encrypted.count == data.count)
        // 7-byte ADTS header unchanged
        #expect(encrypted[0..<7] == data[0..<7])
        // First 16 bytes of audio data unchanged
        #expect(encrypted[7..<23] == data[7..<23])
    }

    @Test("First 16 bytes of audio data remain unencrypted")
    func audioFirst16BytesUnencrypted() throws {
        let data = buildADTSFrame(bodySize: 100)
        let encrypted = try encryptor.encryptAudioSamples(
            data, key: key, iv: iv
        )
        // 7 header + 16 skip = 23 bytes unencrypted
        #expect(encrypted[0..<23] == data[0..<23])
    }

    @Test("Audio trailing bytes (< 16) remain unencrypted")
    func audioTrailingBytes() throws {
        // Body = 16 (skip) + 16 (one block) + 5 (trailing)
        let data = buildADTSFrame(bodySize: 37)
        let encrypted = try encryptor.encryptAudioSamples(
            data, key: key, iv: iv
        )
        let total = 7 + 37
        #expect(encrypted.count == total)
        let trailStart = total - 5
        #expect(
            encrypted[trailStart..<total]
                == data[trailStart..<total]
        )
    }

    @Test("Multiple ADTS frames: each encrypted independently")
    func multipleADTSFrames() throws {
        var data = Data()
        data.append(buildADTSFrame(bodySize: 100))
        data.append(buildADTSFrame(bodySize: 100))
        let encrypted = try encryptor.encryptAudioSamples(
            data, key: key, iv: iv
        )
        #expect(encrypted.count == data.count)
        #expect(encrypted != data)
    }

    @Test("Short ADTS frame: left unencrypted")
    func shortADTSFrame() throws {
        let data = buildADTSFrame(bodySize: 10)
        let encrypted = try encryptor.encryptAudioSamples(
            data, key: key, iv: iv
        )
        #expect(encrypted == data)
    }

    // MARK: - Round-Trip

    @Test("Video: encrypt then decrypt = original")
    func videoRoundTrip() throws {
        #if os(Linux)
            withKnownIssue(
                "SAMPLE-AES decrypt via OpenSSL CLI has padding issue on Linux"
            ) {
                let data = buildAnnexBData(nalType: 5, bodySize: 200)
                let encrypted = try encryptor.encryptVideoSamples(
                    data, key: key, iv: iv
                )
                let decrypted = try encryptor.decryptVideoSamples(
                    encrypted, key: key, iv: iv
                )
                #expect(decrypted == data)
            }
        #else
            let data = buildAnnexBData(nalType: 5, bodySize: 200)
            let encrypted = try encryptor.encryptVideoSamples(
                data, key: key, iv: iv
            )
            let decrypted = try encryptor.decryptVideoSamples(
                encrypted, key: key, iv: iv
            )
            #expect(decrypted == data)
        #endif
    }

    @Test("Audio: encrypt then decrypt = original")
    func audioRoundTrip() throws {
        #if os(Linux)
            withKnownIssue(
                "SAMPLE-AES decrypt via OpenSSL CLI has padding issue on Linux"
            ) {
                let data = buildADTSFrame(bodySize: 200)
                let encrypted = try encryptor.encryptAudioSamples(
                    data, key: key, iv: iv
                )
                let decrypted = try encryptor.decryptAudioSamples(
                    encrypted, key: key, iv: iv
                )
                #expect(decrypted == data)
            }
        #else
            let data = buildADTSFrame(bodySize: 200)
            let encrypted = try encryptor.encryptAudioSamples(
                data, key: key, iv: iv
            )
            let decrypted = try encryptor.decryptAudioSamples(
                encrypted, key: key, iv: iv
            )
            #expect(decrypted == data)
        #endif
    }

    // MARK: - TS Segment

    @Test("Encrypted TS segment same size as original")
    func tsSegmentSameSize() throws {
        let tsData = buildMinimalTSSegment()
        let encrypted = try encryptor.encryptTSSegment(
            tsData, key: key, iv: iv
        )
        #expect(encrypted.count == tsData.count)
    }

    @Test("Encrypt TS segment: PAT/PMT packets unmodified")
    func tsSegmentPATUnmodified() throws {
        let tsData = buildMinimalTSSegment()
        let encrypted = try encryptor.encryptTSSegment(
            tsData, key: key, iv: iv
        )
        // First packet (PAT, PID 0x0000) should be unchanged
        #expect(
            encrypted[0..<188]
                == tsData[0..<188]
        )
    }

    @Test("Small TS data (< 188 bytes) returned unchanged")
    func tsTooSmall() throws {
        let small = Data(repeating: 0x47, count: 100)
        let result = try encryptor.encryptTSSegment(
            small, key: key, iv: iv
        )
        #expect(result == small)
    }

    // MARK: - Error Cases

    @Test("Invalid key size throws error")
    func invalidKeySize() {
        let badKey = Data(repeating: 0xAA, count: 10)
        let data = buildAnnexBData(nalType: 1, bodySize: 100)
        #expect(throws: EncryptionError.self) {
            try encryptor.encryptVideoSamples(
                data, key: badKey, iv: iv
            )
        }
    }

    @Test("Invalid IV size throws error")
    func invalidIVSize() {
        let badIV = Data(repeating: 0xBB, count: 8)
        let data = buildAnnexBData(nalType: 1, bodySize: 100)
        #expect(throws: EncryptionError.self) {
            try encryptor.encryptVideoSamples(
                data, key: key, iv: badIV
            )
        }
    }

    @Test("Audio invalid key size throws error")
    func audioInvalidKeySize() {
        let badKey = Data(repeating: 0xAA, count: 10)
        let data = buildADTSFrame(bodySize: 100)
        #expect(throws: EncryptionError.self) {
            try encryptor.encryptAudioSamples(
                data, key: badKey, iv: iv
            )
        }
    }

    @Test("Custom crypto provider is used")
    func customProvider() throws {
        #if os(Linux)
            withKnownIssue(
                "SAMPLE-AES decrypt via OpenSSL CLI has padding issue on Linux"
            ) {
                let custom = SampleEncryptor(
                    cryptoProvider: defaultCryptoProvider()
                )
                let data = buildAnnexBData(nalType: 5, bodySize: 100)
                let enc = try custom.encryptVideoSamples(
                    data, key: key, iv: iv
                )
                let dec = try custom.decryptVideoSamples(
                    enc, key: key, iv: iv
                )
                #expect(dec == data)
            }
        #else
            let custom = SampleEncryptor(
                cryptoProvider: defaultCryptoProvider()
            )
            let data = buildAnnexBData(nalType: 5, bodySize: 100)
            let enc = try custom.encryptVideoSamples(
                data, key: key, iv: iv
            )
            let dec = try custom.decryptVideoSamples(
                enc, key: key, iv: iv
            )
            #expect(dec == data)
        #endif
    }
}

// MARK: - Test Data Builders

extension SampleEncryptorTests {

    /// Build Annex B data: start code + NAL header + body.
    private func buildAnnexBData(
        nalType: UInt8, bodySize: Int
    ) -> Data {
        var data = Data()
        // Start code
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        // NAL header (forbidden=0, nal_ref_idc=3, nal_type)
        data.append(0x60 | (nalType & 0x1F))
        // NAL body
        data.append(
            Data(
                repeating: UInt8(
                    truncatingIfNeeded: nalType &+ 0x42
                ),
                count: bodySize
            )
        )
        return data
    }

    /// Build an ADTS frame: 7-byte header + body.
    private func buildADTSFrame(bodySize: Int) -> Data {
        let frameLength = 7 + bodySize
        var header = Data(capacity: 7)
        header.append(0xFF)
        header.append(0xF1)
        // profile=1 (AAC-LC), freq=4 (44.1kHz), chan=2 (stereo)
        header.append(0x50)
        header.append(
            0x80 | UInt8((frameLength >> 11) & 0x03)
        )
        header.append(UInt8((frameLength >> 3) & 0xFF))
        header.append(
            UInt8((frameLength & 0x07) << 5) | 0x1F
        )
        header.append(0xFC)

        var data = header
        data.append(Data(repeating: 0x42, count: bodySize))
        return data
    }

    /// Build a minimal TS segment with PAT + video PES.
    private func buildMinimalTSSegment() -> Data {
        var data = Data()

        // PAT packet (PID 0x0000)
        var pat = Data(repeating: 0xFF, count: 188)
        pat[0] = 0x47
        pat[1] = 0x40  // PUSI=1, PID high=0
        pat[2] = 0x00  // PID low=0
        pat[3] = 0x10  // payload only, cc=0
        data.append(pat)

        // Video PES packet (PID 0x0101)
        var vidPkt = Data(repeating: 0x00, count: 188)
        vidPkt[0] = 0x47
        vidPkt[1] = 0x41  // PUSI=1, PID high=1
        vidPkt[2] = 0x01  // PID low=1 → PID=0x0101
        vidPkt[3] = 0x10  // payload only, cc=0
        // PES header
        vidPkt[4] = 0x00  // start code prefix
        vidPkt[5] = 0x00
        vidPkt[6] = 0x01
        vidPkt[7] = 0xE0  // stream ID (video)
        vidPkt[8] = 0x00  // PES length high
        vidPkt[9] = 0x00  // PES length low
        vidPkt[10] = 0x80  // marker
        vidPkt[11] = 0x80  // PTS only
        vidPkt[12] = 0x05  // PES header data length
        // PTS bytes (5 bytes)
        vidPkt[13] = 0x21
        vidPkt[14] = 0x00
        vidPkt[15] = 0x01
        vidPkt[16] = 0x00
        vidPkt[17] = 0x01
        // ES data: Annex B NAL unit
        let esStart = 18
        vidPkt[esStart] = 0x00
        vidPkt[esStart + 1] = 0x00
        vidPkt[esStart + 2] = 0x00
        vidPkt[esStart + 3] = 0x01
        vidPkt[esStart + 4] = 0x65  // NAL type 5 (IDR)
        // Fill body with data (enough for encryption)
        for i in (esStart + 5)..<188 {
            vidPkt[i] = UInt8(truncatingIfNeeded: i)
        }
        data.append(vidPkt)

        return data
    }
}
