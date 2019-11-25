# frozen_string_literal: true

# Dangerfile
# To test locally, use the following
# `export DANGER_GITHUB_API_TOKEN=...YourToken...`
# `bundle exec danger pr https://github.com/Provenance-EMU/Provenance/pull/1618` Or some other pull #

# import remote Dangerfile; example, https://github.com/loadsmart/dangerfile/blob/master/Dangerfile
# danger.import_dangerfile(github: 'loadsmart/dangerfile', :path => 'Dangerfile')

require 'git_diff_parser'

# ------------------------------------------------------------------------------
# Additional pull request data
# ------------------------------------------------------------------------------
pr_number = github.pr_json['number']
pr_url = github.pr_json['_links']['html']['href']

# Sometimes it's a README fix, or something like that - which isn't relevant for
# including in a project's CHANGELOG for example
declared_trivial = github.pr_title.include? '#trivial'

has_changelog_changes = git.modified_files.include?('CHANGELOG.md')
has_gemfile_changes = git.modified_files.include?('Gemfile')
has_gemfile_lock_changes = git.modified_files.include?('Gemfile.lock')
has_podfile_changes = git.modified_files.include?('Podfile')
has_library_changes = !git.modified_files.grep(%r{PV*/*/*.swift}).empty?
has_app_changes = !git.modified_files.grep(%r{Provenance*/*/*.swift}).empty?
has_test_changes = !git.modified_files.grep(%r{Provenance Tests/*/*.swift}).empty?
has_danger_changes = !git.modified_files.grep(%r{Dangerfile|script/oss-check}).empty?
has_pod_lock_changes = !git.modified_files.grep(/Podfile.lock|Manifest.lock/).empty?
modified_xcode_project = !git.modified_files.grep(/.*\.xcodeproj/).empty?
added_swift_library_files = !git.added_files.grep(/PV.*\.swift/).empty?
deleted_swift_library_files = !git.deleted_files.grep(/PV.*\.swift/).empty?

## Warnings

# Warn when there is a big PR
warn "Big PR, consider splitting into smaller" if git.lines_of_code > 600

# Warn when Danger changes
warn('Dangerfile changes') if has_danger_changes

# Warn when Ruby changes
warn('Ruby `Gemfile` changes') if has_gemfile_changes
fail('Ruby `Gemfile` changes but not `Gemfile.lock`. Did you forget to run `bundle install`') if has_gemfile_changes && !has_gemfile_lock_changes

# Warn when Pod changes
warn('Cocoapods Changes') if has_podfile_changes

# Warn when Podfile changes but no lockfile
warn('Podfile changes but lockfile unchanged. Did you forget to run `pod install`?') if has_podfile_changes && !has_pod_lock_changes

warn 'PR is classed as Work in Progress' if github.pr_title.include? 'WIP'
warn 'PR is classed as Hold' if github.pr_labels.include? 'ON HOLD'

# NOTE WHEN A PR CANNOT BE MANUALLY MERGED, WHICH GOES AWAY WHEN YOU CAN
can_merge = github.pr_json['mergeable']
warn('This PR cannot be merged yet.', sticky: false) unless can_merge

requires_proj_update = added_swift_library_files || deleted_swift_library_files
failure 'Added or removed library files require the Xcode project to be updated.' if requires_proj_update && !modified_xcode_project

# ------------------------------------------------------------------------------
# Have you updated CHANGELOG.md?
# ------------------------------------------------------------------------------
if !has_changelog_changes && has_library_changes
  markdown <<-MARKDOWN
  Here's an example of a CHANGELOG.md entry (place it immediately under the `* Your contribution here!` line):
  ```markdown
  * [##{pr_number}](#{pr_url}): #{github.pr_title} - [@#{github.pr_author}](https://github.com/#{github.pr_author})
  ```
  MARKDOWN
  warn('Please update CHANGELOG.md with a description of your changes. '\
       'If this PR is not a user-facing change (e.g. just refactoring), '\
       'you can disregard this.', sticky: false)
end

## Messages

# - > +
message('Good job on cleaning the code!') if git.deletions > git.insertions

## Failures

