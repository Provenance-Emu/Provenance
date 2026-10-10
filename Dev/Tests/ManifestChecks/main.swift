import Foundation

// Compiled with Tuist/ProjectDescriptionHelpers/*.swift against Tuist's ProjectDescription
// framework by Scripts/dev/check_dev_manifest.sh. Argument 1: repo root.

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
var failures: [String] = []

func exists(_ relative: String) -> Bool {
    FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
}

/// Names in cores.yml whose entry has `enabled: true`.
func enabledLibretroNames() throws -> Set<String> {
    let text = try String(contentsOf: root.appendingPathComponent("CoresRetro/RetroArch/scripts/cores.yml"), encoding: .utf8)
    var enabled = Set<String>()
    var current: String?
    for rawLine in text.components(separatedBy: "\n") {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("- name:") {
            current = line.dropFirst("- name:".count)
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        } else if let name = current, line.hasPrefix("enabled:") {
            let value = line.dropFirst("enabled:".count).split(separator: "#").first?
                .trimmingCharacters(in: .whitespaces)
            if value == "true" { enabled.insert(name) }
        }
    }
    return enabled
}

// 1. Every libretro name is an enabled cores.yml entry.
let enabled = try enabledLibretroNames()
for app in FocusedApp.all {
    for name in app.libretro where !enabled.contains(name) {
        failures.append("\(app.name): libretro '\(name)' is not an enabled cores.yml entry")
    }
}

// 2. Every CoreProduct path exists.
for core in CoreProduct.all {
    for link in core.links {
        for path in link.paths where !exists(path) {
            failures.append("CoreProduct '\(core.id)': missing \(path)")
        }
    }
}

// 3. No local package declared twice, and each has a Package.swift.
let locals = DevSettings.localPackagePaths(for: FocusedApp.all)
if Set(locals).count != locals.count {
    failures.append("duplicate local packages: \(locals)")
}
for path in locals where !exists(path + "/Package.swift") {
    failures.append("local package without Package.swift: \(path)")
}

// 4. Target names are unique and every vendored project exists.
let names = FocusedApp.all.map(\.name)
if Set(names).count != names.count {
    failures.append("duplicate focused app names: \(names)")
}
for path in FocusedApp.workspaceProjects(for: FocusedApp.all) where !exists(path + "/project.pbxproj") {
    failures.append("workspace project missing: \(path)")
}

if failures.isEmpty {
    print("dev manifest: OK (\(FocusedApp.all.count) apps, \(CoreProduct.all.count) core rows, \(locals.count) local packages)")
    exit(0)
}
failures.forEach { print("dev manifest: FAIL \($0)") }
exit(1)
