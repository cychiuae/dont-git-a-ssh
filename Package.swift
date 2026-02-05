// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DontGitASsh",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DontGitASsh",
            targets: ["DontGitASsh"]
        )
    ],
    targets: [
        .executableTarget(
            name: "DontGitASsh",
            path: "DontGitASsh"
        ),
        .testTarget(
            name: "DontGitASshTests",
            dependencies: ["DontGitASsh"],
            path: "DontGitASshTests"
        )
    ]
)
