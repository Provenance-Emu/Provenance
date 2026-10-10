import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
    name: "Provenance-Dev",
    projects: ["Dev"],
    // A workspace FileRef to an .xcodeproj is a project reference: Xcode builds its targets
    // when the app links their products (implicit dependencies).
    additionalFiles: ["docs/superpowers/specs/*.md"]
        + FocusedApp.workspaceProjects(for: FocusedApp.all).map { .folderReference(path: .relativeToRoot($0)) }
)
