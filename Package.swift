// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "WealthsimpleDownloader",
    products: [
        .library(
            name: "WealthsimpleDownloaderLibrary",
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
