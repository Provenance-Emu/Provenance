# Sometimes it's a README fix, or something like that - which isn't relevant for
# including in a project's CHANGELOG for example
declared_trivial = (github.pr_title + github.pr_body).include?("#trivial")

# Make it more obvious that a PR is a work in progress and shouldn't be merged yet
warn("PR is classed as Work in Progress") if github.pr_title.include? "[WIP]"

# Warn summary on pull request
if github.pr_body.length < 5
  warn "Please provide a summary in the Pull Request description"
end

# If these are all empty something has gone wrong, better to raise it in a comment
if git.modified_files.empty? && git.added_files.empty? && git.deleted_files.empty?
  fail "This PR has no changes at all, this is likely a developer issue."
end

# Warn when there is a big PR
message("Big PR") if git.lines_of_code > 500
warn("Huge PR") if git.lines_of_code > 1000
fail("Enormous PR. Please split this pull request.") if git.lines_of_code > 3000

# Warn Cartfile changes
message("Cartfile changed") if git.modified_files.include?("Cartfile")
message("Cartfile.resolved changed") if git.modified_files.include?("Cartfile.resolved")

# Lint
swiftlint.lint_all_files = true
swiftlint.max_num_violations = 20
swiftlint.config_file = ".swiftlint.yml"
swiftlint.lint_files fail_on_error: true

# xcov.report(
#     scheme: "RxRealm iOS",
#     project: "RxRealm.xcodeproj",
#     include_targets: "RxRealm.framework",
#     minimum_coverage_percentage: 20.0,
#     derived_data_path: "Build/",
#   )
  