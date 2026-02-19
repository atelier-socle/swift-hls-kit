// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import HLSKitCommands

@main
@available(macOS 14, iOS 17, tvOS 17, watchOS 10, macCatalyst 17, visionOS 1, *)
struct HLSKitCLI {
    static func main() async {
        await HLSKitCommand.main()
    }
}
