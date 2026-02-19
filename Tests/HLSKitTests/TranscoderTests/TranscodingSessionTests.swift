// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import CoreMedia
    import Foundation
    import Testing
    #if canImport(os)
        import os
    #endif

    @testable import HLSKit

    @Suite("TranscodingSession — processTrack")
    struct TranscodingSessionTests {

        // MARK: - Mock Types

        /// Mock reader that returns a fixed number of sample buffers.
        final class MockReader: SampleReading {
            private let buffers: [CMSampleBuffer]
            private var index = 0

            init(buffers: [CMSampleBuffer]) {
                self.buffers = buffers
            }

            func copyNextSampleBuffer() -> CMSampleBuffer? {
                guard index < buffers.count else { return nil }
                let buffer = buffers[index]
                index += 1
                return buffer
            }
        }

        /// Mock writer that tracks appended buffers.
        final class MockWriter: SampleWriting {
            var isReadyForMoreMediaData: Bool = true
            var appendedCount = 0
            var finished = false
            var shouldFailAppend = false

            func append(
                _ sampleBuffer: CMSampleBuffer
            ) -> Bool {
                guard !shouldFailAppend else { return false }
                appendedCount += 1
                return true
            }

            func markAsFinished() {
                finished = true
            }
        }

        // MARK: - Sample Buffer Helper

        private static func makeFormatDescription()
            -> CMAudioFormatDescription?
        {
            var asbd = AudioStreamBasicDescription(
                mSampleRate: 44100,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags:
                    kAudioFormatFlagIsSignedInteger
                    | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 2,
                mFramesPerPacket: 1,
                mBytesPerFrame: 2,
                mChannelsPerFrame: 1,
                mBitsPerChannel: 16,
                mReserved: 0
            )
            var desc: CMAudioFormatDescription?
            CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                asbd: &asbd,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: nil,
                formatDescriptionOut: &desc
            )
            return desc
        }

        /// Create a minimal CMSampleBuffer with the given
        /// presentation timestamp.
        private static func makeSampleBuffer(
            pts: CMTime
        ) -> CMSampleBuffer? {
            guard let desc = makeFormatDescription() else {
                return nil
            }
            let frameCount: CMItemCount = 1024
            let dataSize = frameCount * 2

            var blockBuffer: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(
                allocator: kCFAllocatorDefault,
                memoryBlock: nil,
                blockLength: dataSize,
                blockAllocator: kCFAllocatorDefault,
                customBlockSource: nil,
                offsetToData: 0,
                dataLength: dataSize,
                flags: kCMBlockBufferAssureMemoryNowFlag,
                blockBufferOut: &blockBuffer
            )
            guard let block = blockBuffer else {
                return nil
            }

            var sampleBuffer: CMSampleBuffer?
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: kCFAllocatorDefault,
                dataBuffer: block,
                formatDescription: desc,
                sampleCount: frameCount,
                presentationTimeStamp: pts,
                packetDescriptions: nil,
                sampleBufferOut: &sampleBuffer
            )
            return sampleBuffer
        }

        // MARK: - Tests

        @Test("Process track copies all samples to writer")
        func processAllSamples() async throws {
            let buffers = (0..<5).compactMap { i in
                Self.makeSampleBuffer(
                    pts: CMTime(
                        value: CMTimeValue(i * 1024),
                        timescale: 44100
                    )
                )
            }
            #expect(buffers.count == 5)

            let reader = MockReader(buffers: buffers)
            let writer = MockWriter()

            let session = TranscodingSession(
                sourceDuration: CMTime(
                    value: 44100, timescale: 44100
                ),
                progressHandler: nil
            )

            try await session.processTrack(
                readerOutput: reader,
                writerInput: writer,
                reportProgress: false
            )

            #expect(writer.appendedCount == 5)
            #expect(writer.finished)
        }

        @Test("Process track with empty reader marks finished")
        func processEmptyReader() async throws {
            let reader = MockReader(buffers: [])
            let writer = MockWriter()

            let session = TranscodingSession(
                sourceDuration: CMTime(
                    value: 44100, timescale: 44100
                ),
                progressHandler: nil
            )

            try await session.processTrack(
                readerOutput: reader,
                writerInput: writer,
                reportProgress: false
            )

            #expect(writer.appendedCount == 0)
            #expect(writer.finished)
        }

        @Test("Process track throws on append failure")
        func processAppendFailure() async throws {
            let buffer = Self.makeSampleBuffer(
                pts: CMTime(value: 0, timescale: 44100)
            )
            let buffers = [buffer].compactMap { $0 }
            #expect(buffers.count == 1)

            let reader = MockReader(buffers: buffers)
            let writer = MockWriter()
            writer.shouldFailAppend = true

            let session = TranscodingSession(
                sourceDuration: CMTime(
                    value: 44100, timescale: 44100
                ),
                progressHandler: nil
            )

            await #expect(throws: TranscodingError.self) {
                try await session.processTrack(
                    readerOutput: reader,
                    writerInput: writer,
                    reportProgress: false
                )
            }
        }

        @Test("Process track reports progress")
        func processReportsProgress() async throws {
            let buffers = (0..<3).compactMap { i in
                Self.makeSampleBuffer(
                    pts: CMTime(
                        value: CMTimeValue(i) * 14700,
                        timescale: 44100
                    )
                )
            }
            #expect(buffers.count == 3)

            let reader = MockReader(buffers: buffers)
            let writer = MockWriter()

            let collected = OSAllocatedUnfairLock(
                initialState: [Double]()
            )

            let session = TranscodingSession(
                sourceDuration: CMTime(
                    value: 44100, timescale: 44100
                ),
                progressHandler: { value in
                    collected.withLock { $0.append(value) }
                }
            )

            try await session.processTrack(
                readerOutput: reader,
                writerInput: writer,
                reportProgress: true
            )

            let values = collected.withLock { $0 }
            #expect(!values.isEmpty)
            for value in values {
                #expect(value >= 0.0)
                #expect(value <= 1.0)
            }
        }

        @Test("Process track skips progress when disabled")
        func processSkipsProgress() async throws {
            let buffer = Self.makeSampleBuffer(
                pts: CMTime(value: 0, timescale: 44100)
            )
            let buffers = [buffer].compactMap { $0 }

            let reader = MockReader(buffers: buffers)
            let writer = MockWriter()

            let collected = OSAllocatedUnfairLock(
                initialState: [Double]()
            )

            let session = TranscodingSession(
                sourceDuration: CMTime(
                    value: 44100, timescale: 44100
                ),
                progressHandler: { value in
                    collected.withLock { $0.append(value) }
                }
            )

            try await session.processTrack(
                readerOutput: reader,
                writerInput: writer,
                reportProgress: false
            )

            let values = collected.withLock { $0 }
            #expect(values.isEmpty)
            #expect(writer.appendedCount == 1)
        }

        @Test("Session init stores duration and handler")
        func sessionInit() {
            let duration = CMTime(value: 5, timescale: 1)
            let session = TranscodingSession(
                sourceDuration: duration,
                progressHandler: nil
            )
            #expect(session.sourceDuration == duration)
            #expect(session.progressHandler == nil)
        }

        @Test("Session with handler stores it")
        func sessionWithHandler() {
            let duration = CMTime(value: 10, timescale: 1)
            let flag = OSAllocatedUnfairLock(
                initialState: false
            )
            let session = TranscodingSession(
                sourceDuration: duration,
                progressHandler: { _ in
                    flag.withLock { $0 = true }
                }
            )
            #expect(session.sourceDuration == duration)
            #expect(session.progressHandler != nil)
            session.progressHandler?(0.5)
            #expect(flag.withLock { $0 })
        }
    }

#endif
