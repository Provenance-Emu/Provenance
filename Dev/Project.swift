import ProjectDescription
import ProjectDescriptionHelpers

// Named "Provenance" on purpose: Build.xcconfig derives bundle ids, the app group and the
// iCloud container from $(PROJECT_NAME:lower). Generated into Dev/ so it never overwrites
// the shipping Provenance.xcodeproj.
let project = Project(
    name: "Provenance",
    options: .options(
        automaticSchemesOptions: .disabled,
        disableBundleAccessors: true,
        disableSynthesizedResourceAccessors: true
    ),
    packages: DevSettings.packages(for: FocusedApp.all),
    settings: DevSettings.projectSettings,
    targets: FocusedApp.all.map { $0.target() },
    schemes: FocusedApp.all.map { $0.scheme() }
)
