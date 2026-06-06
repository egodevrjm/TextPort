// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TextPort",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TextPort", targets: ["TextPort"])
    ],
    targets: [
        .executableTarget(name: "TextPort")
    ]
)
