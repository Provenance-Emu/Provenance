# PR is a work in progress and shouldn't be merged yet
warn "PR is classed as Work in Progress" if github.pr_title.include? "[WIP]"

# Warn when there is a big PR
warn "Big PR, consider splitting into smaller" if git.lines_of_code > 600

# Ensure a clean commits history
if git.commits.any? { |c| c.message =~ /^Merge branch '#{github.branch_for_base}'/ }
  fail "Please rebase to get rid of the merge commits in this PR"
end

# Mainly to encourage writing up some reasoning about the PR, rather than
# just leaving a title
if github.pr_body.length < 5
  fail "Please provide a summary in the Pull Request description"
end

# If these are all empty something has gone wrong, better to raise it in a comment
if git.modified_files.empty? && git.added_files.empty? && git.deleted_files.empty?
  fail "This PR has no changes at all, this is likely an issue during development."
end

# has_app_changes = !git.modified_files.grep(/Provenance$/).empty?
# has_app_test_changes = !git.modified_files.grep(/Provenance/).empty?
#
# has_support_changes = !git.modified_files.grep(/PVSupport/).empty?
# has_support_test_changes = !git.modified_files.grep(/PVSupport Tests/).empty?
#
# has_library_changes = !git.modified_files.grep(/PVLibrary/).empty?
# has_library_test_changes = !git.modified_files.grep(/PVLibrary Tests/).empty?
#
# # If changes are more than 10 lines of code, tests need to be updated too
# if ((has_core_changes && !has_core_test_changes) || (has_coreui_changes && !has_coreui_test_changes)) && git.lines_of_code > 10
#   fail("Tests were not updated", sticky: false)
# end

# Info.plist file shouldn't change often. Leave warning if it changes.
is_plist_change = git.modified_files.grep[/Info.plist/].empty?

if !is_plist_change
  warn "A Plist was changed"
  # warn "Plist changed, don't forget to localize your plist values"
end

cartfile_updated = !git.modified_files.grep(/Cartfile$/).empty?

# Leave warning, if Cartfile changes
if cartfile_updated
  warn "The `Cartfile` was updated"
end

gemfile_updated = !git.modified_files.grep(/Gemfile$/).empty?

# Leave warning, if Gemfile changes
if gemfile_updated
  warn "The `Gemfile` was updated"
end

# This is swiftlint plugin. More info: https://github.com/ashfurrow/danger-swiftlint
#
# This lints all Swift files and leave comments in PR if 
# there is any issue with linting
swiftlint.lint_files inline_mode: true

# xcodebuild.json_file = "./fastlane/reports/xcpretty-json-formatter-results.json"

# xcodebuild.parse_warnings # returns number of warnings
# xcodebuild.parse_errors # returns number of errors
# xcodebuild.parse_tests # returns number of test failures
# xcodebuild.perfect_build # returns a bool indicating if the build was perfect