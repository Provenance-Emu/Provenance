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

// Every check runs over the whole catalog, including opt-in apps a plain `tuist generate` leaves out.
let apps = FocusedApp.catalog

// 1. Every libretro name is an enabled cores.yml entry.
let enabled = try enabledLibretroNames()
for app in apps {
    for name in app.libretro where !enabled.contains(name) {
        failures.append("\(app.name): libretro '\(name)' is not an enabled cores.yml entry")
    }
}

// 2. Every CoreProduct path exists. Build artefacts (prebuilt links, anything under build/ or
// ending in .framework/.xcframework) are required only for rows a FocusedApp uses.
func isBuildArtefact(_ link: CoreLink, path: String) -> Bool {
    if case .prebuilt = link { return true }
    return path.contains("/build/") || path.hasSuffix(".xcframework") || path.hasSuffix(".framework")
}

let usedCoreIDs = Set(FocusedApp.all.flatMap { $0.allCores.map(\.id) })
let catalogCoreIDs = Set(apps.flatMap { $0.allCores.map(\.id) })
for core in CoreProduct.all {
    for link in core.links {
        for path in link.paths where !exists(path) {
            if isBuildArtefact(link, path: path) {
                if usedCoreIDs.contains(core.id) {
                    failures.append("CoreProduct '\(core.id)': missing \(path)")
                } else {
                    print("dev manifest: note: '\(core.id)' artefact not built (unused by any focused app): \(path)")
                }
            } else {
                failures.append("CoreProduct '\(core.id)': missing \(path)")
            }
        }
    }
}

// 2b. Build artefacts a package row needs before SwiftPM can load it (a binaryTarget path). A clean
// checkout lacks them. They are required only while an enabled app uses the core; an opt-in app
// that is switched off just reports them, because whoever opts in produces them first.
for core in CoreProduct.all {
    for path in core.artefacts where !exists(path) {
        if usedCoreIDs.contains(core.id) {
            failures.append("CoreProduct '\(core.id)': missing build artefact \(path)")
        } else if catalogCoreIDs.contains(core.id) {
            print("dev manifest: note: '\(core.id)' needs \(path) before its opt-in app can generate (see the Makefile)")
        }
    }
}

// 2c. Slice-cache xcframeworks (package binary targets) are build outputs, never checked in, so a clean
// checkout lacks them. The package manifest drops its binary target when the xcframework is absent
// (other apps still resolve), so this is a note, not a failure.
for core in CoreProduct.all {
    guard let slice = core.slice, !exists(slice.xcframework) else { continue }
    let use = usedCoreIDs.contains(core.id) ? "used by a focused app" : "unused by any focused app"
    print("dev manifest: note: '\(core.id)' (\(use)) needs \(slice.xcframework): "
        + "make dev-generate DEV_PREBUILT_CORES=\(slice.core) DEV_SLICE=<ios|ios-sim|tvos|tvos-sim>")
}

// 3. No local package declared twice, and each has a Package.swift.
let locals = DevSettings.localPackagePaths(for: apps)
if Set(locals).count != locals.count {
    failures.append("duplicate local packages: \(locals)")
}
for path in locals where !exists(path + "/Package.swift") {
    failures.append("local package without Package.swift: \(path)")
}

// 4. Target names are unique and every vendored project exists.
let names = apps.map(\.name)
if Set(names).count != names.count {
    failures.append("duplicate focused app names: \(names)")
}
for path in FocusedApp.workspaceProjects(for: apps) where !exists(path + "/project.pbxproj") {
    failures.append("workspace project missing: \(path)")
}

if failures.isEmpty {
    print("dev manifest: OK (\(apps.count) apps (\(FocusedApp.all.count) enabled), \(CoreProduct.all.count) core rows, \(locals.count) local packages)")
    exit(0)
}
failures.forEach { print("dev manifest: FAIL \($0)") }
exit(1)
