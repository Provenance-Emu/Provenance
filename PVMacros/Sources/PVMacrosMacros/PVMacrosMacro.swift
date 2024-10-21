import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// DetachedWeakSelf
public struct DetachedWeakSelf: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        let argument = node.arguments.first?.expression ?? "self "

        return """
            Task.detached { [weak \(argument)] in
                guard let \(argument) = \(argument) else { return }
                async \(argument)\(node.trailingClosure)
            }
            """
    }
}

@main
struct PVMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        DetachedWeakSelf.self,
    ]
}
