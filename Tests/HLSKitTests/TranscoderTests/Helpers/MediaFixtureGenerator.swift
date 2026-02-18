// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    @preconcurrency import AVFoundation
    import CoreMedia
    import Foundation

    /// Generates real media fixtures for AVFoundation transcoding tests.
    ///
    /// Creates minimal audio and video files using AVFoundation that
    /// are guaranteed to be readable by AVAssetReader.
    enum MediaFixtureGenerator {

        // MARK: - Audio Fixture

        /// Create a short AAC audio file (.m4a).
        ///
        /// Writes PCM samples via AVAssetWriter with AAC encoding,
        /// producing a valid MPEG-4 audio file.
        ///
        /// - Parameters:
        ///   - url: Output file URL (should end in .m4a).
        ///   - duration: Duration in seconds (default 1.0).
        /// - Throws: If file creation fails or times out.
        static func createAudioFixture(
            at url: URL, duration: Double = 1.0
        ) async throws {
            try? FileManager.default.removeItem(at: url)
            let writer = try AVAssetWriter(
                outputURL: url, fileType: .m4a
            )

            let audioInput = makeAudioInput()
            writer.add(audioInput)

            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            try writeAudioSamples(
                to: audioInput,
                duration: duration,
                sampleRate: 44_100
            )

            audioInput.markAsFinished()
            try await finishWriter(writer)
        }

        // MARK: - Video Fixture

        /// Create a minimal video+audio .mp4 file.
        ///
        /// Uses AVAssetWriter with H.264 320x240 video and AAC audio.
        ///
        /// - Parameters:
        ///   - url: Output file URL (should end in .mp4).
        ///   - duration: Duration in seconds (default 1.0).
        /// - Throws: If file creation fails or times out.
        static func createVideoFixture(
            at url: URL, duration: Double = 1.0
        ) async throws {
            try? FileManager.default.removeItem(at: url)
            let writer = try AVAssetWriter(
                outputURL: url, fileType: .mp4
            )

            let (videoInput, adaptor) = makeVideoInput()
            let audioInput = makeAudioInput()

            writer.add(videoInput)
            writer.add(audioInput)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            try writeVideoFrames(
                adaptor: adaptor,
                input: videoInput,
                duration: duration
            )
            videoInput.markAsFinished()

            try writeAudioSamples(
                to: audioInput,
                duration: duration,
                sampleRate: 44_100
            )
            audioInput.markAsFinished()

            try await finishWriter(writer)
        }

        // MARK: - Video-Only Fixture

        /// Create a video-only .mp4 file (no audio track).
        ///
        /// - Parameters:
        ///   - url: Output file URL (should end in .mp4).
        ///   - duration: Duration in seconds (default 1.0).
        /// - Throws: If file creation fails or times out.
        static func createVideoOnlyFixture(
            at url: URL, duration: Double = 1.0
        ) async throws {
            try? FileManager.default.removeItem(at: url)
            let writer = try AVAssetWriter(
                outputURL: url, fileType: .mp4
            )

            let (videoInput, adaptor) = makeVideoInput()

            writer.add(videoInput)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            try writeVideoFrames(
                adaptor: adaptor,
                input: videoInput,
                duration: duration
            )
            videoInput.markAsFinished()

            try await finishWriter(writer)
        }

        // MARK: - Fixture Directory

        /// Shared temp directory for test fixtures.
        static var fixtureDirectory: URL {
            FileManager.default.temporaryDirectory
                .appendingPathComponent("HLSKitTestFixtures")
        }

        /// Create the fixture directory if needed.
        static func setUp() throws {
            try FileManager.default.createDirectory(
                at: fixtureDirectory,
                withIntermediateDirectories: true
            )
        }

        /// Clean up fixture directory.
        static func tearDown() {
            try? FileManager.default.removeItem(
                at: fixtureDirectory
            )
        }
    }

    // MARK: - Input Factories

    extension MediaFixtureGenerator {

        private static func makeAudioInput()
            -> AVAssetWriterInput
        {
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000
            ]
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: settings
            )
            input.expectsMediaDataInRealTime = false
            return input
        }

        private static func makeVideoInput() -> (
            AVAssetWriterInput,
            AVAssetWriterInputPixelBufferAdaptor
        ) {
            let settings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 320,
                AVVideoHeightKey: 240,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 100_000,
                    AVVideoMaxKeyFrameIntervalKey: 10
                ] as [String: Any]
            ]
            let input = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: settings
            )
            input.expectsMediaDataInRealTime = false
            let adaptor =
                AVAssetWriterInputPixelBufferAdaptor(
                    assetWriterInput: input,
                    sourcePixelBufferAttributes: [
                        kCVPixelBufferPixelFormatTypeKey
                            as String:
                            kCVPixelFormatType_32BGRA,
                        kCVPixelBufferWidthKey as String:
                            320,
                        kCVPixelBufferHeightKey as String:
                            240
                    ]
                )
            return (input, adaptor)
        }

        private static func finishWriter(
            _ writer: AVAssetWriter
        ) async throws {
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw FixtureError.writerFailed(
                    writer.error?.localizedDescription
                        ?? "unknown"
                )
            }
        }
    }

    // MARK: - Sample Writing

    extension MediaFixtureGenerator {

        private static func writeVideoFrames(
            adaptor: AVAssetWriterInputPixelBufferAdaptor,
            input: AVAssetWriterInput,
            duration: Double
        ) throws {
            let fps = 10
            let totalFrames = Int(duration * Double(fps))

            for frame in 0..<totalFrames {
                while !input.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                }

                let time = CMTime(
                    value: CMTimeValue(frame),
                    timescale: CMTimeScale(fps)
                )

                var pixelBuffer: CVPixelBuffer?
                guard let pool = adaptor.pixelBufferPool
                else {
                    throw FixtureError.pixelBufferFailed
                }
                let status =
                    CVPixelBufferPoolCreatePixelBuffer(
                        kCFAllocatorDefault,
                        pool,
                        &pixelBuffer
                    )
                guard status == kCVReturnSuccess,
                    let buffer = pixelBuffer
                else {
                    throw FixtureError.pixelBufferFailed
                }

                CVPixelBufferLockBaseAddress(buffer, [])
                let baseAddress =
                    CVPixelBufferGetBaseAddress(buffer)
                let bytesPerRow =
                    CVPixelBufferGetBytesPerRow(buffer)
                let height = CVPixelBufferGetHeight(buffer)
                if let base = baseAddress {
                    memset(base, 128, bytesPerRow * height)
                }
                CVPixelBufferUnlockBaseAddress(buffer, [])

                adaptor.append(buffer, withPresentationTime: time)
            }
        }

        private static func makeAudioFormat(
            sampleRate: Double
        ) throws -> CMAudioFormatDescription {
            var asbd = AudioStreamBasicDescription(
                mSampleRate: sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsSignedInteger
                    | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 2,
                mFramesPerPacket: 1,
                mBytesPerFrame: 2,
                mChannelsPerFrame: 1,
                mBitsPerChannel: 16,
                mReserved: 0
            )

            var formatDesc: CMAudioFormatDescription?
            let status = CMAudioFormatDescriptionCreate(
                allocator: kCFAllocatorDefault,
                asbd: &asbd,
                layoutSize: 0,
                layout: nil,
                magicCookieSize: 0,
                magicCookie: nil,
                extensions: nil,
                formatDescriptionOut: &formatDesc
            )
            guard status == noErr, let formatDesc else {
                throw FixtureError.formatDescFailed
            }
            return formatDesc
        }

        private static func writeAudioSamples(
            to input: AVAssetWriterInput,
            duration: Double,
            sampleRate: Double
        ) throws {
            let formatDesc = try makeAudioFormat(
                sampleRate: sampleRate
            )
            let totalSamples = Int(sampleRate * duration)
            let samplesPerChunk = 1024
            var samplesWritten = 0

            while samplesWritten < totalSamples {
                while !input.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                }
                let chunkSize = min(
                    samplesPerChunk,
                    totalSamples - samplesWritten
                )
                let sampleBuffer = try makeAudioChunk(
                    formatDesc: formatDesc,
                    chunkSize: chunkSize,
                    samplesWritten: samplesWritten,
                    sampleRate: sampleRate
                )
                guard input.append(sampleBuffer) else {
                    throw FixtureError.appendFailed
                }
                samplesWritten += chunkSize
            }
        }

        private static func makeAudioChunk(
            formatDesc: CMAudioFormatDescription,
            chunkSize: Int,
            samplesWritten: Int,
            sampleRate: Double
        ) throws -> CMSampleBuffer {
            let dataSize = chunkSize * 2
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
            guard let blockBuffer else {
                throw FixtureError.blockBufferFailed
            }

            fillSineWave(
                blockBuffer: blockBuffer,
                sampleCount: chunkSize,
                startSample: samplesWritten,
                sampleRate: sampleRate
            )

            let pts = CMTime(
                value: CMTimeValue(samplesWritten),
                timescale: CMTimeScale(sampleRate)
            )
            var sampleBuffer: CMSampleBuffer?
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: kCFAllocatorDefault,
                dataBuffer: blockBuffer,
                formatDescription: formatDesc,
                sampleCount: CMItemCount(chunkSize),
                presentationTimeStamp: pts,
                packetDescriptions: nil,
                sampleBufferOut: &sampleBuffer
            )
            guard let sampleBuffer else {
                throw FixtureError.sampleBufferFailed
            }
            return sampleBuffer
        }

        private static func fillSineWave(
            blockBuffer: CMBlockBuffer,
            sampleCount: Int,
            startSample: Int,
            sampleRate: Double
        ) {
            let dataSize = sampleCount * 2
            var tempData = Data(count: dataSize)
            tempData.withUnsafeMutableBytes { rawBuffer in
                let int16Buffer = rawBuffer.bindMemory(
                    to: Int16.self
                )
                for i in 0..<sampleCount {
                    let phase =
                        2.0 * Double.pi * 440.0
                        * Double(startSample + i) / sampleRate
                    int16Buffer[i] = Int16(
                        sin(phase) * 16_000
                    )
                }
            }
            tempData.withUnsafeBytes { rawBuffer in
                guard
                    let baseAddress = rawBuffer
                        .baseAddress
                else { return }
                CMBlockBufferReplaceDataBytes(
                    with: baseAddress,
                    blockBuffer: blockBuffer,
                    offsetIntoDestination: 0,
                    dataLength: dataSize
                )
            }
        }

        /// Errors from fixture generation.
        enum FixtureError: Error {
            case pixelBufferFailed
            case formatDescFailed
            case blockBufferFailed
            case sampleBufferFailed
            case appendFailed
            case writerFailed(String)
        }
    }

#endif
