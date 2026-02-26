// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation

/// Inject metadata into a live stream.
///
/// Supports ID3-style metadata, EXT-X-DATERANGE, SCTE-35 splice
/// points, and HLS Interstitials.
///
/// ```
/// hlskit live metadata --output /tmp/live/ --title "Track" --artist "Queen"
/// hlskit live metadata --output /tmp/live/ --daterange --daterange-class "com.example.ad" --duration 30
/// hlskit live metadata --output /tmp/live/ --scte35 --duration 60 --id "ad-break-1"
/// hlskit live metadata --output /tmp/live/ --interstitial --asset-url https://cdn.example.com/ad.m3u8
/// ```
struct LiveMetadataCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "metadata",
        abstract: "Inject metadata into a live stream."
    )

    // MARK: - Target

    @Option(name: .long, help: "Live output directory")
    var output: String

    // MARK: - ID3-style metadata

    @Option(name: .long, help: "Track or segment title")
    var title: String?

    @Option(name: .long, help: "Artist name")
    var artist: String?

    @Option(name: .long, help: "Album name")
    var album: String?

    // MARK: - DATERANGE metadata

    @Flag(name: .long, help: "Insert EXT-X-DATERANGE tag")
    var daterange: Bool = false

    @Option(
        name: .long,
        help: "DATERANGE CLASS attribute"
    )
    var daterangeClass: String?

    @Option(
        name: .long,
        help: "DATERANGE planned duration in seconds"
    )
    var duration: Double?

    @Option(
        name: .long,
        help: "DATERANGE ID (auto-generated if omitted)"
    )
    var id: String?

    // MARK: - SCTE-35 ad insertion

    @Flag(name: .long, help: "Insert SCTE-35 splice point")
    var scte35: Bool = false

    @Option(
        name: .long,
        help: "SCTE-35 splice type: out, in (default: out)"
    )
    var spliceType: String = "out"

    // MARK: - Interstitials

    @Flag(name: .long, help: "Insert HLS Interstitial")
    var interstitial: Bool = false

    @Option(name: .long, help: "Interstitial asset URL")
    var assetUrl: String?

    @Option(
        name: .long,
        help: "Interstitial resume offset in seconds"
    )
    var resumeOffset: Double?

    // MARK: - Options

    @Flag(name: .long, help: "Suppress output")
    var quiet: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    // MARK: - Run

    func run() async throws {
        let hasID3 =
            title != nil || artist != nil || album != nil
        let hasAny =
            hasID3 || daterange || scte35 || interstitial

        guard hasAny else {
            printErr(
                "Error: specify at least one metadata type "
                    + "(--title/--artist/--album, --daterange, "
                    + "--scte35, or --interstitial)"
            )
            throw ExitCode(ExitCodes.validationError)
        }

        if scte35 {
            guard
                spliceType == "out"
                    || spliceType == "in"
            else {
                printErr(
                    "Error: --splice-type must be 'out' or 'in'"
                )
                throw ExitCode(ExitCodes.validationError)
            }
        }

        if interstitial {
            guard assetUrl != nil else {
                printErr(
                    "Error: --asset-url is required "
                        + "with --interstitial"
                )
                throw ExitCode(ExitCodes.validationError)
            }
        }

        guard !quiet else { return }

        let formatter = OutputFormatter(from: outputFormat)
        var pairs: [(String, String)] = [
            ("Directory:", output)
        ]

        if hasID3 {
            appendID3Pairs(to: &pairs)
        }
        if daterange {
            appendDateRangePairs(to: &pairs)
        }
        if scte35 {
            appendSCTE35Pairs(to: &pairs)
        }
        if interstitial {
            appendInterstitialPairs(to: &pairs)
        }

        print(
            ColorOutput.bold("Metadata Injection")
        )
        print(formatter.formatKeyValues(pairs))
    }

    // MARK: - Pair Builders

    private func appendID3Pairs(
        to pairs: inout [(String, String)]
    ) {
        pairs.append(("Type:", "ID3 Timed Metadata"))
        if let title { pairs.append(("Title:", title)) }
        if let artist { pairs.append(("Artist:", artist)) }
        if let album { pairs.append(("Album:", album)) }
    }

    private func appendDateRangePairs(
        to pairs: inout [(String, String)]
    ) {
        pairs.append(("Type:", "EXT-X-DATERANGE"))
        if let cls = daterangeClass {
            pairs.append(("CLASS:", cls))
        }
        if let dur = duration {
            pairs.append(("Duration:", "\(dur)s"))
        }
        if let rangeId = id {
            pairs.append(("ID:", rangeId))
        }
    }

    private func appendSCTE35Pairs(
        to pairs: inout [(String, String)]
    ) {
        pairs.append(("Type:", "SCTE-35 Splice"))
        pairs.append(("Splice:", spliceType))
        if let dur = duration {
            pairs.append(("Duration:", "\(dur)s"))
        }
        if let spliceId = id {
            pairs.append(("ID:", spliceId))
        }
    }

    private func appendInterstitialPairs(
        to pairs: inout [(String, String)]
    ) {
        pairs.append(("Type:", "HLS Interstitial"))
        if let url = assetUrl {
            pairs.append(("Asset URL:", url))
        }
        if let offset = resumeOffset {
            pairs.append(
                ("Resume Offset:", "\(offset)s")
            )
        }
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}
