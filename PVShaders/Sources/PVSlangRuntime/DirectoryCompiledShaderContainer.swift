//
//  DirectoryCompiledShaderContainer.swift
//  PVSlangRuntime
//
//  Reads a compiled shader that was unpacked at build time: a directory
//  holding `shader.json` plus LUT images named `<lutname>__<original>`.
//  The build script unpacks every `.oecompiledshader` archive, so the app
//  never unzips at runtime.
//

import Foundation

public final class DirectoryCompiledShaderContainer: CompiledShaderContainer {
    public enum Error: Swift.Error, Equatable {
        case missingCompiledShader
        case lutOutsideDirectory
    }

    public let shader: Compiled.Shader
    public let directory: URL

    public init(directory: URL) throws {
        let jsonURL = directory.appendingPathComponent("shader.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path) else {
            throw Error.missingCompiledShader
        }
        self.directory = directory.standardizedFileURL
        let data = try Data(contentsOf: jsonURL)
        shader = try JSONDecoder().decode(Compiled.Shader.self, from: data)
    }

    public func getLUTByName(_ name: String) throws -> Data {
        let prefix = name + "__"
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        guard let match = entries.first(where: { $0.lastPathComponent.hasPrefix(prefix) }) else {
            throw CompiledShaderContainerError.invalidLUTName
        }
        // Reject anything that resolves (via symlink) outside the preset directory.
        let resolved = match.resolvingSymlinksInPath().standardizedFileURL
        guard resolved.path.hasPrefix(directory.resolvingSymlinksInPath().standardizedFileURL.path + "/") else {
            throw Error.lutOutsideDirectory
        }
        return try Data(contentsOf: resolved)
    }
}
