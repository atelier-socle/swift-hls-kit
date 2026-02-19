// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import HLSKitCommands

@main
struct CLI {
    static func main() async throws {
        await HLSKitCommand.main()
    }
}
