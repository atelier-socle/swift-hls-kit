// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Video moov

extension CMAFWriter {

    func buildVideoMoov(
        config: VideoConfig
    ) -> Data {
        let mvhd = buildMvhd(
            timescale: config.timescale,
            nextTrackID: config.trackID + 1
        )
        let trak = buildVideoTrak(config: config)
        let mvex = buildMvex(trackID: config.trackID)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "moov",
            children: [mvhd, trak, mvex]
        )
        return writer.data
    }

    private func buildVideoTrak(
        config: VideoConfig
    ) -> Data {
        let tkhd = buildTkhd(
            trackID: config.trackID,
            isAudio: false,
            width: config.width, height: config.height
        )
        let mdia = buildVideoMdia(config: config)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "trak",
            children: [tkhd, mdia]
        )
        return writer.data
    }

    private func buildVideoMdia(
        config: VideoConfig
    ) -> Data {
        let mdhd = buildMdhd(timescale: config.timescale)
        let hdlr = buildHdlr(type: "vide", name: "VideoHandler")
        let minf = buildVideoMinf(config: config)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mdia",
            children: [mdhd, hdlr, minf]
        )
        return writer.data
    }

    private func buildVideoMinf(
        config: VideoConfig
    ) -> Data {
        let vmhd = buildVmhd()
        let dinf = buildDinf()
        let stbl = buildVideoStbl(config: config)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "minf",
            children: [vmhd, dinf, stbl]
        )
        return writer.data
    }

    private func buildVideoStbl(
        config: VideoConfig
    ) -> Data {
        let stsd = buildVideoStsd(config: config)
        let emptyBoxes = buildEmptySampleTables()
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "stbl",
            children: [stsd] + emptyBoxes
        )
        return writer.data
    }

    private func buildVideoStsd(
        config: VideoConfig
    ) -> Data {
        let sampleEntry = buildAvc1SampleEntry(config: config)
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // version + flags
        payload.writeUInt32(1)  // entry count
        payload.writeData(sampleEntry)
        var box = BinaryWriter()
        box.writeBox(type: "stsd", payload: payload.data)
        return box.data
    }
}
