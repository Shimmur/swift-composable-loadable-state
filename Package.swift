// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-composable-loadable-state",
    platforms: [
      .iOS(.v15),
      .macOS(.v14)
    ],
    products: [
        .library(
            name: "Loadable",
            targets: ["Loadable"]
        ),
        .library(
            name: "LoadableUI",
            targets: ["LoadableUI"]
        ),
        .library(
            name: "PaginatedList",
            targets: ["PaginatedList"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/pointfreeco/swift-case-paths",
            .upToNextMajor(from: "1.5.4")
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            .upToNextMajor(from: "1.13.0")
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-identified-collections",
            .upToNextMajor(from: "1.0.0")
        ),
        .package(
            url: "https://github.com/pointfreeco/swift-custom-dump",
            .upToNextMajor(from: "1.3.3")
        )
    ],
    targets: [
        .target(
            name: "Loadable",
            dependencies: [
                .product(name: "CasePaths", package: "swift-case-paths"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
            ]
        ),
        .target(
            name: "LoadableUI",
            dependencies: ["Loadable"]
        ),
        .target(
            name: "PaginatedList",
            dependencies: ["Loadable", "LoadableUI"]
        ),
        .testTarget(
            name: "LoadableTests",
            dependencies: ["Loadable"]
        ),
    ]
)
