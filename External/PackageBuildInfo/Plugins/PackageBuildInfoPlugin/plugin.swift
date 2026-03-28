/*
 plugin.swift — build tool plugin (forked from DimaRU/PackageBuildInfo).
*/

import Foundation
import PackagePlugin

@main
struct PackageBuildInfoPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }
        let outputFile = context.pluginWorkDirectoryURL.appending(path: "packageBuildInfo.swift")

        // .buildCommand (not .prebuildCommand) is required because the tool is built
        // from source — Xcode 16+ forbids source-built executables in prebuild commands.
        // Declare .git/HEAD as input so the command reruns on each commit.
        let gitHead = context.package.directoryURL
            .deletingLastPathComponent()   // package dir → repo root
            .appending(path: ".git")
            .appending(path: "HEAD")
        let command: Command = .buildCommand(
            displayName: "Generating \(outputFile.lastPathComponent) for \(target.directory.string)",
            executable: try context.tool(named: "PackageBuildInfo").url,
            arguments: [target.directory.string, outputFile.path],
            inputFiles: [gitHead],
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
        let gitHead = context.xcodeProject.directoryURL
            .appending(path: ".git")
            .appending(path: "HEAD")
        let command: Command = .buildCommand(
            displayName: "Generating \(outputFile.lastPathComponent) for \(context.xcodeProject.directoryURL.path)",
            executable: try context.tool(named: "PackageBuildInfo").url,
            arguments: [context.xcodeProject.directoryURL.path, outputFile.path],
            inputFiles: [gitHead],
            outputFiles: [outputFile]
        )
        return [command]
    }
}
#endif
