// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Generates synthetic raw video data for encoder testing.
///
/// Produces YUV420p pixel data (solid color or gradient frames),
/// suitable for feeding to ``VideoEncoder`` or ``FFmpegVideoEncoder``.
enum VideoTestDataGenerator {

    /// Generate a single YUV420p frame with a solid color.
    ///
    /// YUV420p layout: Y plane (width×height), then U plane
    /// (width/2 × height/2), then V plane (width/2 × height/2).
    ///
    /// - Parameters:
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    ///   - y: Y (luma) value (0-255). Default 128.
    ///   - u: U (Cb) value (0-255). Default 128 (neutral).
    ///   - v: V (Cr) value (0-255). Default 128 (neutral).
    /// - Returns: Raw YUV420p data (width × height × 3/2 bytes).
    static func generateYUV420Frame(
        width: Int = 320,
        height: Int = 240,
        y: UInt8 = 128,
        u: UInt8 = 128,
        v: UInt8 = 128
    ) -> Data {
        let ySize = width * height
        let uvWidth = width / 2
        let uvHeight = height / 2
        let uvSize = uvWidth * uvHeight
        let totalSize = ySize + uvSize * 2

        var data = Data(capacity: totalSize)

        // Y plane
        data.append(Data(repeating: y, count: ySize))
        // U plane
        data.append(Data(repeating: u, count: uvSize))
        // V plane
        data.append(Data(repeating: v, count: uvSize))

        return data
    }

    /// Generate a YUV420p frame with a vertical gradient.
    ///
    /// Creates a gradient from dark to light (top to bottom)
    /// for visual verification in encoded output.
    ///
    /// - Parameters:
    ///   - width: Frame width in pixels.
    ///   - height: Frame height in pixels.
    /// - Returns: Raw YUV420p data with gradient pattern.
    static func generateGradientFrame(
        width: Int = 320,
        height: Int = 240
    ) -> Data {
        let ySize = width * height
        let uvWidth = width / 2
        let uvHeight = height / 2
        let uvSize = uvWidth * uvHeight
        let totalSize = ySize + uvSize * 2

        var data = Data(capacity: totalSize)

        // Y plane: gradient top to bottom
        for row in 0..<height {
            let value = UInt8(row * 255 / max(height - 1, 1))
            data.append(Data(repeating: value, count: width))
        }
        // U and V planes: neutral
        data.append(Data(repeating: 128, count: uvSize * 2))

        return data
    }

    /// Expected byte count for a YUV420p frame.
    ///
    /// - Parameters:
    ///   - width: Frame width.
    ///   - height: Frame height.
    /// - Returns: Total byte count (width × height × 3/2).
    static func frameSize(width: Int, height: Int) -> Int {
        width * height * 3 / 2
    }

    /// Create a ``RawMediaBuffer`` with synthetic YUV420p video data.
    ///
    /// - Parameters:
    ///   - width: Frame width in pixels. Default 320.
    ///   - height: Frame height in pixels. Default 240.
    ///   - timestamp: Presentation timestamp. Default is zero.
    ///   - duration: Frame duration in seconds. Default 1/30.
    ///   - isKeyframe: Whether this buffer is a keyframe.
    /// - Returns: A raw media buffer containing YUV420p data.
    static func makeBuffer(
        width: Int = 320,
        height: Int = 240,
        timestamp: MediaTimestamp = .zero,
        duration: TimeInterval = 1.0 / 30.0,
        isKeyframe: Bool = true
    ) -> RawMediaBuffer {
        let data = generateYUV420Frame(
            width: width, height: height
        )
        return RawMediaBuffer(
            data: data,
            timestamp: timestamp,
            duration: MediaTimestamp(seconds: duration),
            isKeyframe: isKeyframe,
            mediaType: .video,
            formatInfo: .video(
                codec: .h264, width: width, height: height
            )
        )
    }

    /// Create multiple sequential video buffers.
    ///
    /// Generates a series of frames with incrementing timestamps
    /// and periodic keyframes.
    ///
    /// - Parameters:
    ///   - count: Number of frames. Default 30.
    ///   - width: Frame width. Default 320.
    ///   - height: Frame height. Default 240.
    ///   - fps: Frame rate. Default 30.
    ///   - keyframeInterval: Frames between keyframes. Default 30.
    /// - Returns: Array of sequential raw media buffers.
    static func makeBuffers(
        count: Int = 30,
        width: Int = 320,
        height: Int = 240,
        fps: Double = 30.0,
        keyframeInterval: Int = 30
    ) -> [RawMediaBuffer] {
        let frameDuration = 1.0 / fps
        return (0..<count).map { index in
            let luma = UInt8((index * 4) % 256)
            let data = generateYUV420Frame(
                width: width, height: height, y: luma
            )
            return RawMediaBuffer(
                data: data,
                timestamp: MediaTimestamp(
                    seconds: Double(index) * frameDuration
                ),
                duration: MediaTimestamp(seconds: frameDuration),
                isKeyframe: index % keyframeInterval == 0,
                mediaType: .video,
                formatInfo: .video(
                    codec: .h264, width: width, height: height
                )
            )
        }
    }
}
