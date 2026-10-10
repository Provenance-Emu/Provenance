import ProjectDescription

// Marks the repo root as the Tuist root, so manifests and helpers resolve
// `.relativeToRoot(...)` paths against it. Helpers live in Tuist/ProjectDescriptionHelpers.
let tuist = Tuist(
    compatibleXcodeVersions: .upToNextMajor("26.0")
)
