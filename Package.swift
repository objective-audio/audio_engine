// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "audio",
    platforms: [.macOS(.v14), .iOS(.v17), .macCatalyst(.v17)],
    products: [
        .library(
            name: "audio",
            targets: ["audio-engine", "audio-processing"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/objective-audio/cpp_utils.git", branch: "master"),
    ],
    targets: [
        .target(
            name: "audio-engine",
            dependencies: [
                .product(name: "cpp-utils", package: "cpp_utils")
            ],
            cSettings: [
                .define("ACCELERATE_NEW_LAPACK", to: "1"),
                .define("ACCELERATE_LAPACK_ILP64", to: "1"),
            ],
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AudioToolbox"),
                .linkedFramework("Accelerate"),
                .linkedFramework("CoreAudio", .when(platforms: [.macOS]))
            ]
        ),
        .target(
            name: "audio-processing",
            dependencies: [
                "audio-engine"
            ],
            cSettings: [
                .unsafeFlags(["-fmodules"]),
            ]
        ),
        .testTarget(
            name: "audio-engine-tests",
            dependencies: [
                "audio-engine"
            ],
            cxxSettings: [
                .define("WAVEFILE_LIGHT_TEST", to: "1"),
                .unsafeFlags(["-fcxx-modules"]),
            ]),
        .testTarget(
            name: "audio-processing-tests",
            dependencies: [
                "audio-processing",
            ],
            cxxSettings: [
                .unsafeFlags(["-fcxx-modules"]),
            ]
        ),
    ],
    cLanguageStandard: .gnu18,
    cxxLanguageStandard: .gnucxx2b
)
