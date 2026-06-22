// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Clarion",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "ClarionKit",
            targets: ["ClarionKit"]
        ),
        .executable(
            name: "clarion",
            targets: ["clarion"]
        ),
        .executable(
            name: "clarion-package",
            targets: ["ClarionPackage"]
        ),
    ],
    targets: [
        .target(
            name: "ClarionKit"
        ),
        .executableTarget(
            name: "clarion",
            dependencies: ["ClarionKit"]
        ),
        .executableTarget(
            name: "ClarionPackage",
            dependencies: ["ClarionKit"]
        ),
        .testTarget(
            name: "ClarionKitTests",
            dependencies: ["ClarionKit"]
        ),
    ]
)
