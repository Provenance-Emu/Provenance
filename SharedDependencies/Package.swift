// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SharedDependencies",
    products: [
        .library(
            name: "SharedDependencies-iOS",
            type: .dynamic,
            targets: ["SharedDependencies", "PVRxGesture"]),
        .library(
            name: "SharedDependencies-tvOS",
            type: .dynamic,
            targets: ["SharedDependencies"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", from: "5.0.0"),
        .package(url: "https://github.com/RxSwiftCommunity/RxRealm.git", from: "1.0.1"),
        .package(name: "Realm", url: "https://github.com/realm/realm-cocoa.git", from: "3.17.3"),
        .package(url: "https://github.com/RxSwiftCommunity/RxDataSources.git", from: "4.0.1"),
        .package(url: "https://github.com/RxSwiftCommunity/RxGesture.git", from: "3.0.3"),
    ],
    targets: [
        // This is just a shim-target, it's needed because otherwise XCode tries to link e.g. RxSwift statically into two different targets, resulting in errors. Having this package with `type: .dynamic` solves that. This seems like a XCode bug, so when it's fixed we should just delete this package and depend on the packages the normal way
        .target(
            name: "SharedDependencies",
            dependencies: [
                "RxSwift",
                .product(name: "RxCocoa", package: "RxSwift"),
                "RxRealm",
                .product(name: "RealmSwift", package: "Realm"),
                "RxDataSources"
            ]
        ),
        .target(
            name: "PVRxGesture",
            dependencies: [
                "RxGesture"
            ]
        )
    ]
)
