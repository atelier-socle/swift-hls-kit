// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - ContentSteeringConfig

@Suite("ContentSteeringConfig — Configuration")
struct ContentSteeringConfigTests {

    @Test("Init sets all properties")
    func initProperties() {
        let config = ContentSteeringConfig(
            serverURI: "https://steering.example.com/manifest",
            pathways: ["CDN-A", "CDN-B"],
            defaultPathway: "CDN-A"
        )
        #expect(config.serverURI == "https://steering.example.com/manifest")
        #expect(config.pathways.count == 2)
        #expect(config.defaultPathway == "CDN-A")
        #expect(config.pollingInterval == 10)
    }

    @Test("Custom polling interval")
    func customPolling() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["A"],
            defaultPathway: "A",
            pollingInterval: 30
        )
        #expect(config.pollingInterval == 30)
    }

    @Test("steeringTag generates correct format")
    func steeringTag() {
        let config = ContentSteeringConfig(
            serverURI: "https://steering.example.com/manifest",
            pathways: ["CDN-A", "CDN-B"],
            defaultPathway: "CDN-A"
        )
        let tag = config.steeringTag()
        #expect(tag == "#EXT-X-CONTENT-STEERING:SERVER-URI=\"https://steering.example.com/manifest\",PATHWAY-ID=\"CDN-A\"")
    }

    @Test("steeringManifest generates valid JSON")
    func steeringManifestDefault() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["CDN-A", "CDN-B"],
            defaultPathway: "CDN-A",
            pollingInterval: 10
        )
        let json = config.steeringManifest()
        #expect(json.contains("\"VERSION\":1"))
        #expect(json.contains("\"TTL\":10"))
        #expect(json.contains("\"PATHWAY-PRIORITY\":[\"CDN-A\",\"CDN-B\"]"))
    }

    @Test("steeringManifest with custom priority")
    func steeringManifestCustomPriority() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["CDN-A", "CDN-B"],
            defaultPathway: "CDN-A"
        )
        let json = config.steeringManifest(pathwayPriority: ["CDN-B", "CDN-A"])
        #expect(json.contains("\"PATHWAY-PRIORITY\":[\"CDN-B\",\"CDN-A\"]"))
    }

    @Test("steeringManifest with custom TTL")
    func steeringManifestCustomTTL() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["A"],
            defaultPathway: "A"
        )
        let json = config.steeringManifest(ttl: 60)
        #expect(json.contains("\"TTL\":60"))
    }

    @Test("Multiple pathways in manifest")
    func multiplePathways() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["CDN-A", "CDN-B", "CDN-C"],
            defaultPathway: "CDN-A"
        )
        let json = config.steeringManifest()
        #expect(json.contains("\"CDN-A\""))
        #expect(json.contains("\"CDN-B\""))
        #expect(json.contains("\"CDN-C\""))
    }
}

// MARK: - Validation

@Suite("ContentSteeringConfig — Validation")
struct ContentSteeringConfigValidationTests {

    @Test("Valid config has no errors")
    func validConfig() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["A"],
            defaultPathway: "A"
        )
        #expect(config.validate().isEmpty)
    }

    @Test("Empty server URI is invalid")
    func emptyServerURI() {
        let config = ContentSteeringConfig(
            serverURI: "",
            pathways: ["A"],
            defaultPathway: "A"
        )
        let errors = config.validate()
        #expect(errors.contains { $0.contains("Server URI is empty") })
    }

    @Test("Empty pathways is invalid")
    func emptyPathways() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: [],
            defaultPathway: "A"
        )
        let errors = config.validate()
        #expect(errors.contains { $0.contains("No pathways") })
    }

    @Test("Default pathway not in list is invalid")
    func defaultNotInList() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["A", "B"],
            defaultPathway: "C"
        )
        let errors = config.validate()
        #expect(errors.contains { $0.contains("not found") })
    }

    @Test("Negative polling interval is invalid")
    func negativePolling() {
        let config = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["A"],
            defaultPathway: "A",
            pollingInterval: -1
        )
        let errors = config.validate()
        #expect(errors.contains { $0.contains("positive") })
    }
}

// MARK: - Equatable

@Suite("ContentSteeringConfig — Equatable")
struct ContentSteeringConfigEquatableTests {

    @Test("Identical configs are equal")
    func identical() {
        let a = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["A"],
            defaultPathway: "A"
        )
        let b = ContentSteeringConfig(
            serverURI: "https://example.com",
            pathways: ["A"],
            defaultPathway: "A"
        )
        #expect(a == b)
    }
}
