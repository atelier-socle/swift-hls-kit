// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ID3TimedMetadata", .timeLimit(.minutes(1)))
struct ID3TimedMetadataTests {

    // MARK: - Serialization Basics

    @Test("Empty metadata serializes to valid ID3v2 header")
    func emptySerialize() {
        let metadata = ID3TimedMetadata()
        let data = metadata.serialize()
        #expect(data.count >= 10)
        // "ID3" magic
        #expect(data[0] == 0x49)
        #expect(data[1] == 0x44)
        #expect(data[2] == 0x33)
        // Version 2.4.0
        #expect(data[3] == 0x04)
        #expect(data[4] == 0x00)
    }

    @Test("Single text frame round-trip")
    func singleTextFrameRoundTrip() {
        var metadata = ID3TimedMetadata()
        metadata.addTextFrame(.title, value: "Episode 42")
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.count == 1)
        #expect(parsed?.frames.first?.id == "TIT2")
    }

    @Test("Multiple text frames round-trip")
    func multipleTextFramesRoundTrip() {
        var metadata = ID3TimedMetadata()
        metadata.addTextFrame(.title, value: "My Track")
        metadata.addTextFrame(.artist, value: "The Artist")
        metadata.addTextFrame(.album, value: "The Album")
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.count == 3)
        let ids = parsed?.frames.map(\.id) ?? []
        #expect(ids.contains("TIT2"))
        #expect(ids.contains("TPE1"))
        #expect(ids.contains("TALB"))
    }

    @Test("Custom TXXX frame round-trip")
    func customFrameRoundTrip() {
        var metadata = ID3TimedMetadata()
        metadata.addCustomFrame(description: "chapter", value: "Introduction")
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.count == 1)
        #expect(parsed?.frames.first?.id == "TXXX")
    }

    @Test("Raw data frame round-trip")
    func rawFrameRoundTrip() {
        var metadata = ID3TimedMetadata()
        let rawData = Data([0x01, 0x02, 0x03, 0x04])
        metadata.addRawFrame(id: "PRIV", data: rawData)
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.first?.id == "PRIV")
        #expect(parsed?.frames.first?.value == rawData)
    }

    @Test("UTF-8 encoding byte present in text frame")
    func utf8EncodingByte() {
        var metadata = ID3TimedMetadata()
        metadata.addTextFrame(.title, value: "Test", encoding: .utf8)
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        let frameValue = parsed?.frames.first?.value
        #expect(frameValue?.first == 0x03)  // UTF-8 encoding byte
    }

    // MARK: - Synchsafe Integers

    @Test("Synchsafe integer: 127 encodes correctly")
    func synchsafe127() {
        var writer = BinaryWriter()
        ID3TimedMetadata.writeSynchsafeInteger(&writer, 127)
        #expect(writer.data == Data([0x00, 0x00, 0x00, 0x7F]))
    }

    @Test("Synchsafe integer: 128 encodes correctly")
    func synchsafe128() {
        var writer = BinaryWriter()
        ID3TimedMetadata.writeSynchsafeInteger(&writer, 128)
        #expect(writer.data == Data([0x00, 0x00, 0x01, 0x00]))
    }

    @Test("Synchsafe round-trip for various values")
    func synchsafeRoundTrip() {
        let values: [UInt32] = [0, 1, 127, 128, 255, 256, 16383, 16384]
        for value in values {
            var writer = BinaryWriter()
            ID3TimedMetadata.writeSynchsafeInteger(&writer, value)
            let decoded = ID3TimedMetadata.readSynchsafe(writer.data, offset: 0)
            #expect(decoded == value)
        }
    }

    // MARK: - Large Data

    @Test("Large frame data survives round-trip")
    func largeFrame() {
        var metadata = ID3TimedMetadata()
        let largeValue = String(repeating: "A", count: 1024)
        metadata.addTextFrame(.title, value: largeValue)
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.count == 1)
    }

    // MARK: - emsg

    @Test("emsg serialization contains scheme URI")
    func emsgSchemeURI() {
        var metadata = ID3TimedMetadata()
        metadata.addTextFrame(.title, value: "Test")
        let emsg = metadata.serializeAsEmsg()
        let schemeString = "https://aomedia.org/emsg/ID3"
        let schemeData = Data(schemeString.utf8)
        #expect(emsg.range(of: schemeData) != nil)
    }

    @Test("emsg contains emsg box type")
    func emsgBoxType() {
        let metadata = ID3TimedMetadata()
        let emsg = metadata.serializeAsEmsg(timescale: 90_000)
        // "emsg" should appear in box header
        let emsgTag = Data("emsg".utf8)
        #expect(emsg.range(of: emsgTag) != nil)
    }

    // MARK: - Presentation Time

    @Test("presentationTime stored and accessible")
    func presentationTime() {
        var metadata = ID3TimedMetadata(presentationTime: 42.5)
        #expect(metadata.presentationTime == 42.5)
        metadata.presentationTime = 100.0
        #expect(metadata.presentationTime == 100.0)
    }

    // MARK: - FrameID

    @Test("All FrameID cases have valid 4-char IDs")
    func frameIDCases() {
        for frameID in ID3TimedMetadata.FrameID.allCases {
            #expect(frameID.rawValue.count == 4)
        }
    }

    // MARK: - Parse Invalid

    @Test("Parse invalid data returns nil")
    func parseInvalid() {
        let result = ID3TimedMetadata.parse(from: Data([0x00, 0x01, 0x02]))
        #expect(result == nil)
    }

    @Test("Parse truncated data returns nil")
    func parseTruncated() {
        let result = ID3TimedMetadata.parse(from: Data([0x49, 0x44, 0x33]))
        #expect(result == nil)
    }

    // MARK: - Edge Cases

    @Test("Frame with empty value serializes correctly")
    func emptyValue() {
        var metadata = ID3TimedMetadata()
        metadata.addTextFrame(.title, value: "")
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.count == 1)
    }

    @Test("Multiple TXXX frames with different descriptions")
    func multipleTXXX() {
        var metadata = ID3TimedMetadata()
        metadata.addCustomFrame(description: "chapter", value: "Ch1")
        metadata.addCustomFrame(description: "mood", value: "happy")
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed?.frames.count == 2)
        #expect(parsed?.frames.allSatisfy { $0.id == "TXXX" } == true)
    }

    @Test("Equatable: same frames are equal")
    func equatableSame() {
        var a = ID3TimedMetadata()
        a.addTextFrame(.title, value: "Test")
        var b = ID3TimedMetadata()
        b.addTextFrame(.title, value: "Test")
        #expect(a == b)
    }

    @Test("Equatable: different frames are not equal")
    func equatableDifferent() {
        var a = ID3TimedMetadata()
        a.addTextFrame(.title, value: "Test A")
        var b = ID3TimedMetadata()
        b.addTextFrame(.title, value: "Test B")
        #expect(a != b)
    }

    @Test("Full round-trip: serialize → parse → equal")
    func fullRoundTrip() {
        var original = ID3TimedMetadata()
        original.addTextFrame(.title, value: "Episode 42")
        original.addTextFrame(.artist, value: "Podcast Host")
        original.addCustomFrame(description: "chapter", value: "Intro")
        let data = original.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed == original)
    }

    // MARK: - Encoding Variants

    @Test("UTF-16 encoding round-trip")
    func utf16Encoding() {
        var metadata = ID3TimedMetadata()
        metadata.addTextFrame(.title, value: "Hello", encoding: .utf16)
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.count == 1)
        if let value = parsed?.frames.first?.value, !value.isEmpty {
            #expect(value[0] == 0x01)  // UTF-16 encoding byte
        }
    }

    @Test("UTF-16BE encoding round-trip")
    func utf16beEncoding() {
        var metadata = ID3TimedMetadata()
        metadata.addTextFrame(.title, value: "Hello", encoding: .utf16be)
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.count == 1)
        if let value = parsed?.frames.first?.value, !value.isEmpty {
            #expect(value[0] == 0x02)  // UTF-16BE encoding byte
        }
    }

    @Test("ISO 8859-1 encoding round-trip")
    func iso88591Encoding() {
        var metadata = ID3TimedMetadata()
        metadata.addTextFrame(.title, value: "Cafe", encoding: .iso88591)
        let data = metadata.serialize()
        let parsed = ID3TimedMetadata.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.frames.count == 1)
        if let value = parsed?.frames.first?.value, !value.isEmpty {
            #expect(value[0] == 0x00)  // ISO 8859-1 encoding byte
        }
    }
}
