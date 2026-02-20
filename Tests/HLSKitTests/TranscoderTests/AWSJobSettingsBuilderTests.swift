// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AWSJobSettingsBuilder")
struct AWSJobSettingsBuilderTests {

    @Test("buildJobJSON includes HLS output group")
    func hlsOutputGroup() {
        let json = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://bucket/input/source.mp4",
            outputS3Path: "s3://bucket/output/",
            roleARN: "arn:aws:iam::123:role/Test",
            variants: [.p720],
            outputFormat: .fmp4
        )

        let settings = json["Settings"] as? [String: Any]
        let groups =
            settings?["OutputGroups"] as? [[String: Any]]
        let groupSettings =
            groups?.first?["OutputGroupSettings"]
            as? [String: Any]
        let groupType = groupSettings?["Type"] as? String

        #expect(groupType == "HLS_GROUP_SETTINGS")
    }

    @Test("maps p720 preset to 1280x720 resolution")
    func p720Resolution() {
        let json = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://b/in.mp4",
            outputS3Path: "s3://b/out/",
            roleARN: "arn",
            variants: [.p720],
            outputFormat: .fmp4
        )

        let videoDesc = extractFirstVideoDescription(json)
        #expect(videoDesc?["Width"] as? Int == 1280)
        #expect(videoDesc?["Height"] as? Int == 720)
    }

    @Test("maps p1080 preset to 1920x1080")
    func p1080Resolution() {
        let json = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://b/in.mp4",
            outputS3Path: "s3://b/out/",
            roleARN: "arn",
            variants: [.p1080],
            outputFormat: .fmp4
        )

        let videoDesc = extractFirstVideoDescription(json)
        #expect(videoDesc?["Width"] as? Int == 1920)
        #expect(videoDesc?["Height"] as? Int == 1080)
    }

    @Test("multiple variants produce multiple outputs")
    func multipleVariants() {
        let json = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://b/in.mp4",
            outputS3Path: "s3://b/out/",
            roleARN: "arn",
            variants: [.p360, .p720, .p1080],
            outputFormat: .fmp4
        )

        let outputs = extractOutputs(json)
        #expect(outputs?.count == 3)
    }

    @Test("sets correct S3 input path")
    func inputPath() {
        let json = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://my-bucket/input/abc/source.mp4",
            outputS3Path: "s3://b/out/",
            roleARN: "arn",
            variants: [.p720],
            outputFormat: .fmp4
        )

        let settings = json["Settings"] as? [String: Any]
        let inputs =
            settings?["Inputs"] as? [[String: Any]]
        let fileInput =
            inputs?.first?["FileInput"] as? String

        #expect(
            fileInput
                == "s3://my-bucket/input/abc/source.mp4"
        )
    }

    @Test("sets correct S3 output destination")
    func outputDestination() {
        let json = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://b/in.mp4",
            outputS3Path: "s3://my-bucket/output/abc/",
            roleARN: "arn",
            variants: [.p720],
            outputFormat: .fmp4
        )

        let settings = json["Settings"] as? [String: Any]
        let groups =
            settings?["OutputGroups"] as? [[String: Any]]
        let groupSettings =
            groups?.first?["OutputGroupSettings"]
            as? [String: Any]
        let hlsSettings =
            groupSettings?["HlsGroupSettings"]
            as? [String: Any]
        let destination =
            hlsSettings?["Destination"] as? String

        #expect(
            destination == "s3://my-bucket/output/abc/"
        )
    }

    @Test("includes IAM role ARN")
    func roleARN() {
        let json = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://b/in.mp4",
            outputS3Path: "s3://b/out/",
            roleARN: "arn:aws:iam::123456789:role/MC",
            variants: [.p720],
            outputFormat: .fmp4
        )

        let role = json["Role"] as? String
        #expect(role == "arn:aws:iam::123456789:role/MC")
    }

    @Test("audio-only preset omits video description")
    func audioOnlyNoVideo() {
        let json = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://b/in.mp4",
            outputS3Path: "s3://b/out/",
            roleARN: "arn",
            variants: [.audioOnly],
            outputFormat: .fmp4
        )

        let outputs = extractOutputs(json)
        let firstOutput = outputs?.first
        let videoDesc =
            firstOutput?["VideoDescription"]
            as? [String: Any]
        #expect(videoDesc == nil)
    }

    // MARK: - Helpers

    private func extractFirstVideoDescription(
        _ json: [String: Any]
    ) -> [String: Any]? {
        let outputs = extractOutputs(json)
        return outputs?.first?["VideoDescription"]
            as? [String: Any]
    }

    private func extractOutputs(
        _ json: [String: Any]
    ) -> [[String: Any]]? {
        let settings = json["Settings"] as? [String: Any]
        let groups =
            settings?["OutputGroups"] as? [[String: Any]]
        return groups?.first?["Outputs"]
            as? [[String: Any]]
    }
}
