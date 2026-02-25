// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Models SCTE-35 splice information for ad insertion in live HLS streams.
///
/// SCTE-35 (ANSI/SCTE 35) defines splice commands for signaling content
/// transitions (ad breaks, program boundaries) in transport streams.
/// In HLS, SCTE-35 data is carried in EXT-X-DATERANGE attributes:
/// SCTE35-CMD, SCTE35-OUT, SCTE35-IN.
///
/// This implementation covers the most common splice commands used in
/// HLS ad insertion workflows. It does NOT implement full SCTE-35 spec
/// (no CRC-32 verification, no encrypted commands, no descriptor parsing).
///
/// ```swift
/// // Create a splice_insert for a 30-second ad break
/// let spliceOut = SCTE35Marker.spliceInsert(
///     eventId: 12345,
///     duration: 30.0,
///     outOfNetwork: true
/// )
/// let binary = spliceOut.serialize()
/// // → Use in EXT-X-DATERANGE: SCTE35-OUT=0x<hex>
///
/// // Parse SCTE-35 binary back
/// let parsed = SCTE35Marker.parse(from: binary)
/// ```
public struct SCTE35Marker: Sendable, Equatable {

    // MARK: - Types

    /// SCTE-35 splice command types.
    public enum SpliceCommandType: UInt8, Sendable, Equatable, CaseIterable {
        /// Keep-alive command.
        case spliceNull = 0x00
        /// Splice insert (ad break start/end).
        case spliceInsert = 0x05
        /// Time signal.
        case timeSignal = 0x06
    }

    /// A splice time with optional PTS.
    public struct SpliceTime: Sendable, Equatable {

        /// Whether the time is specified.
        public var timeSpecified: Bool

        /// PTS value (33-bit, in 90kHz ticks). Only valid when timeSpecified is true.
        public var pts: UInt64?

        /// Creates a splice time.
        ///
        /// - Parameters:
        ///   - timeSpecified: Whether the time is specified.
        ///   - pts: PTS value in 90kHz ticks.
        public init(timeSpecified: Bool = true, pts: UInt64? = nil) {
            self.timeSpecified = timeSpecified
            self.pts = pts
        }

        /// Create a splice time from seconds.
        ///
        /// - Parameter seconds: Time in seconds.
        /// - Returns: A splice time with PTS calculated at 90kHz.
        public static func fromSeconds(_ seconds: TimeInterval) -> SpliceTime {
            SpliceTime(
                timeSpecified: true,
                pts: UInt64(seconds * 90_000)
            )
        }

        /// Convert PTS to seconds (divide by 90000).
        public var seconds: TimeInterval? {
            guard timeSpecified, let pts else { return nil }
            return TimeInterval(pts) / 90_000
        }
    }

    /// Break duration for splice_insert.
    public struct BreakDuration: Sendable, Equatable {

        /// Whether return is automatic (auto-return to network).
        public var autoReturn: Bool

        /// Duration in 90kHz ticks.
        public var duration: UInt64

        /// Creates a break duration.
        ///
        /// - Parameters:
        ///   - autoReturn: Whether return is automatic.
        ///   - duration: Duration in 90kHz ticks.
        public init(autoReturn: Bool = true, duration: UInt64) {
            self.autoReturn = autoReturn
            self.duration = duration
        }

        /// Create from seconds.
        ///
        /// - Parameters:
        ///   - seconds: Duration in seconds.
        ///   - autoReturn: Whether return is automatic.
        /// - Returns: A break duration with ticks calculated at 90kHz.
        public static func fromSeconds(
            _ seconds: TimeInterval, autoReturn: Bool = true
        ) -> BreakDuration {
            BreakDuration(
                autoReturn: autoReturn,
                duration: UInt64(seconds * 90_000)
            )
        }

        /// Convert to seconds.
        public var seconds: TimeInterval {
            TimeInterval(duration) / 90_000
        }
    }

    // MARK: - Properties

    /// The splice command type.
    public var commandType: SpliceCommandType

    /// Splice event ID (for splice_insert).
    public var eventId: UInt32?

    /// Whether this is an out-of-network indicator (start of ad break).
    public var outOfNetwork: Bool

    /// Splice time (PTS of the splice point).
    public var spliceTime: SpliceTime?

    /// Break duration (for splice_insert with duration).
    public var breakDuration: BreakDuration?

    /// Unique program ID.
    public var uniqueProgramId: UInt16

