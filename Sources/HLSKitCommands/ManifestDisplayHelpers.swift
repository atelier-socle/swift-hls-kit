// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import HLSKit

// MARK: - Variant & Rendition Display

func formatVariantJSON(
    _ v: Variant, index: Int
) -> [String: Any] {
    var entry: [String: Any] = [
        "index": index,
        "resolution": v.resolution.map {
            "\($0.width)x\($0.height)"
        } ?? "audio",
        "bandwidth": v.bandwidth,
        "uri": v.uri
    ]
    if let sc = v.supplementalCodecs {
        entry["supplementalCodecs"] = sc
    }
    if let vld = v.videoLayoutDescriptor {
        entry["videoLayout"] = vld.attributeValue
    }
    return entry
}

func formatRenditionJSON(
    _ r: Rendition
) -> [String: Any] {
    var entry: [String: Any] = [
        "name": r.name,
        "type": r.type.rawValue,
        "groupId": r.groupId
    ]
    if let codec = r.codec {
        entry["codec"] = codec
    }
    return entry
}

func formatDefinitionsJSON(
    _ definitions: [VariableDefinition]
) -> [[String: Any]] {
    definitions.map { d in
        [
            "name": d.name,
            "value": d.value,
            "type": d.type.rawValue
        ]
    }
}

func formatVariantDetail(_ variant: Variant) -> String {
    let res =
        variant.resolution.map {
            "\($0.width)x\($0.height)"
        } ?? "audio"
    var detail =
        "\(res) @ \(variant.bandwidth) bps"
        + " → \(variant.uri)"
    if let sc = variant.supplementalCodecs {
        detail += " SUPPLEMENTAL-CODECS=\(sc)"
    }
    if let vld = variant.videoLayoutDescriptor {
        detail +=
            " REQ-VIDEO-LAYOUT=\(vld.attributeValue)"
    }
    return detail
}

// MARK: - Definition Pairs

func appendDefinitionDisplayPairs(
    _ definitions: [VariableDefinition],
    to pairs: inout [(String, String)]
) {
    guard !definitions.isEmpty else { return }
    pairs.append(
        ("Definitions:", "\(definitions.count)")
    )
    for def in definitions {
        pairs.append(
            ("  Define:", formatDefinitionLabel(def))
        )
    }
}

func formatDefinitionLabel(
    _ def: VariableDefinition
) -> String {
    switch def.type {
    case .value:
        return "\(def.name)=\"\(def.value)\""
    case .import:
        return "IMPORT=\"\(def.name)\""
    case .queryParam:
        return "QUERYPARAM=\"\(def.name)\""
    }
}

// MARK: - Rendition Pairs

func appendRenditionDisplayPairs(
    _ renditions: [Rendition],
    to pairs: inout [(String, String)]
) {
    guard !renditions.isEmpty else { return }
    for rendition in renditions {
        var detail =
            "\(rendition.type.rawValue) "
            + "\"\(rendition.name)\""
        if let codec = rendition.codec {
            detail += " CODECS=\(codec)"
        }
        pairs.append(("  Rendition:", detail))
    }
}

// MARK: - Session Key Pairs

func appendSessionKeyDisplayPairs(
    _ keys: [EncryptionKey],
    to pairs: inout [(String, String)]
) {
    for key in keys {
        var detail = key.method.rawValue
        if let kf = key.keyFormat {
            if kf.contains("fairplay")
                || kf.contains("streamingkeydelivery")
            {
                detail += " (FairPlay)"
            } else if kf.contains("edef8ba9") {
                detail += " (CENC/Widevine)"
            }
        }
        pairs.append(("Session Key:", detail))
    }
}

// MARK: - Content Steering Pair

func appendContentSteeringDisplayPair(
    _ steering: ContentSteering?,
    to pairs: inout [(String, String)]
) {
    guard let steering else { return }
    var detail = steering.serverUri
    if let pid = steering.pathwayId {
        detail += " (PATHWAY-ID=\(pid))"
    }
    pairs.append(("Content Steering:", detail))
}

// MARK: - Encryption Pairs

func appendEncryptionDisplayPairs(
    _ segments: [Segment],
    to pairs: inout [(String, String)]
) {
    guard
        let firstKey = segments.first(
            where: { $0.key != nil }
        )?.key
    else { return }
    var detail = firstKey.method.rawValue
    if let uri = firstKey.uri {
        let truncated =
            uri.count > 40
            ? String(uri.prefix(37)) + "..." : uri
        detail += " URI=\(truncated)"
    }
    pairs.append(("Encryption:", detail))
}

// MARK: - DateRange Pairs

func appendDateRangeDisplayPairs(
    _ dateRanges: [DateRange],
    to pairs: inout [(String, String)]
) {
    guard !dateRanges.isEmpty else { return }
    pairs.append(
        ("DateRanges:", "\(dateRanges.count)")
    )
    for dr in dateRanges {
        pairs.append(
            ("  \(dr.id):", formatDateRangeDetail(dr))
        )
    }
}

func formatDateRangeDetail(
    _ dr: DateRange
) -> String {
    let fmt = ISO8601DateFormatter()
    var detail = fmt.string(from: dr.startDate)
    if let dur = dr.duration {
        detail += " (\(dur)s)"
    }
    if let planned = dr.plannedDuration {
        detail += " PLANNED-DURATION=\(planned)s"
    }
    if let cls = dr.classAttribute {
        detail += " CLASS=\(cls)"
    }
    if dr.scte35Cmd != nil || dr.scte35Out != nil {
        detail += " SCTE35"
    }
    return detail
}

// MARK: - Segment Detail

func formatSegmentDetail(_ seg: Segment) -> String {
    var detail =
        "\(seg.uri) "
        + String(format: "(%.1fs)", seg.duration)
    if let br = seg.byteRange {
        let start = br.offset ?? 0
        detail += " [\(start)-\(start + br.length)]"
    }
    return detail
}

// MARK: - JSON Output

func printFormattedJSON(_ object: Any) {
    guard
        let data = try? JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        ),
        let str = String(data: data, encoding: .utf8)
    else {
        return
    }
    print(str)
}

// MARK: - Bitrate Formatting

func formatBitrateDisplay(_ bps: Int) -> String {
    if bps >= 1_000_000 {
        return String(
            format: "%.1f Mbps", Double(bps) / 1_000_000.0
        )
    }
    return String(
        format: "%.0f kbps", Double(bps) / 1_000.0
    )
}
