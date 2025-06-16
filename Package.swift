// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "gitlab-mcp-swift",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "git-lab-mcp", targets: ["GitLabMCP"]),
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "GitLabMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)