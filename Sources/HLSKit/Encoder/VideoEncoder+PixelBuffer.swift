// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(VideoToolbox)

    import CoreVideo
    import Foundation
    import VideoToolbox

    // MARK: - Pixel Buffer

    extension VideoEncoder {

        func createPixelBuffer(
            from data: Data, width: Int, height: Int
        ) throws -> CVPixelBuffer {
            var pixelBuffer: CVPixelBuffer?
            let attrs: [CFString: CFTypeRef] = [
                kCVPixelBufferIOSurfacePropertiesKey:
                    [:] as CFDictionary
            ]
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault, width, height,
                kCVPixelFormatType_420YpCbCr8Planar,
                attrs as CFDictionary, &pixelBuffer
            )
            guard status == kCVReturnSuccess,
                let pb = pixelBuffer
            else {
                throw LiveEncoderError.encodingFailed(
                    "CVPixelBufferCreate failed: \(status)"
                )
            }
            copyYUV420Data(
                data, into: pb, width: width, height: height
            )
            return pb
        }

        private func copyYUV420Data(
            _ data: Data, into pb: CVPixelBuffer,
            width: Int, height: Int
        ) {
            CVPixelBufferLockBaseAddress(pb, [])
            defer { CVPixelBufferUnlockBaseAddress(pb, []) }

            let ySize = width * height
            let uvW = width / 2
            let uvH = height / 2

            data.withUnsafeBytes { src in
                guard let srcBase = src.baseAddress else {
                    return
                }
                Self.copyPlane(
                    srcBase, into: pb,
                    plane: 0, offset: 0,
                    size: (width, height)
                )
                Self.copyPlane(
                    srcBase, into: pb,
                    plane: 1, offset: ySize,
                    size: (uvW, uvH)
                )
                Self.copyPlane(
                    srcBase, into: pb,
                    plane: 2, offset: ySize + uvW * uvH,
                    size: (uvW, uvH)
                )
            }
        }

        private static func copyPlane(
            _ src: UnsafeRawPointer,
            into pb: CVPixelBuffer,
            plane: Int, offset: Int,
            size: (w: Int, h: Int)
        ) {
            guard
                let base =
                    CVPixelBufferGetBaseAddressOfPlane(pb, plane)
            else { return }
            let stride =
                CVPixelBufferGetBytesPerRowOfPlane(pb, plane)
            for row in 0..<size.h {
                memcpy(
                    base + row * stride,
                    src + offset + row * size.w,
                    size.w
                )
            }
        }
    }

    // MARK: - Profile Level Mapping

    extension VideoEncoder {

        func profileLevel(
            for codec: VideoCodec,
            profile: VideoProfile?
        ) -> CFString? {
            switch codec {
            case .h264:
                return h264ProfileLevel(profile)
            case .h265:
                return hevcProfileLevel(profile)
            case .av1, .vp9:
                return nil
            }
        }

        private func h264ProfileLevel(
            _ profile: VideoProfile?
        ) -> CFString {
            switch profile {
            case .baseline:
                return kVTProfileLevel_H264_Baseline_AutoLevel
            case .main:
                return kVTProfileLevel_H264_Main_AutoLevel
            case .high, .none:
                return kVTProfileLevel_H264_High_AutoLevel
            case .mainHEVC, .main10HEVC:
                return kVTProfileLevel_H264_High_AutoLevel
            }
        }

        private func hevcProfileLevel(
            _ profile: VideoProfile?
        ) -> CFString {
            switch profile {
            case .main10HEVC:
                return kVTProfileLevel_HEVC_Main10_AutoLevel
            default:
                return kVTProfileLevel_HEVC_Main_AutoLevel
            }
        }
    }

#endif
