// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(name: "RxRealm",
                      platforms: [
                        .macOS(.v10_10), .iOS(.v11), .tvOS(.v9), .watchOS(.v3)
                      ],
                      products: [
                        // Products define the executables and libraries produced by a package, and make them visible to other packages.
                        .library(name: "RxRealm",
                                 targets: ["RxRealm"])
                      ],

                      dependencies: [
                        // Dependencies declare other packages that this package depends on.
                        .package(url: "https://github.com/realm/realm-swift.git", .upToNextMajor(from: "10.21.1")),
                        .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "6.5.0"))
                      ],

                      targets: [
                        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
                        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
                        .target(name: "RxRealm",
                                dependencies: [
                                  .product(name: "RxSwift", package: "RxSwift"),
                                  .product(name: "Realm", package: "Realm"),
                                  .product(name: "RealmSwift", package: "Realm"),
                                  .product(name: "RxCocoa", package: "RxSwift")
                                ],
                                path: "Sources"),
                        .testTarget(name: "RxRealmTests",
                                    dependencies: [
                                      .byName(name: "RxRealm"),
                                      .product(name: "RxSwift", package: "RxSwift"),
                                      .product(name: "RxBlocking", package: "RxSwift"),
                                      .product(name: "Realm", package: "Realm"),
                                      .product(name: "RealmSwift", package: "Realm"),
                                      .product(name: "RxCocoa", package: "RxSwift")
                                    ])
                      ],
                      swiftLanguageVersions: [.v5])
