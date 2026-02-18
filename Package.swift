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
            targets: ["HLSKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.3")
    ],
    targets: [
        .target(
            name: "HLSKit"),
        .testTarget(
            name: "HLSKitTests",
            dependencies: ["HLSKit"])
    ]
)
