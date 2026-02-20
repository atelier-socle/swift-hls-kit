// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Builds MediaConvert job JSON from quality presets.
///
/// Maps ``QualityPreset`` variants to MediaConvert output
/// settings with HLS group output.
///
/// - SeeAlso: ``AWSMediaConvertProvider``
enum AWSJobSettingsBuilder: Sendable {

    /// Build a complete MediaConvert job request body.
    ///
    /// - Parameters:
    ///   - inputS3Path: S3 URI for the source file.
    ///   - outputS3Path: S3 URI for the output destination.
    ///   - roleARN: IAM role ARN for MediaConvert.
    ///   - variants: Quality presets to encode.
    ///   - outputFormat: Container format preference.
    /// - Returns: JSON-serializable dictionary.
    static func buildJobJSON(
        inputS3Path: String,
        outputS3Path: String,
        roleARN: String,
        variants: [QualityPreset],
        outputFormat: ManagedTranscodingConfig.OutputFormat
    ) -> [String: Any] {
        [
            "Role": roleARN,
            "Settings": [
                "Inputs": [buildInput(inputS3Path)],
                "OutputGroups": [
                    buildHLSOutputGroup(
                        outputS3Path: outputS3Path,
                        variants: variants,
                        outputFormat: outputFormat
                    )
                ]
            ] as [String: Any]
        ]
    }
}

// MARK: - Input

extension AWSJobSettingsBuilder {

    private static func buildInput(
        _ s3Path: String
    ) -> [String: Any] {
        [
            "FileInput": s3Path,
            "AudioSelectors": [
                "Audio Selector 1": [
                    "DefaultSelection": "DEFAULT"
                ]
            ],
            "VideoSelector": [:] as [String: Any]
        ]
    }
}

// MARK: - Output Group

extension AWSJobSettingsBuilder {

    private static func buildHLSOutputGroup(
        outputS3Path: String,
        variants: [QualityPreset],
        outputFormat: ManagedTranscodingConfig.OutputFormat
    ) -> [String: Any] {
        [
            "Name": "HLS",
            "OutputGroupSettings": [
                "Type": "HLS_GROUP_SETTINGS",
                "HlsGroupSettings": [
                    "Destination": outputS3Path,
                    "SegmentLength": 6,
                    "MinSegmentLength": 0,
                    "SegmentControl": "SEGMENTED_FILES"
                ] as [String: Any]
            ] as [String: Any],
            "Outputs": variants.map { buildOutput($0) }
        ]
    }

    private static func buildOutput(
        _ preset: QualityPreset
    ) -> [String: Any] {
        var output: [String: Any] = [
            "ContainerSettings": [
                "Container": "M3U8",
                "M3u8Settings": [:] as [String: Any]
            ],
            "AudioDescriptions": [
                buildAudioDescription(preset)
            ],
            "NameModifier": "_\(preset.name)"
        ]

        if let resolution = preset.resolution,
            let bitrate = preset.videoBitrate
        {
            output["VideoDescription"] =
                buildVideoDescription(
                    width: resolution.width,
                    height: resolution.height,
                    bitrate: bitrate
                )
        }

        return output
    }
}

// MARK: - Video

extension AWSJobSettingsBuilder {

    private static func buildVideoDescription(
        width: Int,
        height: Int,
        bitrate: Int
    ) -> [String: Any] {
        [
            "Width": width,
            "Height": height,
            "CodecSettings": [
                "Codec": "H_264",
                "H264Settings": [
                    "RateControlMode": "CBR",
                    "Bitrate": bitrate,
                    "QualityTuningLevel": "SINGLE_PASS_HQ"
                ] as [String: Any]
            ] as [String: Any]
        ]
    }
}

// MARK: - Audio

extension AWSJobSettingsBuilder {

    private static func buildAudioDescription(
        _ preset: QualityPreset
    ) -> [String: Any] {
        let channelMode: String
        switch preset.audioChannels {
        case 1:
            channelMode = "CODING_MODE_1_0"
        default:
            channelMode = "CODING_MODE_2_0"
        }

        return [
            "AudioSourceName": "Audio Selector 1",
            "CodecSettings": [
                "Codec": "AAC",
                "AacSettings": [
                    "Bitrate": preset.audioBitrate,
                    "SampleRate": preset.audioSampleRate,
                    "CodingMode": channelMode
                ] as [String: Any]
            ] as [String: Any]
        ]
    }
}
