import PackageDescription

let pkg = Package(name: "PMKCloudKit")

pkg.dependencies = [
	.Package(url: "https://github.com/mxcl/PromiseKit.git", majorVersion: 6)
]

pkg.exclude = [
	"Sources/CKContainer+AnyPromise.h",
	"Sources/CKDatabase+AnyPromise.h",
	"Sources/PMKCloudKit.h",
	"Sources/CKContainer+AnyPromise.m",
	"Sources/CKDatabase+AnyPromise.m",
	"Tests"
]
