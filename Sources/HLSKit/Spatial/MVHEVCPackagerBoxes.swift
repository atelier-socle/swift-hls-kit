// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - mdia / minf / stbl Boxes

extension MVHEVCPackager {

    func buildMdia(
        configuration: SpatialVideoConfiguration,
        parameterSets: HEVCParameterSets,
        timescale: UInt32
    ) -> Data {
        let mdhd = buildMdhd(timescale: timescale)
        let hdlr = buildHdlr()
        let minf = buildMinf(
            configuration: configuration,
            parameterSets: parameterSets
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mdia", children: [mdhd, hdlr, minf]
        )
        return writer.data
    }

    func buildMdhd(timescale: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(0)  // duration
        payload.writeUInt16(encodeLanguage("und"))
        payload.writeUInt16(0)  // pre_defined
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mdhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildHdlr() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // pre_defined
        payload.writeFourCC("vide")
        payload.writeZeros(12)  // reserved
        let name = "MV-HEVC Video Handler"
        payload.writeData(Data(name.utf8))
        payload.writeUInt8(0)  // null terminator
        var box = BinaryWriter()
        box.writeFullBox(
            type: "hdlr", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildMinf(
        configuration: SpatialVideoConfiguration,
        parameterSets: HEVCParameterSets
    ) -> Data {
        let vmhd = buildVmhd()
        let dinf = buildDinf()
        let stbl = buildStbl(
            configuration: configuration,
            parameterSets: parameterSets
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "minf", children: [vmhd, dinf, stbl]
        )
        return writer.data
    }

    func buildVmhd() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt16(0)  // graphicsmode
        payload.writeZeros(6)  // opcolor
        var box = BinaryWriter()
        box.writeFullBox(
            type: "vmhd", version: 0, flags: 1,
            payload: payload.data
        )
        return box.data
    }

    func buildDinf() -> Data {
        var drefPayload = BinaryWriter()
        drefPayload.writeUInt32(1)  // entry count
        var urlBox = BinaryWriter()
        urlBox.writeFullBox(
            type: "url ", version: 0, flags: 1,
            payload: Data()
        )
        drefPayload.writeData(urlBox.data)
        var dref = BinaryWriter()
        dref.writeFullBox(
            type: "dref", version: 0, flags: 0,
            payload: drefPayload.data
        )
        var dinf = BinaryWriter()
        dinf.writeContainerBox(
            type: "dinf", children: [dref.data]
        )
        return dinf.data
    }

    func buildStbl(
        configuration: SpatialVideoConfiguration,
        parameterSets: HEVCParameterSets
    ) -> Data {
        let stsd = buildStsd(
            configuration: configuration,
            parameterSets: parameterSets
        )
        let emptyTables = buildEmptySampleTables()
        var children = [stsd]
        children.append(contentsOf: emptyTables)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "stbl", children: children
        )
        return writer.data
    }

    func buildStsd(
        configuration: SpatialVideoConfiguration,
        parameterSets: HEVCParameterSets
    ) -> Data {
        let hvc1 = buildHvc1(
            parameterSets: parameterSets,
            configuration: configuration
        )
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // entry count
        payload.writeData(hvc1)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "stsd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildEmptySampleTables() -> [Data] {
        let empty = emptyEntryPayload()
        var stts = BinaryWriter()
        stts.writeFullBox(
            type: "stts", version: 0, flags: 0, payload: empty
        )
        var stsc = BinaryWriter()
        stsc.writeFullBox(
            type: "stsc", version: 0, flags: 0, payload: empty
        )
        var stszPayload = BinaryWriter()
        stszPayload.writeUInt32(0)  // sample_size
        stszPayload.writeUInt32(0)  // sample_count
        var stsz = BinaryWriter()
        stsz.writeFullBox(
            type: "stsz", version: 0, flags: 0,
            payload: stszPayload.data
        )
        var stco = BinaryWriter()
        stco.writeFullBox(
            type: "stco", version: 0, flags: 0, payload: empty
        )
        return [stts.data, stsc.data, stsz.data, stco.data]
    }

    private func emptyEntryPayload() -> Data {
        var w = BinaryWriter()
        w.writeUInt32(0)
        return w.data
    }
}

// MARK: - hvc1 Sample Entry + Spatial Boxes

extension MVHEVCPackager {

    /// Builds the hvc1 visual sample entry containing hvcC and vexu.
    func buildHvc1(
        parameterSets: HEVCParameterSets,
        configuration: SpatialVideoConfiguration
    ) -> Data {
        let hvcC = buildHvcC(parameterSets: parameterSets)
        let vexu = buildVexu(
            channelLayout: configuration.channelLayout
        )

        var payload = BinaryWriter()
        // SampleEntry base: 6 reserved + data_reference_index
        payload.writeZeros(6)
        payload.writeUInt16(1)  // data_reference_index
        // VisualSampleEntry fields (ISO 14496-12)
        payload.writeUInt16(0)  // pre_defined
        payload.writeUInt16(0)  // reserved
        payload.writeZeros(12)  // pre_defined[3]
        payload.writeUInt16(UInt16(configuration.width))
        payload.writeUInt16(UInt16(configuration.height))
        payload.writeUInt32(0x0048_0000)  // horiz resolution 72 dpi
        payload.writeUInt32(0x0048_0000)  // vert resolution 72 dpi
        payload.writeUInt32(0)  // reserved
        payload.writeUInt16(1)  // frame count
        payload.writeZeros(32)  // compressor name
        payload.writeUInt16(0x0018)  // depth (24 bit)
        payload.writeInt16(-1)  // pre_defined
        // Child boxes
        payload.writeData(hvcC)
        payload.writeData(vexu)

        var box = BinaryWriter()
        box.writeBox(type: "hvc1", payload: payload.data)
        return box.data
    }

