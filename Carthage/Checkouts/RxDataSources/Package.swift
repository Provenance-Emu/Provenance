// swift-tools-version:4.0

import PackageDescription

let package = Package(
  name: "RxDataSources",
  products: [
    .library(name: "RxDataSources", targets: ["RxDataSources"]),
    .library(name: "Differentiator", targets: ["Differentiator"]),
  ],
  dependencies: [
    .package(url: "https://github.com/ReactiveX/RxSwift.git", .upToNextMajor(from: "4.0.0")),
  ],
  targets: [
    .target(name: "RxDataSources", dependencies: ["Differentiator", "RxSwift", "RxCocoa"]),
    .target(name: "Differentiator"),
    .testTarget(name: "RxDataSourcesTests", dependencies: ["RxDataSources"]),
  ]
)
