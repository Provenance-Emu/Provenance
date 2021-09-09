import Danger
import Foundation
// import SwiftLint

let danger = Danger()

// fileImport: DangerfileExtensions/ChangelogCheck.swift
// checkChangelog()

// Add a CHANGELOG entry for app changes
let hasChangelog = danger.git.modifiedFiles.contains("Changelog.md")
let isTrivial = (danger.github.pullRequest.body + danger.github.pullRequest.title).contains("#trivial")

if (!hasChangelog && !isTrivial) {
    warn("Please add a changelog entry for your changes.")
}

// PR Too large
if danger.git.createdFiles.count + danger.git.modifiedFiles.count - danger.git.deletedFiles.count > 600 {
    warn("Big PR, try to keep changes smaller if you can")
}

// Check copyright
let swiftFilesWithCopyright = danger.git.createdFiles.filter {
    $0.fileType == .swift
        && danger.utils.readFile($0).contains("//  Created by")
}

if !swiftFilesWithCopyright.isEmpty {
    let files = swiftFilesWithCopyright.joined(separator: ", ")
    warn("In Danger JS we don't include copyright headers, found them in: \(files)")
}

// # This is swiftlint plugin. More info: https://github.com/ashfurrow/danger-swiftlint
// #
// # This lints all Swift files and leave comments in PR if
// # there is any issue with linting
let filesToLint = (danger.git.modifiedFiles + danger.git.createdFiles) // .filter { !$0.contains("Documentation/") }

SwiftLint.lint(.files(filesToLint), inline: true)

// Support running via `danger local`
if danger.github != nil {
    // These checks only happen on a PR
    if danger.github.pullRequest.title.contains("WIP") {
        warn("PR is classed as Work in Progress")
    }
}

if github.pr_title.contains("WIP") {
    warn("PR is classed as Work in Progress")
}

if git.commits.any {
  return $0.message.contains("Merge branch '\(github.branch_for_base)'")
} {
  fail("Please rebase to get rid of the merge commits in this PR ")
}

if github.pr_body.length > 1000 {
    warn("PR body is too long")
}

if github.pr_body.length < 5 {
  fail("PR body is too short")
}

let has_app_changes = !git.modified_files.any { $0.contains("Provenance") }
let has_support_changes = !git.modified_files.any { $0.contains("PVSupport") }
let has_support_test_changes = !git.modified_files.any { $0.contains("PVSupport Tests") }
let has_library_changes = !git.modified_files.any { $0.contains("PVLibrary") }
let has_library_test_changes = !git.modified_files.any { $0.contains("PVLibrary Tests") }

// If changes are more than 10 lines of code, tests need to be updated too
// if (has_core_changes && !has_core_test_changes) ||
//     (has_coreui_changes && !has_coreui_test_changes)) &&
//     git.lines_of_code > 10 {
//   fail("Tests were not updated", sticky: false)
// }

// Info.plist file shouldn't change often. Leave warning if it changes.
let is_plist_change = git.modified_files.any { $0.contains("Info.plist") }

if !is_plist_change
  // warn "A Plist was changed"
  warn("Plist changed, don't forget to localize your plist values")
end

// gemfile_updated = !git.modified_files.grep(/Gemfile$/).empty?

// # Leave warning, if Gemfile changes
// if gemfile_updated
//   warn "The `Gemfile` was updated"
// end

// import xcodebuild
// xcodebuild.json_file = "./fastlane/reports/xcpretty-json-formatter-results.json"
// xcodebuild.parse_warnings() // returns number of warnings
// xcodebuild.parse_errors() // returns number of errors
// // xcodebuild.parse_errors(errors: danger.github.pull_request.body)
// xcodebuild.parse_tests()  // returns number of test failures
// xcodebuild.perfect_build() // returns a bool indicating if the build was perfect
func checkSwiftVersions() {
    SwiftChecks.check(
        files: [
            VersionFile(
                path: "./\(projectName).xcodeproj/project.pbxproj",
                interpreter: .regex("SWIFT_VERSION = (.*);")
            ),
            VersionFile(
                path: "./\(projectName).podspec",
                interpreter: .regex("\\.swift_version\\s*=\\s*\"(.*)\"")
            ),
        ],
        versionKind: "Swift"
    )
}

func checkProjectVersions() {
    SwiftChecks.check(
        fileProviders: [
            InfoPlistFileProvider(
                discoveryMethod: .searchDirectory("./Sources", fileNames: ["Info.plist"]),
                plistKey: .versionNumber,
                projectFilePath: "./\(projectName).xcodeproj"
            ),
        ],
        files: [
            VersionFile(path: "./\(projectName).podspec", interpreter: .regex("\\.version\\s*=\\s*\"(.*)\"")),
        ],
        versionKind: "framework"
    )
}

// checkProjectVersions()
// checkSwiftVersions