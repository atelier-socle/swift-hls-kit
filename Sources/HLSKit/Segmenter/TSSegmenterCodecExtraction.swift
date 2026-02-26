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
        let videoConfig = try videoAnalysis.map {
            try extractVideoConfig($0)
        }
        let audioConfig = try audioAnalysis.map {
            try extractAudioConfig($0)
        }
        return TSCodecConfig(
            sps: videoConfig?.sps, pps: videoConfig?.pps,
            aacConfig: audioConfig?.aacConfig,
            videoStreamType: videoConfig?.streamType,
            audioStreamType: audioConfig?.streamType
        )
    }

    private struct VideoCodecResult {
        let sps: Data
        let pps: Data
        let streamType: ProgramTableGenerator.StreamType
    }

    private struct AudioCodecResult {
        let aacConfig: ADTSConverter.AACConfig
        let streamType: ProgramTableGenerator.StreamType
    }

    private func extractVideoConfig(
        _ video: MP4TrackAnalysis
    ) throws -> VideoCodecResult {
        let codec = video.info.codec
        switch codec {
        case "avc1", "avc3":
            let avcCData = try extractAvcC(
                from: video.info.sampleDescriptionData
            )
            let converter = AnnexBConverter()
            let params = try converter.extractParameterSets(
                from: avcCData
            )
            return VideoCodecResult(
                sps: params.sps, pps: params.pps,
                streamType: .h264
            )
        case "hvc1", "hev1":
            let hvcCData = try extractHvcC(
                from: video.info.sampleDescriptionData
            )
            let converter = AnnexBConverter()
            let params =
                try converter.extractHEVCParameterSets(
                    from: hvcCData
                )
            var combined = Data()
            combined.append(params.vps)
            combined.append(params.sps)
            return VideoCodecResult(
                sps: combined, pps: params.pps,
                streamType: .h265
            )
        default:
            throw TransportError.unsupportedCodec(codec)
        }
    }

    private func extractAudioConfig(
        _ audio: MP4TrackAnalysis
    ) throws -> AudioCodecResult {
        let codec = audio.info.codec
        guard codec == "mp4a" else {
            throw TransportError.unsupportedCodec(codec)
        }
        let esdsData = try extractEsds(
            from: audio.info.sampleDescriptionData
        )
        let adtsConverter = ADTSConverter()
        let ascData =
            try adtsConverter.extractAudioSpecificConfig(
                from: esdsData
            )
        let config = try adtsConverter.extractConfig(
            from: ascData
        )
        return AudioCodecResult(
            aacConfig: config, streamType: .aac
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

    /// Extract hvcC box data from stsd payload.
    ///
    /// stsd layout is the same as avcC: entry header(8)
    /// + visual sample entry(78) + config box.
    func extractHvcC(
        from stsdPayload: Data
    ) throws -> Data {
        guard stsdPayload.count > 16 else {
            throw TransportError.invalidAVCConfig(
                "stsd payload too short for hvcC"
            )
        }
        let base = stsdPayload.startIndex
        let entryStart = base + 8
        // Same 78-byte visual sample entry as AVC
        let hvcCOffset = entryStart + 8 + 78
        guard hvcCOffset + 8 <= stsdPayload.endIndex else {
            throw TransportError.invalidAVCConfig(
                "stsd too short for hvcC"
            )
        }
        let hvcCSize = readUInt32(stsdPayload, at: hvcCOffset)
        let typeStart = hvcCOffset + 4
        guard typeStart + 4 <= stsdPayload.endIndex else {
            throw TransportError.invalidAVCConfig(
                "cannot read hvcC type"
            )
        }
        let typeData = stsdPayload[typeStart..<(typeStart + 4)]
        let typeStr = String(
            data: Data(typeData), encoding: .ascii
        )
        guard typeStr == "hvcC" else {
            throw TransportError.invalidAVCConfig(
                "expected hvcC but found \(typeStr ?? "nil")"
            )
        }
        let payloadStart = hvcCOffset + 8
        let payloadEnd = hvcCOffset + Int(hvcCSize)
        guard payloadEnd <= stsdPayload.endIndex else {
            throw TransportError.invalidAVCConfig(
                "hvcC payload extends beyond stsd"
            )
        }
        return Data(stsdPayload[payloadStart..<payloadEnd])
    }

    /// Extract esds box data from stsd payload.
    ///
    /// Supports both standard MP4 (`stsd → mp4a → esds`) and
    /// QuickTime MOV (`stsd → mp4a → wave → esds`) layouts.
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
        // mp4a version field: box header(8) + reserved(6)
        // + dataRefIndex(2) = 16 bytes from entry start
        let versionOffset = entryStart + 16
        var extraHeaderBytes = 0
        if versionOffset + 2 <= stsdPayload.endIndex {
            let version =
                UInt16(stsdPayload[versionOffset]) << 8
                | UInt16(stsdPayload[versionOffset + 1])
            switch version {
            case 1: extraHeaderBytes = 16
            case 2: extraHeaderBytes = 36
            default: break
            }
        }
        let childrenStart =
            entryStart + 8 + 28 + extraHeaderBytes
        let childrenEnd = stsdPayload.endIndex
        guard childrenStart + 8 <= childrenEnd else {
            throw TransportError.invalidAudioConfig(
                "stsd too short for esds"
            )
        }
        // Standard MP4: esds as direct child of mp4a
        if let esds = findChildBox(
            "esds", in: stsdPayload,
            from: childrenStart, to: childrenEnd
        ) {
            return try readEsdsPayload(
                from: stsdPayload, at: esds.offset,
                size: esds.size
            )
        }
        // QuickTime MOV: esds nested inside wave box
        if let wave = findChildBox(
            "wave", in: stsdPayload,
            from: childrenStart, to: childrenEnd
        ) {
            let waveStart = wave.offset + 8
            let waveEnd = wave.offset + wave.size
            if let esds = findChildBox(
                "esds", in: stsdPayload,
                from: waveStart, to: waveEnd
            ) {
                return try readEsdsPayload(
                    from: stsdPayload, at: esds.offset,
                    size: esds.size
                )
            }
        }
        throw TransportError.invalidAudioConfig(
            "esds not found (checked direct and wave paths)"
        )
    }

    /// Scan ISOBMFF child boxes for a given type.
    private func findChildBox(
        _ type: String,
        in data: Data,
        from start: Int,
        to end: Int
    ) -> (offset: Int, size: Int)? {
        var pos = start
        while pos + 8 <= end {
            let boxSize = Int(readUInt32(data, at: pos))
            guard boxSize >= 8, pos + boxSize <= end else {
                break
            }
            let typeStart = pos + 4
            let typeData = data[typeStart..<(typeStart + 4)]
            let typeStr = String(
                data: Data(typeData), encoding: .ascii
            )
            if typeStr == type {
                return (offset: pos, size: boxSize)
            }
            pos += boxSize
        }
        return nil
    }

    /// Read esds box payload (skip header + version/flags).
    private func readEsdsPayload(
        from data: Data,
        at offset: Int,
        size: Int
    ) throws -> Data {
        let payloadStart = offset + 12
        let payloadEnd = offset + size
        guard payloadEnd <= data.endIndex else {
            throw TransportError.invalidAudioConfig(
                "esds payload extends beyond stsd"
            )
        }
        return Data(data[payloadStart..<payloadEnd])
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
