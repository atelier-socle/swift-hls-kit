# Testing Guide

Understand the test architecture, run the full suite, use the mock HLS server, and write new tests that follow HLSKit conventions.

@Metadata {
    @PageKind(article)
}

## Overview

HLSKit maintains 5,127 tests across the entire test suite, covering manifest parsing, generation, validation, segmentation, transcoding, encryption, live pipeline, transport contracts, spatial video, IMSC1 subtitles, variable substitution, and CLI operations. The project uses the Swift Testing framework exclusively — no XCTest.

## Test Structure

The test target `HLSKitTests` is organized into subdirectories that mirror the library's architecture. Each directory groups tests by feature domain:

| Directory | Purpose | Example |
|-----------|---------|---------|
| `ManifestTests/` | Parser, generator, validator | Tag parsing, round-trips |
| `SegmentationTests/` | MP4/TS segmenter | fMP4 box structure |
| `TranscodingTests/` | Encoding pipelines | Preset validation |
| `EncryptionTests/` | AES-128, SAMPLE-AES | Key management |
| `ContainerTests/` | MP4 box parsing | Binary reader/writer |
| `LivePipelineTests/` | Pipeline, LL-HLS | Transport orchestration |
| `PushTests/` | Transport protocols | RTMP/SRT/Icecast |
| `SpatialTests/` | MV-HEVC, projection | NALU extraction |
| `SubtitleTests/` | IMSC1 parser/renderer | TTML round-trip |
| `ShowcaseTests/` | End-to-end examples | API demonstrations |
| `CLITests/` | Command-line tool | Argument parsing |
| `IntegrationTests/` | Cross-module workflows | Full pipelines |

Each subdirectory contains `@Suite`-annotated structs. Related test helpers and mocks live in the same file as the tests that use them, keeping each file self-contained.

## Running Tests

### Swift Package Manager

```bash
# Run all tests
swift test

# Run a specific test suite
swift test --filter HLSKitTests

# Run tests matching a pattern
swift test --filter "ManifestParser"
```

### Xcode

```bash
# Build and test with Xcode
xcodebuild -scheme swift-hls-kit-Package \
    -destination 'platform=macOS' \
    clean build test

# Code coverage
swift test --enable-code-coverage
xcrun llvm-cov report .build/debug/swift-hls-kitPackageTests.xctest/Contents/MacOS/swift-hls-kitPackageTests \
    -instr-profile .build/debug/codecov/default.profdata \
    -ignore-filename-regex '.build|Tests'
```

## Mock HLS Server

`Scripts/mock-hls-server.py` is a Python-based test server that simulates HLS infrastructure for integration testing. It supports 5 operating modes:

| Mode | Description |
|------|-------------|
| `serve` | Serve in-memory HLS content for parsing and validation |
| `push` | Accept HTTP PUT/POST segment uploads |
| `live` | Simulate a live HLS origin with growing playlists |
| `multi` | Multi-destination mode for failover testing |
| `spatial` | Serve spatial video manifests with REQ-VIDEO-LAYOUT |

Start the server:

```bash
python3 Scripts/mock-hls-server.py --mode serve --port 8080
python3 Scripts/mock-hls-server.py --mode push --port 8081
python3 Scripts/mock-hls-server.py --mode live --port 8082
```

The server generates all content in memory — no `--directory` flag is needed. It also supports failure simulation via `--fail` for testing resilience:

- `--fail 403` / `--fail 500` — HTTP error codes
- `--fail timeout` / `--fail slow` — Delayed or hung responses
- `--fail disconnect` — Connection drops
- `--fail intermittent --fail-rate N` — Fail every Nth request

## CLI Scenario Runner

`Scripts/run-cli-scenarios.sh` automates 38 CLI test scenarios covering all 10 commands (`info`, `segment`, `transcode`, `validate`, `encrypt`, `manifest`, `live`, `iframe`, `imsc1`, `mvhevc`):

```bash
# Run all scenarios
Scripts/run-cli-scenarios.sh

# Skip building (when already built)
Scripts/run-cli-scenarios.sh --skip-build

# Keep temporary files for debugging
Scripts/run-cli-scenarios.sh --keep-temp
```

Each scenario tests a specific command with known inputs and validates the output. The runner reports PASS/FAIL per scenario and a summary at the end.

## Writing Tests

HLSKit uses Swift Testing exclusively. Every test file follows these conventions:

```swift
// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Feature Name — Aspect Being Tested")
struct FeatureNameTests {

    @Test("Descriptive test name explaining expected behavior")
    func testMethodName() throws {
        // Arrange
        let input = ...

        // Act
        let result = try SomeType().someMethod(input)

        // Assert
        #expect(result.property == expectedValue)
    }
}
```

Key conventions:

- `@Suite("Description")` groups related tests
- `@Test("Description")` provides a human-readable test name
- `#expect(condition)` for assertions — never `XCTAssert`
- `try #require(value)` for unwrapping optionals that must succeed
- `.timeLimit(.minutes(1))` on suites with async operations
- No force unwrapping (`!`) — use `guard let` or `try #require`
- SPDX license header on every file

## Showcase Tests as Documentation

The 10 showcase test files in `Tests/HLSKitTests/ShowcaseTests/` serve as the source of truth for all DocC code examples. Every code snippet in the documentation is extracted from a passing showcase test. This ensures examples stay accurate as the API evolves.

Showcase test files cover:

- `IMSC1ShowcaseTests.swift` — IMSC1 subtitle pipeline
- `MVHEVCShowcaseTests.swift` — MV-HEVC spatial video packaging
- `ProjectionShowcaseTests.swift` — Video projection and layout descriptors
- `VariableSubstitutionShowcaseTests.swift` — EXT-X-DEFINE and variable resolution
- `TransportQualityShowcaseTests.swift` — Quality monitoring and grades
- `TransportAwarePipelineShowcaseTests.swift` — Pipeline + transport integration
- `RTMPTransportV2ShowcaseTests.swift` — RTMP v2 presets and capabilities
- `SRTTransportV2ShowcaseTests.swift` — SRT v2 FEC, bonding, congestion
- `IcecastTransportV2ShowcaseTests.swift` — Icecast auth modes and server presets
- `FullPipelineShowcaseTests.swift` — End-to-end integration scenarios

## Next Steps

- <doc:GettingStarted> — Quick start guide
- <doc:CLIReference> — CLI command reference