    /// Avail number (for ad scheduling).
    public var availNum: UInt8

    /// Total avails expected.
    public var availsExpected: UInt8

    // MARK: - Initialization

    /// Creates a SCTE-35 marker.
    ///
    /// - Parameters:
    ///   - commandType: The splice command type.
    ///   - eventId: Optional event identifier.
    ///   - outOfNetwork: Whether this is an out-of-network indicator.
    ///   - spliceTime: Optional splice time.
    ///   - breakDuration: Optional break duration.
    ///   - uniqueProgramId: Unique program identifier.
    ///   - availNum: Avail number.
    ///   - availsExpected: Total avails expected.
    public init(
        commandType: SpliceCommandType,
        eventId: UInt32? = nil,
        outOfNetwork: Bool = false,
        spliceTime: SpliceTime? = nil,
        breakDuration: BreakDuration? = nil,
        uniqueProgramId: UInt16 = 0,
        availNum: UInt8 = 0,
        availsExpected: UInt8 = 0
    ) {
        self.commandType = commandType
        self.eventId = eventId
        self.outOfNetwork = outOfNetwork
        self.spliceTime = spliceTime
        self.breakDuration = breakDuration
        self.uniqueProgramId = uniqueProgramId
        self.availNum = availNum
        self.availsExpected = availsExpected
    }

    // MARK: - Factory Methods

    /// Create a splice_null (keep-alive).
    ///
    /// - Returns: A splice_null marker.
    public static func spliceNull() -> SCTE35Marker {
        SCTE35Marker(commandType: .spliceNull)
    }

    /// Create a splice_insert for an ad break.
    ///
    /// - Parameters:
    ///   - eventId: Unique event identifier.
    ///   - duration: Ad break duration in seconds (nil for open-ended).
    ///   - outOfNetwork: true = start of ad break, false = return to program.
    ///   - spliceTime: Optional PTS for the splice point.
    ///   - autoReturn: Whether to automatically return after duration.
    /// - Returns: A splice_insert marker.
    public static func spliceInsert(
        eventId: UInt32,
        duration: TimeInterval? = nil,
        outOfNetwork: Bool = true,
        spliceTime: SpliceTime? = nil,
        autoReturn: Bool = true
    ) -> SCTE35Marker {
        SCTE35Marker(
            commandType: .spliceInsert,
            eventId: eventId,
            outOfNetwork: outOfNetwork,
            spliceTime: spliceTime,
            breakDuration: duration.map {
                BreakDuration.fromSeconds($0, autoReturn: autoReturn)
            }
        )
    }

    /// Create a time_signal.
    ///
    /// - Parameter spliceTime: The PTS of the signal.
    /// - Returns: A time_signal marker.
    public static func timeSignal(spliceTime: SpliceTime) -> SCTE35Marker {
        SCTE35Marker(commandType: .timeSignal, spliceTime: spliceTime)
    }
}

// MARK: - Serialization

extension SCTE35Marker {

    /// Serialize to SCTE-35 binary format (splice_info_section).
    ///
    /// Returns raw binary data suitable for SCTE35-CMD/OUT/IN attributes.
    public func serialize() -> Data {
        let commandData = serializeCommand()
        var writer = BinaryWriter(capacity: 32 + commandData.count)
        writer.writeUInt8(0xFC)  // table_id
        // section_syntax_indicator=0, private=0, sap=0x03, section_length
        let sectionLength = 11 + commandData.count + 4
        let flagsAndLength = UInt16(0x3000) | UInt16(sectionLength & 0x0FFF)
        writer.writeUInt16(flagsAndLength)
        writer.writeUInt8(0x00)  // protocol_version
        // encrypted=0, encryption_algorithm=0, pts_adjustment=0
        writer.writeUInt8(0x00)
        writer.writeUInt32(0)  // pts_adjustment lower 32 bits
        writer.writeUInt8(0x00)  // cw_index
        // tier (12 bits) + splice_command_length (12 bits)
        let tier: UInt16 = 0x0FFF
        let cmdLength = UInt16(commandData.count)
        writer.writeUInt8(UInt8((tier >> 4) & 0xFF))
        writer.writeUInt8(
            UInt8(((tier & 0x0F) << 4) | ((cmdLength >> 8) & 0x0F))
        )
        writer.writeUInt8(UInt8(cmdLength & 0xFF))
        writer.writeUInt8(commandType.rawValue)
        writer.writeData(commandData)
        writer.writeUInt16(0)  // descriptor_loop_length = 0
        writer.writeUInt32(0xFFFF_FFFF)  // CRC-32 placeholder
        return writer.data
    }

