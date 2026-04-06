// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MovingPaper",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "MovingPaper", targets: ["MovingPaper"]),
    ],
    targets: [
        .executableTarget(
            name: "MovingPaper",
            path: "sources",
            resources: [
                .copy("Resources"),
            ],
            swiftSettings: [
                .unsafeFlags([
                    "-F",
                    "tools/sparkle",
                ]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F",
                    "tools/sparkle",
                    "-framework",
                    "Sparkle",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../Frameworks",
                    "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../../../tools/sparkle",
                    "-Xlinker", "-rpath", "-Xlinker", "@loader_path/../../../tools/sparkle",
                ]),
            ]
        ),
        .testTarget(
            name: "MovingPaperTests",
            path: "tests"
        ),
    ]
)
