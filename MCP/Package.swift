// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PinboardMCP",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "pinboard-mcp", targets: ["PinboardMCP"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/modelcontextprotocol/swift-sdk.git",
            exact: "0.12.1"
        ),
    ],
    targets: [
        .executableTarget(
            name: "PinboardMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
            ]
        ),
    ]
)

