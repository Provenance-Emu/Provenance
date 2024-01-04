Pod::Spec.new do |s|
  s.name = "RxRealm"
  # Version to always follow latest tag, with fallback to major
  s.version = "5.0.5"
  s.license = "MIT"
  s.description = <<-DESC
    This is an Rx extension that provides an easy and straight-forward way
    to use Realm's natively reactive collection type as an Observable
    DESC

  s.summary = "An Rx wrapper of Realm's notifications and write bindings"
  s.homepage = "https://github.com/RxSwiftCommunity/RxRealm"
  s.authors = { "RxSwift Community" => "community@rxswift.org" }
  s.source = { :git => "https://github.com/RxSwiftCommunity/RxRealm.git", :tag => "v" + s.version.to_s }
  s.swift_version = "5.1"

  s.ios.deployment_target = "11.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "3.0"

  s.requires_arc = true

  s.source_files = "Sources/RxRealm/*.swift"

  s.frameworks = "Foundation"
  s.dependency "Realm", "~> 10.21"
  s.dependency "RealmSwift", "~> 10.21"
  s.dependency "RxSwift", "~> 6.1"
  s.dependency "RxCocoa", "~> 6.1"
end
