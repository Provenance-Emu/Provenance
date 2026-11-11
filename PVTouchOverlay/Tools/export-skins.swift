import Foundation

/// Capture the authored templates before the legacy family builders are removed.
private struct SystemTemplates: Encodable {
    struct Layout: Encodable {
        let subtype: String
        let orientation: OverlayOrientation
        let template: OverlayTemplate
    }

    let system: String
    let defaultSubtype: String
    let palette: OverlayPalette
    let layouts: [Layout]
}

@main
struct OverlayTemplateExport {
    static func main() throws {
        let systems = try SystemOverlayBindings.boundSystems
            .sorted { $0.rawValue < $1.rawValue }
            .map { system in
                guard let binding = SystemOverlayBindings.binding(for: system) else {
                    throw ExportError.missingBinding(system.rawValue)
                }
                guard binding.families[binding.defaultSubtype] != nil else {
                    throw ExportError.missingDefaultSubtype(system.rawValue, binding.defaultSubtype)
                }
                let layouts = binding.families.keys.sorted().flatMap { subtype in
                    let pad = OverlayPadKind(system: system, subtype: subtype)
                    return OverlayOrientation.allCases.map { orientation in
                        SystemTemplates.Layout(
                            subtype: subtype,
                            orientation: orientation,
                            template: binding.template(padKind: pad, orientation: orientation)
                        )
                    }
                }
                return SystemTemplates(system: system.rawValue, defaultSubtype: binding.defaultSubtype,
                                       palette: binding.palette, layouts: layouts)
            }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        FileHandle.standardOutput.write(try encoder.encode(systems))
        FileHandle.standardOutput.write(Data([0x0A]))
    }

    enum ExportError: Error {
        case missingBinding(String)
        case missingDefaultSubtype(String, String)
    }
}
