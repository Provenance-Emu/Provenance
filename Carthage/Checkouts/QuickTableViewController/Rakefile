require "fileutils"

def xcodebuild(params)
  return ":" unless params[:scheme]
  [
    %(xcodebuild),
    %(-workspace QuickTableViewController.xcworkspace),
    %(-scheme #{params[:scheme]}),
    %(-sdk #{params[:simulator]}),
    params[:destination],
    params[:action],
    %(| xcpretty -c && exit ${PIPESTATUS[0]})
  ].reject(&:nil?).join " "
end


namespace :build do
  desc "Build an iOS target with the specified scheme"
  task :ios, [:scheme] do |t, args|
    puts "Usage: rake 'build:ios[scheme]'" unless args[:scheme]

    sh xcodebuild(args.to_hash.merge({
      action: "clean build analyze",
      simulator: "iphonesimulator"
    }))
    exit $?.exitstatus if not $?.success?
  end

  desc "Build a tvOS target with the specified scheme"
  task :tvos, [:scheme] do |t, args|
    puts "Usage: rake 'build:tvos[scheme]'" unless args[:scheme]

    sh xcodebuild(args.to_hash.merge({
      action: "clean build analyze",
      simulator: "appletvsimulator"
    }))
    exit $?.exitstatus if not $?.success?
  end
end


namespace :test do
  desc "Run tests with the specified iOS scheme"
  task :ios, [:scheme] do |t, args|
    puts "Usage: rake 'test:ios[scheme]'" unless args[:scheme]

    sh xcodebuild(args.to_hash.merge({
      action: "-enableCodeCoverage YES clean test",
      destination: %(-destination "name=iPhone 8,OS=latest"),
      simulator: "iphonesimulator"
    }))
    exit $?.exitstatus if not $?.success?
  end

  desc "Run tests with the specified tvOS scheme"
  task :tvos, [:scheme] do |t, args|
    puts "Usage: rake 'test:tvos[scheme]'" unless args[:scheme]

    sh xcodebuild(args.to_hash.merge({
      action: "-enableCodeCoverage YES clean test",
      destination: %(-destination "name=Apple TV,OS=latest"),
      simulator: "appletvsimulator"
    }))
    exit $?.exitstatus if not $?.success?
  end
end


desc "Bump versions"
task :bump, [:version] do |t, args|
  version = args[:version]
  unless version
    puts "Usage: rake bump[version]"
    next
  end

  sh %(xcrun agvtool new-marketing-version #{version})

  podspec = "QuickTableViewController.podspec"
  text = File.read podspec
  File.write podspec, text.gsub(%r(\"\d+\.\d+\.\d+\"), "\"#{version}\"")
  puts "Updated #{podspec} to #{version}"

  jazzy = ".jazzy.yml"
  text = File.read jazzy
  File.write jazzy, text.gsub(%r(:\s\d+\.\d+\.\d+), ": #{version}")
  puts "Updated #{jazzy} to #{version}"
end
