//
//  MSLSource.swift
//  PVSlangRuntime
//
//  Compiles a pass's MSL source. Some SPIRV-Cross translations use names that
//  collide with Metal (`and`/`or` helpers, a user `fmod`), so a source that
//  fails to compile as-is is retried once with those names rewritten.
//  The rewrite is a retry only: shaders that already compile are never touched.
//

import Foundation
import Metal

enum MSLSource {
    /// Rewrites identifiers that GLSL-to-MSL translation leaves colliding with
    /// Metal's standard library. Ported from RasterLab's FilterChain.
    static func sanitize(_ source: String) -> String {
        var s = source
        s = s.replacingOccurrences(of: " bool4 and(", with: " bool4 msl_and(")
        s = s.replacingOccurrences(of: " bool4 or(", with: " bool4 msl_or(")
        s = s.replacingOccurrences(of: "\nand(", with: "\nmsl_and(")
        s = s.replacingOccurrences(of: " and(", with: " msl_and(")
        s = s.replacingOccurrences(of: "\nor(", with: "\nmsl_or(")
        s = s.replacingOccurrences(of: " or(", with: " msl_or(")
        // Rename user-defined fmod, then bind plain calls to metal::fmod.
        s = s.replacingOccurrences(of: "float fmod(", with: "float fmod_local(")
        s = s.replacingOccurrences(of: " static float fmod(", with: " static float fmod_local(")
        s = s.replacingOccurrences(of: "inline float fmod(", with: "inline float fmod_local(")
        s = s.replacingOccurrences(of: " fmod(", with: " metal::fmod(")
        return s
    }

    /// Compiles `source` and returns the first entry point found in `names`.
    /// Throws when neither the source nor its sanitized form compiles.
    static func makeFunction(device: MTLDevice,
                             source: String,
                             options: MTLCompileOptions,
                             names: [String]) throws -> MTLFunction? {
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: source, options: options)
        } catch {
            let sanitized = sanitize(source)
            guard sanitized != source else { throw error }
            library = try device.makeLibrary(source: sanitized, options: options)
        }
        for name in names {
            if let function = library.makeFunction(name: name) {
                return function
            }
        }
        return nil
    }
}
