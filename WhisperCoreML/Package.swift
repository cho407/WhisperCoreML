// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WhisperCoreML",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "WhisperCoreML",
            targets: ["WhisperCoreML"]),
        .library(
            name: "WhisperCoreMLUtils",
            targets: ["WhisperCoreMLUtils"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/apple/swift-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-collections", from: "1.0.0"),
        .package(url: "https://github.com/marmelroy/Zip.git", from: "2.1.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "WhisperCoreML",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                "Zip"
            ],
            exclude: [
                "README.md",
                "Audio/README.md",
                "Core/README.md",
                "Language/README.md",
                "Models/README.md",
                "Transcription/README.md",
                "Utils/README.md"
            ]),
        .target(
            name: "WhisperCoreMLUtils",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
                .product(name: "Collections", package: "swift-collections")
            ]),
        .testTarget(
            name: "WhisperCoreMLTests",
            dependencies: [
                "WhisperCoreML"
            ]),
        .testTarget(
            name: "WhisperCoreMLUtilsTests",
            dependencies: [
                "WhisperCoreMLUtils"
            ]),
    ]
)
