/*
 plugin.swift — build tool plugin (forked from DimaRU/PackageBuildInfo).
*/

import Foundation
import PackagePlugin

/// Linked worktrees store their Git directory in a `.git` file rather than a directory.
private func gitHeadInputs(in repository: URL) -> [URL] {
    let git = repository.appending(path: ".git")
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: git.path, isDirectory: &isDirectory) else { return [] }
    if isDirectory.boolValue { return [git.appending(path: "HEAD")] }
    guard let pointer = try? String(contentsOf: git, encoding: .utf8), pointer.hasPrefix("gitdir:") else { return [git] }
    let path = String(pointer.dropFirst("gitdir:".count)).trimmingCharacters(in: .whitespacesAndNewlines)
    let directory = URL(fileURLWithPath: path, relativeTo: repository).standardizedFileURL
    return [git, directory.appending(path: "HEAD")]
}

@main
struct PackageBuildInfoPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }
        let outputFile = context.pluginWorkDirectoryURL.appending(path: "packageBuildInfo.swift")
        /// `SourceModuleTarget.directoryURL` is not available on all PackagePlugin SDKs; derive a filesystem path from `directory` instead.
        let targetDirectoryPath = target.directory.string

        // .buildCommand (not .prebuildCommand) is required because the tool is built
        // from source — Xcode 16+ forbids source-built executables in prebuild commands.
        // Declare .git/HEAD as input so the command reruns on each commit.
        let gitInputs = gitHeadInputs(in: context.package.directoryURL.deletingLastPathComponent())
        let command: Command = .buildCommand(
            displayName: "Generating \(outputFile.lastPathComponent) for \(targetDirectoryPath)",
            executable: try context.tool(named: "PackageBuildInfo").url,
            arguments: [targetDirectoryPath, outputFile.path],
            inputFiles: gitInputs,
            outputFiles: [outputFile]
        )
        return [command]
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin
extension PackageBuildInfoPlugin: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodeProjectPlugin.XcodePluginContext, target: XcodeProjectPlugin.XcodeTarget) throws -> [PackagePlugin.Command] {
        let outputFile = context.pluginWorkDirectoryURL.appending(path: "packageBuildInfo.swift")
        let gitInputs = gitHeadInputs(in: context.xcodeProject.directoryURL)
        let command: Command = .buildCommand(
            displayName: "Generating \(outputFile.lastPathComponent) for \(context.xcodeProject.directoryURL.path)",
            executable: try context.tool(named: "PackageBuildInfo").url,
            arguments: [context.xcodeProject.directoryURL.path, outputFile.path],
            inputFiles: gitInputs,
            outputFiles: [outputFile]
        )
        return [command]
    }
}
#endif
