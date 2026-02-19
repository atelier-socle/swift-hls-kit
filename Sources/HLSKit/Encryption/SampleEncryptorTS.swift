// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - TS Segment Processing

extension SampleEncryptor {

    func tsPayloadOffset(
        _ data: Data, at packetStart: Int
    ) -> Int {
        let byte3 = data[packetStart + 3]
        let afc = (byte3 >> 4) & 0x03
        if afc == 0b10 || afc == 0b11 {
            let afLength = Int(data[packetStart + 4])
            return packetStart + 5 + afLength
        }
        return packetStart + 4
    }

    func encryptPESAndWrite(
        pesData: Data,
        pid: UInt16,
        keyIV: (key: Data, iv: Data),
        result: inout Data,
        pktStart: Int
    ) throws {
        guard pesData.count > 9 else { return }
        let pesHdrLen = Int(pesData[8])
        let esStart = 9 + pesHdrLen
        guard esStart < pesData.count else { return }

        let esData = pesData.subdata(
            in: esStart..<pesData.count
        )

        let encrypted: Data
        if pid == TSPacket.PID.video {
            encrypted = try encryptVideoSamples(
                esData, key: keyIV.key, iv: keyIV.iv
            )
        } else {
            encrypted = try encryptAudioSamples(
                esData, key: keyIV.key, iv: keyIV.iv
            )
        }

        writeBack(
            encrypted, esStart: esStart,
            pktStart: pktStart, result: &result
        )
    }

    private func writeBack(
        _ encrypted: Data,
        esStart: Int,
        pktStart: Int,
        result: inout Data
    ) {
        var esOff = 0
        var pesOff = 0
        let tsSnapshot = result
        var pktIdx = pktStart / TSPacket.packetSize

        while pktIdx < result.count / TSPacket.packetSize,
            esOff < encrypted.count
        {
            guard
                let payRange = mediaPktPayload(
                    tsSnapshot, pktIdx: pktIdx
                )
            else {
                pktIdx += 1
                continue
            }
            let paySize = payRange.count

            if pesOff < esStart {
                let hdrRem = esStart - pesOff
                if hdrRem >= paySize {
                    pesOff += paySize
                    pktIdx += 1
                    continue
                }
                let writeStart = payRange.lowerBound + hdrRem
                esOff = copyChunk(
                    encrypted, esOff: esOff,
                    into: &result,
                    range: writeStart..<payRange.upperBound
                )
            } else {
                esOff = copyChunk(
                    encrypted, esOff: esOff,
                    into: &result, range: payRange
                )
            }
            pesOff += paySize
            pktIdx += 1
        }
    }

    private func mediaPktPayload(
        _ data: Data, pktIdx: Int
    ) -> Range<Int>? {
        let start = pktIdx * TSPacket.packetSize
        let end = start + TSPacket.packetSize
        guard end <= data.count else { return nil }
        guard data[start] == TSPacket.syncByte else {
            return nil
        }
        let b1 = data[start + 1]
        let b2 = data[start + 2]
        let pid = UInt16(b1 & 0x1F) << 8 | UInt16(b2)
        guard
            pid == TSPacket.PID.video
                || pid == TSPacket.PID.audio
        else { return nil }
        let payStart = tsPayloadOffset(data, at: start)
        guard payStart < end else { return nil }
        return payStart..<end
    }

    private func copyChunk(
        _ encrypted: Data,
        esOff: Int,
        into result: inout Data,
        range: Range<Int>
    ) -> Int {
        let cpSize = min(
            range.count, encrypted.count - esOff
        )
        guard cpSize > 0 else { return esOff }
        let chunk = encrypted.subdata(
            in: esOff..<(esOff + cpSize)
        )
        result.replaceSubrange(
            range.lowerBound..<(range.lowerBound + cpSize),
            with: chunk
        )
        return esOff + cpSize
    }
}
