/*
 plugin.swift — build tool plugin (forked from DimaRU/PackageBuildInfo).
*/

import Foundation
import PackagePlugin

@main
struct PackageBuildInfoPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        guard let target = target as? SourceModuleTarget else { return [] }
        let outputFile = context.pluginWorkDirectory.appending("packageBuildInfo.swift")

        // .buildCommand (not .prebuildCommand) is required because the tool is built
        // from source — Xcode 16+ forbids source-built executables in prebuild commands.
        // Declare .git/HEAD as input so the command reruns on each commit.
        let gitHead = context.package.directory
            .removingLastComponent()   // package dir → repo root
            .appending(".git")
            .appending("HEAD")
        let command: Command = .buildCommand(
            displayName: "Generating \(outputFile.lastComponent) for \(target.directory)",
            executable: try context.tool(named: "PackageBuildInfo").path,
            arguments: ["\(target.directory)", "\(outputFile)"],
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
        let outputFile = context.pluginWorkDirectory.appending("packageBuildInfo.swift")
        let gitHead = context.xcodeProject.directory
            .appending(".git")
            .appending("HEAD")
        let command: Command = .buildCommand(
            displayName: "Generating \(outputFile.lastComponent) for \(context.xcodeProject.directory)",
            executable: try context.tool(named: "PackageBuildInfo").path,
            arguments: ["\(context.xcodeProject.directory)", "\(outputFile)"],
            inputFiles: [gitHead],
            outputFiles: [outputFile]
        )
        return [command]
    }
}
#endif
