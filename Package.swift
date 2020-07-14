// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "WealthsimpleDownloader",
    products: [
        .library(
            name: "WealthsimpleDownloader",
            targets: ["WealthsimpleDownloader"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "WealthsimpleDownloader",
            dependencies: []),
        .testTarget(
            name: "WealthsimpleDownloaderTests",
            dependencies: ["WealthsimpleDownloader"]),
    ]
)