    /// Builds the hvcC box (HEVCDecoderConfigurationRecord).
    func buildHvcC(
        parameterSets: HEVCParameterSets
    ) -> Data {
        let processor = MVHEVCSampleProcessor()
        let profile = processor.parseSPSProfile(parameterSets.sps)

        var payload = BinaryWriter()
        // configurationVersion
        payload.writeUInt8(1)

        if let profile {
            // general_profile_space(2) + general_tier_flag(1) + general_profile_idc(5)
            let ptlByte =
                (profile.profileSpace << 6)
                | (profile.tierFlag ? 0x20 : 0x00)
                | (profile.profileIDC & 0x1F)
            payload.writeUInt8(ptlByte)
            payload.writeUInt32(profile.profileCompatibilityFlags)
            payload.writeData(profile.constraintIndicatorFlags)
            payload.writeUInt8(profile.levelIDC)
        } else {
            // Fallback: Main10 profile, level 4.1
            payload.writeUInt8(0x42)  // space=0, tier=1, profile=2
            payload.writeUInt32(0x2000_0000)
            payload.writeZeros(6)  // constraint flags
            payload.writeUInt8(123)  // level 4.1
        }

        // min_spatial_segmentation_idc
        payload.writeUInt16(0xF000)
        // parallelismType
        payload.writeUInt8(0xFC)
        // chromaFormat
        let chromaFormat = profile?.chromaFormatIDC ?? 1
        payload.writeUInt8(0xFC | chromaFormat)
        // bitDepthLumaMinus8
        let lumaMinus8 = (profile?.bitDepthLuma ?? 8) - 8
        payload.writeUInt8(0xF8 | lumaMinus8)
        // bitDepthChromaMinus8
        let chromaMinus8 = (profile?.bitDepthChroma ?? 8) - 8
        payload.writeUInt8(0xF8 | chromaMinus8)
        // avgFrameRate
        payload.writeUInt16(0)
        // constantFrameRate(2) + numTemporalLayers(3) +
        // temporalIdNested(1) + lengthSizeMinusOne(2)
        // 0b00_001_1_11 = 0x0F (1 temporal layer, nested, 4-byte length)
        payload.writeUInt8(0x0F)
        // numOfArrays = 3 (VPS, SPS, PPS)
        payload.writeUInt8(3)

        // VPS array
        writeNALUArray(
            to: &payload, naluType: 32,
            nalus: [parameterSets.vps]
        )
        // SPS array
        writeNALUArray(
            to: &payload, naluType: 33,
            nalus: [parameterSets.sps]
        )
        // PPS array
        writeNALUArray(
            to: &payload, naluType: 34,
            nalus: [parameterSets.pps]
        )

        var box = BinaryWriter()
        box.writeBox(type: "hvcC", payload: payload.data)
        return box.data
    }

    private func writeNALUArray(
        to writer: inout BinaryWriter,
        naluType: UInt8,
        nalus: [Data]
    ) {
        // array_completeness(1) + reserved(1) + NAL_unit_type(6)
        writer.writeUInt8(0x80 | (naluType & 0x3F))
        writer.writeUInt16(UInt16(nalus.count))
        for nalu in nalus {
            writer.writeUInt16(UInt16(nalu.count))
            writer.writeData(nalu)
        }
    }

    /// Builds the vexu (Video Extended Usage) container box.
    func buildVexu(
        channelLayout: VideoChannelLayout
    ) -> Data {
        let eyes = buildEyes(channelLayout: channelLayout)
        let hero = buildHero()
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "vexu", children: [eyes, hero]
        )
        return writer.data
    }

    /// Builds the eyes (Stereo View) container box.
    func buildEyes(
        channelLayout: VideoChannelLayout
    ) -> Data {
        let stri = buildStri(channelLayout: channelLayout)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "eyes", children: [stri]
        )
        return writer.data
    }

    /// Builds the stri (Stereo View Information) full box.
    func buildStri(
        channelLayout: VideoChannelLayout
    ) -> Data {
        var payload = BinaryWriter()
        // View byte:
        // bit 0: has_left_eye_view
        // bit 1: has_right_eye_view
        // bit 2: has_additional_views
        // bit 3: eye_views_reversed
        let viewByte: UInt8 =
            channelLayout == .stereoLeftRight
            ? 0x03  // both eyes, normal order
            : 0x01  // left eye only (mono)
        payload.writeUInt8(viewByte)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "stri", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    /// Builds the hero (Hero Eye Description) full box.
    func buildHero() -> Data {
        var payload = BinaryWriter()
        // hero_eye: 0x00 = left eye is hero (2D fallback)
        payload.writeUInt8(0x00)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "hero", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }
}