    /// Serialize to hex string (for EXT-X-DATERANGE attributes).
    ///
    /// Returns "0x" prefixed uppercase hex string.
    public func serializeHex() -> String {
        let data = serialize()
        return "0x" + data.map { String(format: "%02X", $0) }.joined()
    }

    private func serializeCommand() -> Data {
        var writer = BinaryWriter()
        switch commandType {
        case .spliceNull:
            break
        case .spliceInsert:
            serializeSpliceInsert(&writer)
        case .timeSignal:
            serializeTimeSignal(&writer)
        }
        return writer.data
    }

    private func serializeSpliceInsert(_ writer: inout BinaryWriter) {
        writer.writeUInt32(eventId ?? 0)
        writer.writeUInt8(0x00)  // cancel_indicator = 0
        let hasDuration = breakDuration != nil
        let hasTime = spliceTime?.timeSpecified == true
        var flags: UInt8 = 0
        if outOfNetwork { flags |= 0x80 }
        flags |= 0x40  // program_splice_flag = 1
        if hasDuration { flags |= 0x20 }
        if !hasTime { flags |= 0x10 }  // splice_immediate_flag
        flags |= 0x0F  // reserved bits
        writer.writeUInt8(flags)
        if hasTime {
            writeSpliceTime(&writer, spliceTime)
        }
        if let bd = breakDuration {
            writeBreakDuration(&writer, bd)
        }
        writer.writeUInt16(uniqueProgramId)
        writer.writeUInt8(availNum)
        writer.writeUInt8(availsExpected)
    }

    private func serializeTimeSignal(_ writer: inout BinaryWriter) {
        writeSpliceTime(&writer, spliceTime)
    }

    private func writeSpliceTime(
        _ writer: inout BinaryWriter, _ time: SpliceTime?
    ) {
        guard let time, time.timeSpecified, let pts = time.pts else {
            writer.writeUInt8(0x7E)  // time_specified=0 + reserved
            return
        }
        let byte0 = UInt8(0x80 | 0x3E | UInt8((pts >> 32) & 0x01))
        writer.writeUInt8(byte0)
        writer.writeUInt32(UInt32(pts & 0xFFFF_FFFF))
    }

    private func writeBreakDuration(
        _ writer: inout BinaryWriter, _ bd: BreakDuration
    ) {
        let byte0 = UInt8(
            (bd.autoReturn ? 0x80 : 0x00) | 0x3E
                | UInt8((bd.duration >> 32) & 0x01)
        )
        writer.writeUInt8(byte0)
        writer.writeUInt32(UInt32(bd.duration & 0xFFFF_FFFF))
    }
}

// MARK: - Parsing

extension SCTE35Marker {

    /// Parse SCTE-35 binary data.
    ///
    /// - Parameter data: Raw SCTE-35 binary data.
    /// - Returns: Parsed marker, or nil if data is invalid.
    public static func parse(from data: Data) -> SCTE35Marker? {
        guard data.count >= 15 else { return nil }
        guard data[0] == 0xFC else { return nil }
        guard data[3] == 0x00 else { return nil }  // protocol_version
        let commandTypeByte = data[13]
        guard let cmdType = SpliceCommandType(rawValue: commandTypeByte) else {
            return nil
        }
        let cmdLengthHigh = UInt16(data[11] & 0x0F) << 8
        let cmdLengthLow = UInt16(data[12])
        let cmdLength = Int(cmdLengthHigh | cmdLengthLow)
        let cmdStart = 14
        guard data.count >= cmdStart + cmdLength else { return nil }
        let cmdData = Data(data[cmdStart..<(cmdStart + cmdLength)])
        switch cmdType {
        case .spliceNull:
            return SCTE35Marker(commandType: .spliceNull)
        case .spliceInsert:
            return parseSpliceInsert(cmdData)
        case .timeSignal:
            return parseTimeSignal(cmdData)
        }
    }

    /// Parse from hex string (with or without "0x" prefix).
    ///
    /// - Parameter hex: Hex string to parse.
    /// - Returns: Parsed marker, or nil if invalid.
    public static func parseHex(_ hex: String) -> SCTE35Marker? {
        var hexStr = hex
        if hexStr.hasPrefix("0x") || hexStr.hasPrefix("0X") {
            hexStr = String(hexStr.dropFirst(2))
        }
        guard let data = dataFromHex(hexStr) else { return nil }
        return parse(from: data)
    }

