// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mic-mute-mac",
    
    platforms: [
        .macOS(.v15)
    ],

    products: [
        .executable(
            name: "mic-mute-mac",
            targets: ["mic-mute-mac"]
        )
    ],

    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "mic-mute-mac",
            path: "Sources"
        )
    ]
)
