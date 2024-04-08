// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "audio",
    platforms: [.macOS(.v10_15), .iOS(.v13), .macCatalyst(.v13)],
    products: [
        .library(
            name: "audio",
            targets: ["audio"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/objective-audio/observing.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "audio",
            dependencies: [
                .product(name: "observing", package: "observing")
            ],
            cSettings: [
                .unsafeFlags(["-fmodules"]),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreAudio", .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "audio-tests",
            dependencies: [
                "audio"
            ],
            cxxSettings: [
                .define("WAVEFILE_LIGHT_TEST", to: "1"),
                .unsafeFlags(["-fcxx-modules"]),
            ]),
    ],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx2b
)
