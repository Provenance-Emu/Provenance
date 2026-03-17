# Provenance

Multi-platform emulator frontend for iOS, tvOS, watchOS, and macOS. Fork of [Provenance-Emu/Provenance](https://github.com/Provenance-Emu/Provenance).

## Stack

- **Language:** Swift / Objective-C
- **Platforms:** iOS 13+, tvOS 13+, watchOS 6+, macOS 10.15+
- **Build System:** Xcode (`.xcworkspace`)
- **Package Managers:** Swift Package Manager (SPM), XcodeGen (`project.yml`)
- **Build Automation:** Fastlane (via Bundler)
- **Ruby Tooling:** Use RVM (not rbenv) for Ruby version management
- **Key Dependencies:** Realm, RxSwift, CocoaLumberjack, SQLite.swift, ZipArchive, SteamController

## Build & Test

```bash
# Install Ruby gems (Fastlane, etc.)
bundle install

# Run tests via Fastlane
bundle exec fastlane test

# Build iOS (developer profile)
bundle exec fastlane build_developer scheme:Provenance-Release

# Build tvOS (developer profile)
bundle exec fastlane build_developer scheme:ProvenanceTV-Release

# Open workspace
open Provenance.xcworkspace

# Swift package build (library targets only)
swift build
```

## Project Structure

- `Provenance/` — Main iOS/tvOS app
- `ProvenanceTV/` — tvOS-specific app code
- `Provenance Watch WatchKit App/` — watchOS app
- `Provenance Watch WatchKit Extension/` — watchOS extension
- `Provenance Clip/` — App Clip
- `PVLibrary/` — Core library (ROM management, database)
- `PVSupport/` — Support framework (controllers, logging)
- `PVUI/` — UI framework
- `Cores/` — Emulator cores
- `ExperimentalCores/` — Experimental emulator cores
- `TopShelf/` — tvOS Top Shelf extension
- `Spotlight/` — iOS Spotlight extension
- `fastlane/` — Build/deploy automation
- `Scripts/` — Build scripts

## Conventions

- Use gitmoji prefixes for commit messages (e.g. `✨ feat`, `🐛 fix`, `♻️ refactor`, `📝 docs`, `✅ test`, `🔧 chore`)
- Open `Provenance.xcworkspace` (not `.xcodeproj`)
- Follow existing Swift API Design Guidelines naming conventions
