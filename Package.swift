// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CombineRequest",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(
            name: "CombineRequest",
            targets: ["CombineRequest"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Nimble", from: "9.0.0"),
        .package(url: "https://github.com/AliSoftware/OHHTTPStubs", from: "9.1.0")
    ],
    targets: [
        .target(
            name: "CombineRequest",
            dependencies: []),
        .testTarget(
            name: "CombineRequestTests",
            dependencies: [
                "CombineRequest",
                "Nimble",
                .product(name: "OHHTTPStubsSwift", package: "OHHTTPStubs")
            ]),
    ]
)