    private static func parseSpliceInsert(_ data: Data) -> SCTE35Marker? {
        guard data.count >= 5 else { return nil }
        let eventId = readUInt32(data, offset: 0)
        let cancelIndicator = (data[4] & 0x80) != 0
        guard !cancelIndicator else {
            return SCTE35Marker(
                commandType: .spliceInsert,
                eventId: eventId
            )
        }
        guard data.count >= 6 else { return nil }
        let flags = data[5]
        let outOfNetwork = (flags & 0x80) != 0
        let hasDuration = (flags & 0x20) != 0
        let spliceImmediate = (flags & 0x10) != 0
        var offset = 6
        var time: SpliceTime?
        if !spliceImmediate {
            let result = readSpliceTime(data, offset: offset)
            time = result.0
            offset = result.1
        }
        var bd: BreakDuration?
        if hasDuration {
            guard data.count >= offset + 5 else { return nil }
            let bdByte0 = data[offset]
            let autoRet = (bdByte0 & 0x80) != 0
            let durHigh = UInt64(bdByte0 & 0x01) << 32
            let durLow = UInt64(readUInt32(data, offset: offset + 1))
            bd = BreakDuration(
                autoReturn: autoRet,
                duration: durHigh | durLow
            )
            offset += 5
        }
        var programId: UInt16 = 0
        var aNum: UInt8 = 0
        var aExp: UInt8 = 0
        if data.count >= offset + 4 {
            programId = readUInt16(data, offset: offset)
            aNum = data[offset + 2]
            aExp = data[offset + 3]
        }
        return SCTE35Marker(
            commandType: .spliceInsert,
            eventId: eventId,
            outOfNetwork: outOfNetwork,
            spliceTime: time,
            breakDuration: bd,
            uniqueProgramId: programId,
            availNum: aNum,
            availsExpected: aExp
        )
    }

    private static func parseTimeSignal(_ data: Data) -> SCTE35Marker? {
        guard !data.isEmpty else { return nil }
        let result = readSpliceTime(data, offset: 0)
        return SCTE35Marker(
            commandType: .timeSignal,
            spliceTime: result.0
        )
    }

    private static func readSpliceTime(
        _ data: Data, offset: Int
    ) -> (SpliceTime, Int) {
        guard data.count > offset else {
            return (SpliceTime(timeSpecified: false), offset)
        }
        let byte0 = data[offset]
        let specified = (byte0 & 0x80) != 0
        if specified {
            guard data.count >= offset + 5 else {
                return (SpliceTime(timeSpecified: false), offset + 1)
            }
            let ptsHigh = UInt64(byte0 & 0x01) << 32
            let ptsLow = UInt64(readUInt32(data, offset: offset + 1))
            return (
                SpliceTime(timeSpecified: true, pts: ptsHigh | ptsLow),
                offset + 5
            )
        }
        return (SpliceTime(timeSpecified: false), offset + 1)
    }

    private static func readUInt32(_ data: Data, offset: Int) -> UInt32 {
        UInt32(data[offset]) << 24
            | UInt32(data[offset + 1]) << 16
            | UInt32(data[offset + 2]) << 8
            | UInt32(data[offset + 3])
    }

    private static func readUInt16(_ data: Data, offset: Int) -> UInt16 {
        UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
    }

    private static func dataFromHex(_ hex: String) -> Data? {
        let chars = Array(hex)
        guard chars.count % 2 == 0 else { return nil }
        var data = Data(capacity: chars.count / 2)
        var index = 0
        while index < chars.count {
            let pair = String(chars[index]) + String(chars[index + 1])
            guard let byte = UInt8(pair, radix: 16) else { return nil }
            data.append(byte)
            index += 2
        }
        return data
    }
}

// MARK: - DATERANGE Integration

extension SCTE35Marker {

    /// Create a DATERANGE-compatible attribute dictionary.
    ///
    /// Returns attributes suitable for DateRangeManager custom attributes.
    /// Includes SCTE35-CMD with hex-encoded binary data.
    public func dateRangeAttributes() -> [String: String] {
        var attrs: [String: String] = [:]
        attrs["SCTE35-CMD"] = serializeHex()
        if outOfNetwork {
            attrs["SCTE35-OUT"] = serializeHex()
        } else {
            attrs["SCTE35-IN"] = serializeHex()
        }
        return attrs
    }
}
