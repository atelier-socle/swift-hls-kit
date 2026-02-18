// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Codec Config Extraction

extension TSSegmenter {

    /// Extract TS codec configuration from MP4 track analyses.
    func extractCodecConfig(
        videoAnalysis: MP4TrackAnalysis?,
        audioAnalysis: MP4TrackAnalysis?,
        sourceBoxes: [MP4Box]
    ) throws -> TSCodecConfig {
        var sps: Data?
        var pps: Data?
        var aacConfig: ADTSConverter.AACConfig?
        var videoStreamType: ProgramTableGenerator.StreamType?
        var audioStreamType: ProgramTableGenerator.StreamType?

        if let video = videoAnalysis {
            let codec = video.info.codec
            guard codec == "avc1" || codec == "avc3" else {
                throw TransportError.unsupportedCodec(codec)
            }
            videoStreamType = .h264
            let avcCData = try extractAvcC(
                from: video.info.sampleDescriptionData
            )
            let converter = AnnexBConverter()
            let params = try converter.extractParameterSets(
                from: avcCData
            )
            sps = params.sps
            pps = params.pps
        }

        if let audio = audioAnalysis {
            let codec = audio.info.codec
            guard codec == "mp4a" else {
                throw TransportError.unsupportedCodec(codec)
            }
            audioStreamType = .aac
            let esdsData = try extractEsds(
                from: audio.info.sampleDescriptionData
            )
            let adtsConverter = ADTSConverter()
            let ascData =
                try adtsConverter.extractAudioSpecificConfig(
                    from: esdsData
                )
            aacConfig = try adtsConverter.extractConfig(
                from: ascData
            )
        }

        return TSCodecConfig(
            sps: sps, pps: pps,
            aacConfig: aacConfig,
            videoStreamType: videoStreamType,
            audioStreamType: audioStreamType
        )
    }
}

// MARK: - Box Data Extraction

extension TSSegmenter {

    /// Extract avcC box data from stsd payload.
    ///
    /// stsd layout: version(1) + flags(3) + entryCount(4)
    /// + entry: size(4) + codec(4) + reserved(6) +
    /// dataRefIndex(2) + ... + avcC box
    func extractAvcC(
        from stsdPayload: Data
    ) throws -> Data {
        guard stsdPayload.count > 16 else {
            throw TransportError.invalidAVCConfig(
                "stsd payload too short"
            )
        }
        let base = stsdPayload.startIndex
        let entryStart = base + 8
        // avc1: 78 bytes after 8-byte entry header
        let avcCOffset = entryStart + 8 + 78
        guard avcCOffset + 8 <= stsdPayload.endIndex else {
            throw TransportError.invalidAVCConfig(
                "stsd too short for avcC"
            )
        }
        let avcCSize = readUInt32(stsdPayload, at: avcCOffset)
        let typeStart = avcCOffset + 4
        guard typeStart + 4 <= stsdPayload.endIndex else {
            throw TransportError.invalidAVCConfig(
                "cannot read avcC type"
            )
        }
        let typeData = stsdPayload[typeStart..<(typeStart + 4)]
        let typeStr = String(
            data: Data(typeData), encoding: .ascii
        )
        guard typeStr == "avcC" else {
            throw TransportError.invalidAVCConfig(
                "expected avcC but found \(typeStr ?? "nil")"
            )
        }
        let payloadStart = avcCOffset + 8
        let payloadEnd = avcCOffset + Int(avcCSize)
        guard payloadEnd <= stsdPayload.endIndex else {
            throw TransportError.invalidAVCConfig(
                "avcC payload extends beyond stsd"
            )
        }
        return Data(stsdPayload[payloadStart..<payloadEnd])
    }

    /// Extract esds box data from stsd payload.
    ///
    /// stsd → mp4a entry → esds box
    func extractEsds(
        from stsdPayload: Data
    ) throws -> Data {
        guard stsdPayload.count > 16 else {
            throw TransportError.invalidAudioConfig(
                "stsd payload too short"
            )
        }
        let base = stsdPayload.startIndex
        let entryStart = base + 8
        // mp4a: 28 bytes after 8-byte entry header
        let esdsOffset = entryStart + 8 + 28
        guard esdsOffset + 8 <= stsdPayload.endIndex else {
            throw TransportError.invalidAudioConfig(
                "stsd too short for esds"
            )
        }
        let esdsSize = readUInt32(stsdPayload, at: esdsOffset)
        let typeStart = esdsOffset + 4
        guard typeStart + 4 <= stsdPayload.endIndex else {
            throw TransportError.invalidAudioConfig(
                "cannot read esds type"
            )
        }
        let typeData = stsdPayload[typeStart..<(typeStart + 4)]
        let typeStr = String(
            data: Data(typeData), encoding: .ascii
        )
        guard typeStr == "esds" else {
            throw TransportError.invalidAudioConfig(
                "expected esds but found \(typeStr ?? "nil")"
            )
        }
        // esds payload: skip box header(8) + version(4)
        let payloadStart = esdsOffset + 12
        let payloadEnd = esdsOffset + Int(esdsSize)
        guard payloadEnd <= stsdPayload.endIndex else {
            throw TransportError.invalidAudioConfig(
                "esds payload extends beyond stsd"
            )
        }
        return Data(stsdPayload[payloadStart..<payloadEnd])
    }

    func readUInt32(
        _ data: Data, at offset: Int
    ) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1])
        let b2 = UInt32(data[offset + 2])
        let b3 = UInt32(data[offset + 3])
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }
}
