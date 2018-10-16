use_frameworks!

workspace "QuickTableViewController"
project "QuickTableViewController"

target "QuickTableViewController-iOSTests" do
  platform :ios, "8.0"
  pod "Nimble", git: "https://github.com/Quick/Nimble.git", tag: "v7.1.3"
  pod "Quick", git: "https://github.com/Quick/Quick.git", tag: "v1.3.1"
end

target "QuickTableViewController-tvOSTests" do
  platform :tvos, "9.0"
  pod "Nimble", git: "https://github.com/Quick/Nimble.git", tag: "v7.1.3"
  pod "Quick", git: "https://github.com/Quick/Quick.git", tag: "v1.3.1"
end

target "Example-iOS" do
  platform :ios, "8.0"
  pod "SwiftLint", podspec: "https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/4/0/1/SwiftLint/0.27.0/SwiftLint.podspec.json"
end

target "Example-tvOS" do
  platform :tvos, "9.0"
  pod "SwiftLint", podspec: "https://raw.githubusercontent.com/CocoaPods/Specs/master/Specs/4/0/1/SwiftLint/0.27.0/SwiftLint.podspec.json"
end
