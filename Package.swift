// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "swift-hls-kit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .watchOS(.v10),
        .visionOS(.v1),
        .macCatalyst(.v17)
    ],
    products: [
        .library(
            name: "HLSKit",
            targets: ["HLSKit"]),
        .executable(
            name: "hlskit-cli",
            targets: ["HLSKitCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.0")
    ],
    targets: [
        .target(
            name: "HLSKit"),
        .target(
            name: "HLSKitCommands",
            dependencies: [
                "HLSKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]),
        .executableTarget(
            name: "HLSKitCLI",
            dependencies: ["HLSKitCommands"]),
        .testTarget(
            name: "HLSKitTests",
            dependencies: ["HLSKit"]),
        .testTarget(
            name: "HLSKitCommandsTests",
            dependencies: ["HLSKitCommands"])
    ]
)
