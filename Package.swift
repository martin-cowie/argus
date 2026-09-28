// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Argus",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Argus", targets: ["Argus"])
    ],
    targets: [
        .executableTarget(name: "Argus", resources: [.process("Resources")]),
        .testTarget(name: "ArgusTests", dependencies: ["Argus"])
    ]
)
