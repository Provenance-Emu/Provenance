//
//  CMakeGeneratorBuildToolPlugin.swift
//  
//
//  Created by Joseph Mattiello on 02/25/23.
//

import Foundation
import PackagePlugin

@main
struct CMakeGeneratorPlugin: BuildToolPlugin {
    func createBuildCommands(
        context: PackagePlugin.PluginContext, 
        target: PackagePlugin.Target) async throws -> [PackagePlugin.Command] 
        {
        
        let inputJSON = target.directory.appending("Source.json")
        let output = context.pluginWorkDirectory.appending("GeneratedEnum.swift")
        return [
            .buildCommand(
                displayName: "Generate Code",
                executable: try context.tool(named: "CMakeGenerator").path,
                arguments: [inputJSON, output],
                environment: [:],
                inputFiles: [inputJSON],
                outputFiles: [output])
        ]
    }
}
