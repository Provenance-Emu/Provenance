source "https://rubygems.org"

#gem 'multipart-post'
gem "fastlane"
gem 'travis'
gem 'net-ssh'
gem "net-scp"
gem "danger"
gem "danger-xcodebuild"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
