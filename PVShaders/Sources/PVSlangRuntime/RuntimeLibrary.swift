//
//  RuntimeLibrary.swift
//  PVSlangRuntime
//
//  Loads the runtime's own Metal functions (Shaders.metal, Converters.metal)
//  from this package's bundle, once per device.
//

import Foundation
import Metal

enum RuntimeLibrary {
    /// The `.metal` resource that holds a group of runtime functions.
    enum Source: String {
        /// Final-blit vertex/fragment functions used by `FilterChain`.
        case shaders = "Shaders"
        /// Pixel-format conversion kernels used by `MTLPixelConverter`.
        case converters = "Converters"
    }

    enum Error: Swift.Error {
        case missingSource(String)
    }

    private struct Key: Hashable {
        let device: UInt64
        let source: Source
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cache: [Key: MTLLibrary] = [:]

    /// Returns a library containing `source`'s functions.
    ///
    /// Xcode compiles the package's `.metal` files into `default.metallib` in
    /// `Bundle.module`. The SwiftPM command line only copies them, so when no
    /// metallib exists the source is compiled at runtime. Never the main bundle:
    /// it has no copy of these functions, and a missing library otherwise only
    /// shows up later as a failed pipeline.
    static func library(for device: MTLDevice, source: Source) throws -> MTLLibrary {
        lock.lock()
        defer { lock.unlock() }
        let key = Key(device: device.registryID, source: source)
        if let cached = cache[key] {
            return cached
        }
        let library: MTLLibrary
        if let bundled = try? device.makeDefaultLibrary(bundle: Bundle.module) {
            library = bundled
        } else {
            guard let url = Bundle.module.url(forResource: source.rawValue, withExtension: "metal") else {
                throw Error.missingSource(source.rawValue)
            }
            library = try device.makeLibrary(source: String(contentsOf: url, encoding: .utf8), options: nil)
        }
        cache[key] = library
        return library
    }
}
