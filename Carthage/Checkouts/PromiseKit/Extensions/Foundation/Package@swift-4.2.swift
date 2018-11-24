// swift-tools-version:4.2

import PackageDescription

let pkg = Package(name: "PMKFoundation")
pkg.products = [
    .library(name: "PMKFoundation", targets: ["PMKFoundation"]),
]
pkg.dependencies = [
    .package(url: "https://github.com/mxcl/PromiseKit.git", .upToNextMajor(from: "6.0.0"))
]
pkg.swiftLanguageVersions = [.v3, .v4, .v4_2]

let target: Target = .target(name: "PMKFoundation")
target.path = "Sources"
target.exclude = ["NSNotificationCenter", "NSTask", "NSURLSession"].flatMap {
    ["\($0)+AnyPromise.m", "\($0)+AnyPromise.h"]
}
target.exclude.append("PMKFoundation.h")

target.dependencies = [
    "PromiseKit"
]

#if os(Linux)
target.exclude += [
    "afterlife.swift",
    "NSObject+Promise.swift"
]
#endif

pkg.targets = [target]
