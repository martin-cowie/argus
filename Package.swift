// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "argus",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "argus", targets: ["Argus"])
    ],
    targets: [
        .executableTarget(name: "Argus"),
        .testTarget(name: "ArgusTests", dependencies: ["Argus"])
    ]
)
