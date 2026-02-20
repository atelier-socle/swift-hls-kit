// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ManagedTranscodingConfig")
struct ManagedTranscodingConfigTests {

    // MARK: - Default Values

    @Test("Default config values")
    func defaults() {
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "key",
            accountID: "acct"
        )
        #expect(config.provider == .cloudflareStream)
        #expect(config.apiKey == "key")
        #expect(config.accountID == "acct")
        #expect(config.endpoint == nil)
        #expect(config.region == nil)
        #expect(config.storageBucket == nil)
        #expect(config.roleARN == nil)
        #expect(config.pollingInterval == 5)
        #expect(config.timeout == 3600)
        #expect(config.cleanupAfterDownload)
        #expect(config.outputFormat == .fmp4)
    }

    // MARK: - Custom Values

    @Test("Custom config values")
    func customValues() throws {
        let endpoint = try #require(
            URL(string: "https://custom.api.com")
        )
        let config = ManagedTranscodingConfig(
            provider: .awsMediaConvert,
            apiKey: "aws-key",
            accountID: "aws-acct",
            endpoint: endpoint,
            region: "us-east-1",
            storageBucket: "my-bucket",
            roleARN: "arn:aws:iam::role/Test",
            pollingInterval: 10,
            timeout: 7200,
            cleanupAfterDownload: false,
            outputFormat: .ts
        )
        #expect(config.provider == .awsMediaConvert)
        #expect(config.endpoint == endpoint)
        #expect(config.region == "us-east-1")
        #expect(config.storageBucket == "my-bucket")
        #expect(config.roleARN == "arn:aws:iam::role/Test")
        #expect(config.pollingInterval == 10)
        #expect(config.timeout == 7200)
        #expect(!config.cleanupAfterDownload)
        #expect(config.outputFormat == .ts)
    }

    // MARK: - ProviderType

    @Test("ProviderType raw values")
    func providerTypeRawValues() {
        #expect(
            ManagedTranscodingConfig.ProviderType
                .cloudflareStream.rawValue
                == "cloudflareStream"
        )
        #expect(
            ManagedTranscodingConfig.ProviderType
                .awsMediaConvert.rawValue
                == "awsMediaConvert"
        )
        #expect(
            ManagedTranscodingConfig.ProviderType.mux
                .rawValue == "mux"
        )
    }

    @Test("ProviderType Codable round-trip")
    func providerTypeCodable() throws {
        let types: [ManagedTranscodingConfig.ProviderType] = [
            .cloudflareStream, .awsMediaConvert, .mux
        ]
        for type in types {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(
                ManagedTranscodingConfig.ProviderType.self,
                from: data
            )
            #expect(decoded == type)
        }
    }

    @Test("ProviderType Hashable")
    func providerTypeHashable() {
        let set: Set<ManagedTranscodingConfig.ProviderType> = [
            .cloudflareStream, .awsMediaConvert, .mux,
            .cloudflareStream
        ]
        #expect(set.count == 3)
    }

    // MARK: - OutputFormat

    @Test("OutputFormat raw values")
    func outputFormatRawValues() {
        #expect(
            ManagedTranscodingConfig.OutputFormat.fmp4
                .rawValue == "fmp4"
        )
        #expect(
            ManagedTranscodingConfig.OutputFormat.ts
                .rawValue == "ts"
        )
    }

    @Test("OutputFormat Codable round-trip")
    func outputFormatCodable() throws {
        let formats: [ManagedTranscodingConfig.OutputFormat] = [
            .fmp4, .ts
        ]
        for format in formats {
            let data = try JSONEncoder().encode(format)
            let decoded = try JSONDecoder().decode(
                ManagedTranscodingConfig.OutputFormat.self,
                from: data
            )
            #expect(decoded == format)
        }
    }

    @Test("OutputFormat Hashable")
    func outputFormatHashable() {
        let set: Set<ManagedTranscodingConfig.OutputFormat> = [
            .fmp4, .ts, .fmp4
        ]
        #expect(set.count == 2)
    }

    // MARK: - Mutability

    @Test("Config is mutable")
    func mutability() {
        var config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "key",
            accountID: "acct"
        )
        config.provider = .mux
        config.apiKey = "new-key"
        config.pollingInterval = 30
        config.timeout = 600
        config.cleanupAfterDownload = false
        config.outputFormat = .ts

        #expect(config.provider == .mux)
        #expect(config.apiKey == "new-key")
        #expect(config.pollingInterval == 30)
        #expect(config.timeout == 600)
        #expect(!config.cleanupAfterDownload)
        #expect(config.outputFormat == .ts)
    }
}
