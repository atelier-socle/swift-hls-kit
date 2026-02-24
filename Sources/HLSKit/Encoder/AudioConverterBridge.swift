// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AudioToolbox)

    import AudioToolbox
    import Foundation

    // MARK: - Converter Context

    /// Encapsulates AudioConverter buffer fill logic.
    ///
    /// Bridges the C-style `AudioConverterFillComplexBuffer` API into
    /// a Swift-friendly `convert(input:)` call.
    struct AudioConverterBridge {
        let converter: AudioConverterRef
        let channels: Int
        private let maxOutputSize = 8192

        /// Converts PCM input data to AAC using the converter.
        ///
        /// - Parameter input: PCM data to encode (consumed on success).
        /// - Returns: Encoded AAC data, or nil if conversion produced
        ///   no output.
        mutating func convert(input: inout Data) -> Data? {
            var outputBuffer = Data(count: maxOutputSize)
            var packetDesc = AudioStreamPacketDescription()
            var numPackets: UInt32 = 1

            let status = fill(
                input: &input,
                output: &outputBuffer,
                packetDesc: &packetDesc,
                numPackets: &numPackets
            )

            guard status == noErr, numPackets > 0 else { return nil }
            let size = Int(packetDesc.mDataByteSize)
            guard size > 0 else { return nil }
            return Data(outputBuffer.prefix(size))
        }

        private func fill(
            input: inout Data,
            output: inout Data,
            packetDesc: inout AudioStreamPacketDescription,
            numPackets: inout UInt32
        ) -> OSStatus {
            let ch = channels
            let outSize = maxOutputSize
            let ref = converter
            return output.withUnsafeMutableBytes { outPtr in
                guard let base = outPtr.baseAddress else {
                    return OSStatus(-1)
                }
                var bufList = AudioBufferList(
                    mNumberBuffers: 1,
                    mBuffers: AudioBuffer(
                        mNumberChannels: UInt32(ch),
                        mDataByteSize: UInt32(outSize),
                        mData: base
                    )
                )
                return input.withUnsafeMutableBytes { inPtr in
                    var ud = CallbackUserData(
                        data: inPtr.baseAddress,
                        dataSize: UInt32(inPtr.count),
                        bytesPerFrame: UInt32(2 * ch)
                    )
                    return withUnsafeMutablePointer(to: &ud) { p in
                        AudioConverterFillComplexBuffer(
                            ref, converterInputCallback, p,
                            &numPackets, &bufList, &packetDesc
                        )
                    }
                }
            }
        }
    }

    // MARK: - Input Callback

    /// User data passed to the AudioConverter input callback.
    private struct CallbackUserData {
        var data: UnsafeMutableRawPointer?
        var dataSize: UInt32
        var bytesPerFrame: UInt32
    }

    /// AudioConverter input data callback — provides PCM data on demand.
    ///
    /// Returns `-1` when no more data is available, which signals
    /// `AudioConverterFillComplexBuffer` to stop requesting input.
    private func converterInputCallback(
        _: AudioConverterRef,
        _ ioPackets: UnsafeMutablePointer<UInt32>,
        _ ioData: UnsafeMutablePointer<AudioBufferList>,
        _ outDesc: UnsafeMutablePointer<
            UnsafeMutablePointer<AudioStreamPacketDescription>?
        >?,
        _ inUserData: UnsafeMutableRawPointer?
    ) -> OSStatus {
        guard let ptr = inUserData else {
            ioPackets.pointee = 0
            return -1
        }

        let ud = ptr.assumingMemoryBound(to: CallbackUserData.self)

        if ud.pointee.dataSize == 0 {
            ioPackets.pointee = 0
            return -1
        }

        ioData.pointee.mNumberBuffers = 1
        ioData.pointee.mBuffers.mData = ud.pointee.data
        ioData.pointee.mBuffers.mDataByteSize = ud.pointee.dataSize
        ioData.pointee.mBuffers.mNumberChannels = 1

        // Frames = totalBytes / bytesPerFrame (2 * channels)
        let bpf = max(ud.pointee.bytesPerFrame, 1)
        ioPackets.pointee = ud.pointee.dataSize / bpf
        outDesc?.pointee = nil
        ud.pointee.dataSize = 0

        return noErr
    }

#endif
