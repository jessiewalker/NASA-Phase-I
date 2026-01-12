// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EFBAgent",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "EFBAgent",
            targets: ["EFBAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "EFBAgent",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ]),
        .testTarget(
            name: "EFBAgentTests",
            dependencies: ["EFBAgent"]),
    ]
)

