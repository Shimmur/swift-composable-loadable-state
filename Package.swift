// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-composable-loadable-state",
    platforms: [
      .iOS(.v15),
      .macOS(.v14)
    ],
    products: [
        // Disabled while TCA1 dependency is removed for TCA2 exploration
        // .library(
        //     name: "Loadable",
        //     targets: ["Loadable"]
        // ),
        // .library(
        //     name: "LoadableUI",
        //     targets: ["LoadableUI"]
        // ),
        // .library(
        //     name: "PaginatedList",
        //     targets: ["PaginatedList"]
        // ),
        .library(
            name: "LoadableTCA2",
            targets: ["LoadableTCA2"]
        ),
    ],
    dependencies: [
        // TCA1-era dependencies (commented out with TCA1)
        // .package(url: "https://github.com/pointfreeco/swift-case-paths", .upToNextMajor(from: "1.5.4")),
        // .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.13.0")),
        // .package(url: "https://github.com/pointfreeco/swift-identified-collections", .upToNextMajor(from: "1.0.0")),
        // .package(url: "https://github.com/pointfreeco/swift-custom-dump", .upToNextMajor(from: "1.3.3")),
        // .package(url: "https://github.com/pointfreeco/xctest-dynamic-overlay", .upToNextMajor(from: "1.4.1")),
        .package(url: "https://github.com/pointfreeco/TCA26", branch: "main")
    ],
    targets: [
        // Disabled while TCA1 dependency is removed for TCA2 exploration
        // .target(
        //     name: "Loadable",
        //     dependencies: [
        //         .product(name: "CasePaths", package: "swift-case-paths"),
        //         .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        //         .product(name: "CustomDump", package: "swift-custom-dump"),
        //         .product(name: "IdentifiedCollections", package: "swift-identified-collections"),
        //     ]
        // ),
        // .target(
        //     name: "LoadableUI",
        //     dependencies: ["Loadable"]
        // ),
        // .target(
        //     name: "PaginatedList",
        //     dependencies: ["Loadable", "LoadableUI"]
        // ),
        .target(
            name: "LoadableTCA2",
            dependencies: [
                .product(name: "ComposableArchitecture2", package: "TCA26"),
            ]
        ),
        // .testTarget(
        //     name: "LoadableTests",
        //     dependencies: [
        //         "Loadable",
        //         .product(name: "IssueReportingTestSupport", package: "xctest-dynamic-overlay")
        //     ]
        // ),
        .testTarget(
            name: "LoadableTCA2Tests",
            dependencies: [
                "LoadableTCA2",
                .product(name: "ComposableArchitecture2", package: "TCA26"),
            ]
        ),
    ]
)