# Mainly to encourage writing up some reasoning about the PR, rather than
# just leaving a title
failure 'Please provide a summary in the Pull Request description' if github.pr_body.length < 5

# ONLY ACCEPT PRS TO THE DEVELOP BRANCH
# failure 'Please re-submit this PR to develop, we may have already fixed your issue.' if github.branch_for_base != 'develop'

# Ensure a clean commits history
failure 'Please rebase to get rid of the merge commits in this PR' if git.commits.any? { |c| c.message =~ /^Merge branch '#{github.branch_for_base}'/ }

# Auto-linking to JIRA issues
# jira.check(
#   key: ['PROV'],
#   url: 'https://jira.provenance-emu.com/browse',
#   fail_on_warning: false
# )

# Adds labels

# Hold
# on_hold_label = ':rotating_light:ON HOLD:rotating_light:'
# if github.pr_title.include? 'HOLD'
#   auto_label.set(github.pr_json['number'], on_hold_label, 'ff8a04')
# else
#   auto_label.remove(on_hold_label)
# end

# Check if PR is mergeable
# merge_conflict_label = ':cry: Merge Conflicts'

# if github.pr_json['mergeable']
#   auto_label.remove(merge_conflict_label)
# else
#   auto_label.set(github.pr_json['number'], merge_conflict_label, 'e0f76f')
# end

### Everything here only happens if has code changes to ScreenKit
return unless has_library_changes || has_danger_changes || has_app_changes

# Non-trivial amounts of app changes without tests
if git.lines_of_code > 50 && has_library_changes && !has_test_changes
  warn 'This PR may need tests.'
end

if git.lines_of_code > 50 && has_library_changes && !has_app_changes
  warn 'This PR may need ScreenKitExample additions.'
end

# Run SwiftLint and comment on lines with violations
swiftlint.config_file = '.swiftlint.yml'
# swiftlint.binary_path = 'Pods/SwiftLint/swiftlint'

# Only lint files from this PR
diff = GitDiffParser::Patches.parse(github.pr_diff)
dir = "#{Dir.pwd}/"
swiftlint.lint_files(inline_mode: true) do |violation|
  diff_filename = violation['file'].gsub(dir, '')
  file_patch = diff.find_patch_by_file(diff_filename)
  !file_patch.nil? && file_patch.changed_lines.any? { |line| line.number == violation['line'] }
end

# Codecov
# xcov.report(
#   scheme: ENV['BUDDYBUILD_SCHEME'] || 'ScreenKitExample',
#   workspace: "#{ENV['BUDDYBUILD_WORKSPACE']}/ScreenKit.xcworkspace",
#   minimum_coverage_percentage: 10.0,
#   derived_data_path: ENV['BUDDYBUILD_TEST_DIR/],
#   source_directory: ENV['BUDDYBUILD_WORKSPACE']
# )

# Changelog
# modified_code = git.modified_files.include? 'ScreenKit/*.swift'
# updated_release_notes = git.modified_files.include? 'buddybuild_release_notes.txt'

# failure 'You forgot to update the release_notes_file ([docs](http://docs.buddybuild.com/docs/focus-message))' if modified_code && !updated_release_notes


# PR is a work in progress and shouldn't be merged yet
warn "PR is classed as Work in Progress" if github.pr_title.include? "WIP"

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

warn "A Plist was changed" if is_plist_change

## Carthage Checks
cartfile_updated = !git.modified_files.grep(/Cartfile$/).empty?
cartfile_lock_updated = !git.modified_files.grep(/Cartfile.lock$/).empty?
warn "The `Cartfile` was updated" if cartfile_updated
warn "The `Cartfile.lock` was updated" if cartfile_lock_updated
fail 'The `Cartfile` was updated but `Cartfile.lock` was not!' if cartfile_updated && !cartfile_lock_updated

# xcodebuild.json_file = "./fastlane/reports/xcpretty-json-formatter-results.json"

# xcodebuild.parse_warnings # returns number of warnings
# xcodebuild.parse_errors # returns number of errors
# xcodebuild.parse_tests # returns number of test failures
# xcodebuild.perfect_build # returns a bool indicating if the build was perfect
