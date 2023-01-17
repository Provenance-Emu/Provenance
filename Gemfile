# frozen_string_literal: true

source 'https://rubygems.org'

# Ruby 
gem 'dotenv'

# Fastlane
gem 'fastlane'
gem 'xcode-install'
# gem 'net-ssh'
# gem "net-scp"

gem 'badge'

# group :documentation do
#   gem 'jazzy'
# end

group :test do
  gem 'git_diff_parser'
  gem 'xcpretty'

  # gem 'danger'
  # gem 'danger-auto_label'
  # gem 'danger-jira'
  # gem 'danger-swiftlint'
  # gem 'danger-xcodebuild'

  # Danger plugin to validate the code coverage of the files changed
  #     - Gem:     danger-xcov
  #     - URL:     https://github.com/nakiostudio/danger-xcov
  # gem 'danger-xcov'

  # This is plugin for Danger that notify danger reports to slack.
  #     - Gem:     danger-slack
  #     - URL:     https://github.com/duck8823/danger-slack
  # gem 'danger-slack'
end

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
