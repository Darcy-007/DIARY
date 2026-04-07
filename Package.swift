// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "dAIry",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "dAIry",
            targets: ["dAIry"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck.git", from: "0.12.0"),
        .package(url: "https://github.com/google-gemini/generative-ai-swift.git", from: "0.5.6")
    ],
    targets: [
        .target(
            name: "dAIry",
            dependencies: [
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift")
            ],
            path: "dAIry",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "dAIryTests",
            dependencies: [
                "dAIry",
                "SwiftCheck"
            ],
            path: "dAIryTests"
        )
    ]
)
