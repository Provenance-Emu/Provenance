import PackageDescription

let package = Package(
    name: "PMKAlamofire",
    dependencies: [
        .Package(url: "https://github.com/mxcl/PromiseKit.git", majorVersion: 4),
        .Package(url: "https://github.com/Alamofire/Alamofire.git", majorVersion: 4)
    ],
    exclude: ["Tests"]
)
