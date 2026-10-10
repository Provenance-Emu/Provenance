# Dev Workspace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Tuist-generated `Provenance-Dev.xcworkspace` with small focused app targets, a launch-argument core harness, a content-hashed per-slice cache for the Azahar and Dolphin core builds, and prune the 32 dead native cores from the shipping project behind a `RetiredCoreMigration` path that keeps users' saves.

**Architecture:** Tuist 4.200.0 (pinned in `.mise.toml`) reads a repo-root `Tuist.swift`, `Workspace.swift` and `Dev/Project.swift`. The manifests are built from helper tables in `Tuist/ProjectDescriptionHelpers/` (`CoreProduct`, `FocusedApp`, `LibretroCores`, `DevSettings`). Cores that live in hand-maintained `Cores/<X>/*.xcodeproj` files are added to the generated workspace, linked by name and embedded by a script, because Tuist can only depend on targets of projects it generates. `Scripts/cores/build_slice.py` wraps the two CMake core builds and caches one slice per content key outside the tree. The shipping `Provenance.xcodeproj` stays the release path; batch 5 prunes it on a branch that CI validates.

**Tech Stack:** Tuist 4.200.0 (ProjectDescription API), mise, Swift 6 toolchain in Swift 5 language mode, SwiftPM, Python 3.9+ (stdlib only), bash, Ruby `xcodeproj` gem, GitHub Actions, Realm.

**Spec:** `docs/superpowers/specs/2026-10-10-dev-workspace-design.md` (audit input: `docs/superpowers/specs/2026-10-10-core-audit.md`)

## Global Constraints

- Tuist **4.200.0**, pinned in `.mise.toml` (`tuist = "4.200.0"`), always run as `mise exec -- tuist …` from the repo root.
- Generated files are never committed: `/Provenance-Dev.xcworkspace`, `/Dev/Provenance.xcodeproj`, `/Dev/Derived` are gitignored.
- The Tuist project is named `Provenance` and lives in `Dev/` (`Build.xcconfig` derives bundle ids, the app group and the iCloud container from `$(PROJECT_NAME:lower)`). `Provenance.xcodeproj` and `Provenance.xcworkspace` keep shipping; batches 1–4 must not change them except where a task says so.
- Every focused target is one multiplatform target. It must compile for **iOS Simulator and tvOS Simulator**. Guard with `#if os(iOS)` / `#if os(tvOS)`; never use `DragGesture`, `UIImpactFeedbackGenerator` or `UIDevice.current.orientation` on tvOS.
- Minimum targets: iOS 17, tvOS 17. Do not add availability guards for APIs that exist on iOS 17.
- Swift app code compares systems with the `SystemIdentifier` enum (`import PVSystems` or `PVPrimitives`), never with `"com.provenance.*"` string literals.
- `RetiredCoreMigration` and the retired-core table use no inline core-identifier strings. The file currently has none of its own and the table in `PVCore.swift` is one literal dictionary, so batch 5 adds named constants (`RetiredCoreID`, `LibretroCoreID`) and every entry, the Jaguar one included, uses them.
- Commits: conventional commits (`feat:`, `fix:`, `build:`, `ci:`, `refactor:`, `test:`, `docs:`, `chore:`), subject < 72 chars, body ends with the trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`, committed with `git -c commit.gpgsign=false commit`.
- Implementers never run `git reset`, `git rebase`, `git push`, or `git checkout` (of branches or files). Batches 1–4 and 6 commit on `develop`. Batch 5 commits on `feature/prune-dead-cores`, which the coordinator creates and pushes, and merges only after `build.yml` passes on both legs.
- Never edit a submodule in place (`Cores/Azahar/azahar`, `Cores/Dolphin/dolphin-ios`, any `Cores/<X>/<upstream>` directory). Do not edit `Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py` or `Cores/Azahar/build_azahar_core.py`.
- Never regenerate `Cores/Azahar/PVAzahar.xcodeproj` from `Cores/Azahar/project.yml`. Hand-edit the pbxproj and mirror the same change in the yml.
- Every new script under `Scripts/` or `CoresRetro/RetroArch/scripts/` is registered in `Scripts/maint/jobs.toml`, either as a job or under `[ignore]`.
- Build verification (main worktree only, because PVUI cannot build in a git worktree):
  - `mise exec -- tuist generate --no-open` (from the repo root)
  - `xcodebuild -workspace Provenance-Dev.xcworkspace -scheme <Scheme> -destination 'generic/platform=iOS Simulator' -skipPackagePluginValidation -skipMacroValidation -derivedDataPath /tmp/claude-501/dev-dd build`
  - the same command with `-destination 'generic/platform=tvOS Simulator'`
  - launch check (iOS): `xcrun simctl install booted /tmp/claude-501/dev-dd/Build/Products/Debug-iphonesimulator/<App>.app && xcrun simctl launch --console-pty booted <bundle id>` must print the app's startup log, not a dyld error (simulator builds are ad-hoc signed by `Dev/Config/Dev.xcconfig`; do not pass `CODE_SIGNING_ALLOWED=NO`)
  - Pipe to `tee /tmp/claude-501/<task>.log | tail -40`. A Run Script failure prints no `error:` line, so read the `The following build commands failed:` block.
  - Never run two `xcodebuild`s against `/tmp/claude-501/dev-dd` at once.
- PVLibrary tests: `cd PVLibrary && xcodebuild test -workspace .swiftpm/xcode/package.xcworkspace -scheme PVLibrary-UnitTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation` (add `-only-testing:PVLibraryTests/<Class>` to scope). On Xcode 26.6, add `-xcconfig` with `OTHER_CFLAGS = $(inherited) -Wno-invalid-specialization` and `OTHER_CPLUSPLUSFLAGS = $(inherited) -Wno-invalid-specialization`.
- Lint every changed Swift file: `swiftlint lint --path <file>`.
- Model tier per task is stated in the task header (haiku = transcription from this plan, sonnet = default, opus = judgement across many files).

## Deviations from the spec, decided here

1. **Helper location.** Tuist compiles helpers from `<root>/Tuist/ProjectDescriptionHelpers`, where `<root>` is the directory that holds `Tuist.swift`. With `Tuist.swift` at the repo root, the helpers go in `Tuist/ProjectDescriptionHelpers/` at the repo root, not `Dev/Tuist/…`. A `Dev/Tuist/` directory would make `Dev/` a second root.
2. **`CoreLink.project` is not a Tuist `.project` dependency.** `TargetDependency.project(target:path:)` only resolves Tuist-generated projects. For a hand-maintained `Cores/<X>/*.xcodeproj`, the plan does three things:
   - lists the `.xcodeproj` in `Workspace.additionalFiles` (a workspace `FileRef` to an `.xcodeproj` is a project, the same way `Provenance.xcworkspace` lists cores);
   - links the product with `OTHER_LDFLAGS -framework <Product>`, so Xcode adds the producing target as an implicit dependency, as it does for the shipping app's `BUILT_PRODUCTS_DIR` references;
   - embeds and signs the product with a post script.
3. **Manifest tests** compile the helper sources together with `Dev/Tests/ManifestChecks/main.swift` against the `ProjectDescription.framework` shipped inside the pinned Tuist install, through `Scripts/dev/check_dev_manifest.sh`. `ProjectDescription` is not a SwiftPM product, so the helpers cannot be tested with `swift test` as a package.
4. **Libretro URL lists.** The pre script takes each name's URL from the generated `urls.txt` / `urls-tv.txt` instead of formatting it. Neutral filenames (`ppsspp_libretro.dylib.zip`) have no `_ios`/`_tvos` suffix.
5. **`get-modules.sh --urls`** keeps its download state in a sibling directory `modules_compressed/<iOS|tvOS>-urls-<sha12>` and skips manifest pruning. Otherwise one focused build would delete about 100 dylibs from the `modules/` directory that shipping builds share.
6. **`build_slice.py`** calls the builders' per-platform methods (`AzaharBuilder.build_platform`, `DolphinBuilder.build_platform` + `create_framework`) in a subprocess instead of their `main()`. Both `main()`s repack the xcframework and `rmtree` the slice path, which would break on the cache symlink. For Dolphin it also packs `PVlibDolphin.xcframework` when that file is missing, because `PVDolphin.xcodeproj` links the xcframework, which Xcode resolves while planning.
7. **`Cores/Debug` is kept.** `PVMupen64Plus.xcodeproj`, `PVDolphin.xcodeproj`, `PVPPSSPP.xcodeproj` and `Provenance.xcodeproj` reference `Cores/Debug/PVDebug.c` (the simulator stub). The prune list is therefore 32 cores, not 33.
8. **The harness counts frames by time.** No core exposes a public frame counter (`PVMetalViewController.frameCount` is internal), so `frames.json` records the requested frame count, the core's `frameInterval` and the measured wait, and says `"frameCountSource": "estimated"`.
9. **`make dev-generate` pre-builds only cores linked as `.prebuilt`** (listed in `DEV_PREBUILT_CORES`, empty by default). `project` links resolve lazily, so Azahar needs no slice before `tuist generate`; its aggregate builds the slice during the app build.

## File map

| Path | Created/modified in | Responsibility |
|---|---|---|
| `.mise.toml` | T1 | Tuist pin |
| `Tuist.swift` | T1 | Tuist config (root marker) |
| `Workspace.swift` | T1, T2, T3 | `Provenance-Dev` workspace, vendored core projects |
| `Tuist/ProjectDescriptionHelpers/CoreProduct.swift` | T2, T3, T5 | `CoreLink`, `CoreProduct`, the core table |
| `Tuist/ProjectDescriptionHelpers/DevSettings.swift` | T2, T3, T10 | packages, shared settings, configurations, embed script |
| `Tuist/ProjectDescriptionHelpers/FocusedApp.swift` | T2, T3, T7, T8, T10 | target template, `FocusedApp.all` |
| `Tuist/ProjectDescriptionHelpers/LibretroCores.swift` | T7 | libretro pre/post scripts |
| `Dev/Project.swift` | T2 | `Project(name: "Provenance")` |
| `Dev/Config/Dev.xcconfig` | T2 | includes `Build-iOS.xcconfig`, repo-relative path overrides |
| `Dev/Tests/ManifestChecks/main.swift` | T4 | manifest assertions |
| `Scripts/dev/check_dev_manifest.sh` | T4 | compiles and runs the checks |
| `CoresRetro/RetroArch/scripts/get-modules.sh` | T6 | `--urls <file>` |
| `Scripts/tests/test-get-modules-validation.sh` | T6 | `--urls` test |
| `PVDevHarness/` | T9, T10 | harness package (`PVDevHarnessKit` pure logic, `PVDevHarness` runtime) |
| `Provenance/Main UI/ProvenanceApp.swift` | T10 | `#if PV_DEV_HARNESS` hook |
| `Scripts/cores/build_slice.py` | T12 | slice cache |
| `Scripts/cores/tests/test_build_slice.py` | T12 | its unit tests |
| `Cores/Azahar/project.yml`, `Cores/Azahar/PVAzahar.xcodeproj/project.pbxproj` | T13 | aggregate calls `build_slice.py` |
| `Cores/Dolphin/PVDolphin.xcodeproj/project.pbxproj` | T13 | aggregate calls `build_slice.py` |
| `Scripts/maint/jobs.toml` | T4, T12, T13, T18 | registry |
| `.github/workflows/build.yml`, `testflight.yml`, `dev-workspace.yml` | T14, T19 | caches, dev smoke build |
| `Makefile` | T3, T8, T11, T13 | `dev`, `dev-generate`, `dev-ui`, `dev-azahar`, `dev-thin`, `dev-harness` |
| `PVLibrary/Sources/PVRealm/RealmPlatform/Entities/PVCore.swift` | T15, T17 | retired-core model and table |
| `PVLibrary/Sources/PVLibrary/Migration/RetiredCoreMigration.swift` | T15 | per-system, save-state-aware migration |
| `PVLibrary/Sources/PVLibrary/Migration/RetiredBatterySaveMigration.swift` | T16 | battery file pass |
| `PVLibrary/Sources/PVLibrary/Configuration/PVEmulatorConfiguration+Frameworks.swift` | T15, T16 | prune guard, battery pass launch |
| `Scripts/dev/prune_cores.rb` | T18 | pbxproj/workspace/submodule pruning |
| `CLAUDE.md`, `.claude/skills/fast-iteration/SKILL.md`, `docs/RELEASE_SMOKE_TESTS.md`, roadmap | T20, T21 | docs |

---

# Batch 1 — Tooling and the first target (develop)

### Task 1: Tuist pin, root manifests, gitignore  *(model: haiku)*

**Files:**
- Create: `.mise.toml`, `Tuist.swift`, `Workspace.swift`
- Modify: `.gitignore` (append)
- Delete: `project.yml` (repo root only; the 2021 `Provenance-SPM` xcodegen spec, unused)

**Interfaces:**
- Produces: a repo-root Tuist root; `Workspace(name: "Provenance-Dev", projects: ["Dev"])`, which Task 2 extends.

- [ ] **Step 1: Confirm the pinned Tuist is installed**

Run: `ls ~/.local/share/mise/installs/tuist/4.200.0/bin/tuist`
Expected: the path prints. If it doesn't, run `mise install tuist@4.200.0`.

- [ ] **Step 2: Write `.mise.toml`**

```toml
# Tool versions for the dev workspace (`make dev`). Tuist generates
# Provenance-Dev.xcworkspace; CI (.github/workflows/dev-workspace.yml) installs the same pin.
[tools]
tuist = "4.200.0"
```

- [ ] **Step 3: Write `Tuist.swift`**

```swift
import ProjectDescription

// Marks the repo root as the Tuist root, so manifests and helpers resolve
// `.relativeToRoot(...)` paths against it. Helpers live in Tuist/ProjectDescriptionHelpers.
let tuist = Tuist(
    compatibleXcodeVersions: .upToNextMajor("26.0")
)
```

- [ ] **Step 4: Write the first `Workspace.swift`**

```swift
import ProjectDescription

let workspace = Workspace(
    name: "Provenance-Dev",
    projects: ["Dev"],
    additionalFiles: ["docs/superpowers/specs/*.md"]
)
```

- [ ] **Step 5: Append to `.gitignore`**

```gitignore
# Tuist dev workspace (generated by `make dev-generate`; never commit)
/Provenance-Dev.xcworkspace
/Dev/Provenance.xcodeproj
/Dev/Derived
/Tuist/.build
```

- [ ] **Step 6: Delete the dead root xcodegen spec**

Run: `git rm -q project.yml`
Expected: no output. `git status --short project.yml` shows `D  project.yml`.

- [ ] **Step 7: Verify**

Run: `mise exec -- tuist version && git check-ignore -v Provenance-Dev.xcworkspace Dev/Provenance.xcodeproj Dev/Derived`
Expected: `4.200.0`, then three `.gitignore:` lines.

- [ ] **Step 8: Commit**

```bash
git add .mise.toml Tuist.swift Workspace.swift .gitignore
git -c commit.gpgsign=false commit -m "build: pin Tuist 4.200.0 and add the dev workspace root" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: Helpers, `Dev/Project.swift`, and a package-only `Provenance-Dev-UI`  *(model: sonnet)*

The first target links only SwiftPM products (mGBA, Stella, PVCheevos, MoltenVK). Task 3 adds the cores that come from `.xcodeproj` files.

**Files:**
- Create: `Tuist/ProjectDescriptionHelpers/CoreProduct.swift`
- Create: `Tuist/ProjectDescriptionHelpers/DevSettings.swift`
- Create: `Tuist/ProjectDescriptionHelpers/FocusedApp.swift`
- Create: `Dev/Config/Dev.xcconfig`
- Create: `Dev/Project.swift`

**Interfaces:**
- Produces (exact names later tasks use):
  - `public enum CoreLink { case package(path: String, product: String); case project(path: String, target: String, product: String); case prebuilt(path: String) }`. Paths are repo-relative strings.
  - `public struct CoreProduct { id: String; link: CoreLink; embeds: [CoreLink]; platforms: Set<PlatformFilter>; needsAggregate: String? }`, with static rows `CoreProduct.mGBA`, `.stella`, `.cheevos`, `.moltenVK`, the arrays `CoreProduct.nonCore` and `CoreProduct.all`, and `var links: [CoreLink]`.
  - `public struct FocusedApp { slug: String; title: String; cores: [CoreProduct]; libretro: [String]; flags: [String]; name: String; func target() -> Target; func scheme() -> Scheme }` and `public static let all: [FocusedApp]`.
  - `public enum DevSettings` with `static func packages(for apps: [FocusedApp]) -> [Package]`, `static func localPackagePaths(for apps: [FocusedApp]) -> [String]`, `static let projectSettings: Settings`, `static func appSettings(for app: FocusedApp) -> Settings`, `static let appResources: ResourceFileElements`, `static let appDependencies: [TargetDependency]`.

- [ ] **Step 1: Write `Tuist/ProjectDescriptionHelpers/CoreProduct.swift`**

```swift
import ProjectDescription

/// How the dev app consumes a core or a support framework.
/// Paths are repo-relative (the Tuist root is the repo root).
public enum CoreLink: Equatable {
    /// A dynamic product of a local Swift package.
    case package(path: String, product: String)
    /// A framework target of a hand-maintained `.xcodeproj`. Tuist can only depend on targets
    /// of projects it generates, so the project is listed in the workspace, the product is
    /// linked by name (Xcode schedules the producer as an implicit dependency) and a post
    /// script embeds it. See `DevSettings.embedProjectFrameworksScript`.
    case project(path: String, target: String, product: String)
    /// A `.framework` / `.xcframework` on disk. Tuist reads it at generate time, so it must exist.
    case prebuilt(path: String)

    /// Every repo-relative path this link needs (for the manifest checks).
    public var paths: [String] {
        switch self {
        case let .package(path, _): return [path, path + "/Package.swift"]
        case let .project(path, _, _): return [path]
        case let .prebuilt(path): return [path]
        }
    }
}

/// One audited core (see docs/superpowers/specs/2026-10-10-core-audit.md, KEEP rows) or a
/// non-core product every app embeds. Only how the app consumes it lives here.
public struct CoreProduct {
    public let id: String
    public let link: CoreLink
    /// Extra frameworks the app must embed (Mupen plugins, PVlibDolphin).
    public let embeds: [CoreLink]
    /// Platforms the shipping target links it on.
    public let platforms: Set<PlatformFilter>
    /// Aggregate target that builds the core's out-of-tree library ("BuildPVlibAzahar", "Make XCFrameworks").
    public let needsAggregate: String?

    public init(
        id: String,
        link: CoreLink,
        embeds: [CoreLink] = [],
        platforms: Set<PlatformFilter> = [.ios, .tvos],
        needsAggregate: String? = nil
    ) {
        self.id = id
        self.link = link
        self.embeds = embeds
        self.platforms = platforms
        self.needsAggregate = needsAggregate
    }

    /// `link` followed by `embeds`.
    public var links: [CoreLink] { [link] + embeds }
}

public extension CoreProduct {
    // MARK: KEEP cores (product names copied from Provenance.xcodeproj embed phases)

    static let mGBA = CoreProduct(id: "mgba", link: .package(path: "Cores/mGBA", product: "PVCoremGBA-Dynamic"))
    static let stella = CoreProduct(id: "stella", link: .package(path: "Cores/Stella", product: "PVStella-Dynamic"))

    // MARK: Non-core products every app embeds

    static let cheevos = CoreProduct(id: "pvcheevos", link: .package(path: "PVCheevos", product: "PVCheevos"))
    static let moltenVK = CoreProduct(id: "moltenvk", link: .package(path: "MoltenVK", product: "MoltenVK"))

    /// Linked into every focused app.
    static let nonCore: [CoreProduct] = [.cheevos, .moltenVK]

    /// Every row, for the manifest checks.
    static let all: [CoreProduct] = [.mGBA, .stella] + nonCore
}
```

- [ ] **Step 2: Write `Tuist/ProjectDescriptionHelpers/DevSettings.swift`**

Package versions are copied from the root `packageReferences` of `Provenance.xcodeproj/project.pbxproj`. The product list is `Provenance-Lite (AppStore)`'s package products minus its cores.

```swift
import ProjectDescription

public enum DevSettings {
    /// Base xcconfig for the project and every app target (repo-relative).
    public static let xcconfig: Path = .relativeToRoot("Dev/Config/Dev.xcconfig")

    // MARK: Packages

    /// Local packages whose products the app links directly (Provenance-Lite (AppStore) minus cores).
    static let appLocalPackages: [String] = [
        "PVEmulatorCore", "PVCoreAudio", "PVWebServer", "PVLibrary", "PVLogging", "PVThemes",
        "PVPlists", "PVSettings", "PVUI", "PVFeatureFlags", "PVJIT",
    ]

    static let remotePackages: [Package] = [
        .remote(url: "https://github.com/Provenance-Emu/SteamController.git", requirement: .revision("55d2fe0484f4cc5ed3535033af6b0218621e37b2")),
        .remote(url: "https://github.com/ashleymills/Reachability.swift", requirement: .branch("master")),
        .remote(url: "https://github.com/RxSwiftCommunity/RxDataSources.git", requirement: .upToNextMajor(from: "5.0.2")),
        .remote(url: "https://github.com/ZipArchive/ZipArchive.git", requirement: .upToNextMajor(from: "2.5.5")),
        .remote(url: "https://github.com/jdg/MBProgressHUD.git", requirement: .upToNextMajor(from: "1.2.0")),
        .remote(url: "https://github.com/realm/realm-swift.git", requirement: .upToNextMajor(from: "20.0.3")),
        .remote(url: "https://github.com/sindresorhus/Defaults.git", requirement: .exact("9.0.2")),
        .remote(url: "https://github.com/theappcapital/SiriusRating-iOS.git", requirement: .upToNextMajor(from: "1.0.8")),
        .remote(url: "https://github.com/FlineDev/FreemiumKit.git", requirement: .upToNextMajor(from: "1.19.0")),
        .remote(url: "https://github.com/SvenTiigi/WhatsNewKit.git", requirement: .upToNextMajor(from: "2.2.1")),
        .remote(url: "https://github.com/krzyzanowskim/OpenSSL", requirement: .upToNextMajor(from: "3.3.2000")),
    ]

    /// Every local package the apps need, each exactly once (a duplicate `.local(path:)`
    /// fails `tuist generate`). Sorted for stable output.
    public static func localPackagePaths(for apps: [FocusedApp]) -> [String] {
        var paths = Set(appLocalPackages)
        for app in apps {
            for core in app.allCores {
                for link in core.links {
                    if case let .package(path, _) = link { paths.insert(path) }
                }
            }
        }
        return paths.sorted()
    }

    public static func packages(for apps: [FocusedApp]) -> [Package] {
        localPackagePaths(for: apps).map { .local(path: .relativeToRoot($0)) } + remotePackages
    }

    /// Package products every focused app links (Provenance-Lite (AppStore) minus its cores).
    public static let appDependencies: [TargetDependency] = [
        .package(product: "SteamController"),
        .package(product: "Reachability"),
        .package(product: "RxDataSources"),
        .package(product: "ZipArchive"),
        .package(product: "PVEmulatorCore"),
        .package(product: "PVCoreAudio"),
        .package(product: "PVWebServer"),
        .package(product: "PVLibrary"),
        .package(product: "PVLogging"),
        .package(product: "MBProgressHUD"),
        .package(product: "RealmSwift"),
        .package(product: "PVThemes"),
        .package(product: "PVPlists"),
        .package(product: "PVSettings"),
        .package(product: "PVUI"),
        .package(product: "Defaults"),
        .package(product: "SiriusRating", condition: .when([.ios])),
        .package(product: "FreemiumKit"),
        .package(product: "PVFeatureFlags"),
        .package(product: "WhatsNewKit", condition: .when([.ios])),
        .package(product: "OpenSSL"),
        .package(product: "JITManager"),
        .package(product: "PVJIT"),
        .sdk(name: "z", type: .library),
        .sdk(name: "c++", type: .library),
        .sdk(name: "xml2", type: .library),
        .sdk(name: "bz2", type: .library),
    ]

    // MARK: Resources (Provenance-Lite (AppStore) resources phase)

    public static let appResources: ResourceFileElements = [
        .glob(pattern: .relativeToRoot("Provenance/*.lproj/InfoPlist.strings")),
        .glob(pattern: .relativeToRoot("Provenance/Resources/*.lproj/Strings.strings")),
        .glob(pattern: .relativeToRoot("Provenance/Resources/AppStoreAssets-Lite.xcassets")),
        .glob(pattern: .relativeToRoot("Provenance/Resources/Assets-Lite.xcassets")),
        .glob(pattern: .relativeToRoot("Provenance/Resources/ColoredIcons.xcassets")),
        .folderReference(path: .relativeToRoot("Provenance/Resources/Settings.bundle")),
        .glob(pattern: .relativeToRoot("Provenance/licenses.html")),
        .glob(pattern: .relativeToRoot("CONTRIBUTORS.md")),
        .glob(pattern: .relativeToRoot("SYSTEMS.md")),
        .glob(pattern: .relativeToRoot("ProvenanceTV/LaunchImageTV.png"), inclusionCondition: .when([.tvos])),
        .glob(pattern: .relativeToRoot("ProvenanceTV/TVAssets.xcassets"), inclusionCondition: .when([.tvos])),
        .glob(pattern: .relativeToRoot("ProvenanceTV/LaunchScreenTV.storyboard"), inclusionCondition: .when([.tvos])),
        .glob(pattern: .relativeToRoot("ProvenanceTV/Story Boards/*.lproj/*.storyboard"), inclusionCondition: .when([.tvos])),
    ]

    // MARK: Settings

    /// Project-level settings (the shipping project's COMMON block that is not in Build.xcconfig).
    public static let projectSettings: Settings = .settings(
        base: [
            "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
            "ENABLE_BITCODE": "NO",
            "SWIFT_VERSION": "5.0",
        ],
        configurations: [
            .debug(name: .debug, xcconfig: xcconfig),
            .release(name: .release, xcconfig: xcconfig),
        ],
        defaultSettings: .recommended
    )

    /// Target settings for a focused app. Bundle id and product name are per configuration
    /// (a target-level PRODUCT_BUNDLE_IDENTIFIER from `Target.bundleId` would also work, but
    /// per-configuration keeps the iCube pattern and lets Release differ later).
    public static func appSettings(for app: FocusedApp) -> Settings {
        let perConfiguration: SettingsDictionary = [
            "ALPHA_BUNDLE_SUFFIX": .string(".dev.\(app.slug)"),
            "PRODUCT_BUNDLE_IDENTIFIER": "$(ORG_PREFIX).$(PROJECT_NAME:lower)$(ALPHA_BUNDLE_SUFFIX)",
            "PRODUCT_NAME": .string(app.name),
        ]
        var base: SettingsDictionary = [
            "SWIFT_ACTIVE_COMPILATION_CONDITIONS": .string((["$(inherited)", "PV_DEV"] + app.flags).joined(separator: " ")),
            "ENABLE_USER_SCRIPT_SANDBOXING": "NO",
            "CODE_SIGN_STYLE": "Automatic",
            "GCC_PREPROCESSOR_DEFINITIONS": ["$(inherited)", "APP_STORE=1", "GL_SILENCE_DEPRECATION=1"],
            "OTHER_SWIFT_FLAGS": ["$(inherited)", "-DAPP_STORE", "-DAPPSTORE"],
            "LD_RUNPATH_SEARCH_PATHS": [
                "$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks",
                "@executable_path/Frameworks/MoltenVK.framework",
            ],
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            // Tuist's .recommended defaults inject the more specific appletvos*/appletvsimulator*
            // keys, which outrank an [sdk=appletv*] override. Pin them (iCube lesson).
            "ASSETCATALOG_COMPILER_APPICON_NAME[sdk=appletvos*]": "App Icon & Top Shelf Image",
            "ASSETCATALOG_COMPILER_APPICON_NAME[sdk=appletvsimulator*]": "App Icon & Top Shelf Image",
            "ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS": "YES",
            "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.arcade-games",
            "SUPPORTS_MACCATALYST": "NO",
            "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "YES",
            "SWIFT_EMIT_LOC_STRINGS": "YES",
            "MTL_FAST_MATH": "YES",
            "DEAD_CODE_STRIPPING": "YES",
        ]
        base.merge(app.linkerSettings) { _, new in new }
        return .settings(
            base: base,
            configurations: [
                .debug(name: .debug, settings: perConfiguration, xcconfig: xcconfig),
                .release(name: .release, settings: perConfiguration, xcconfig: xcconfig),
            ],
            defaultSettings: .recommended(excluding: ["ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME"])
        )
    }
}
```

- [ ] **Step 3: Write `Tuist/ProjectDescriptionHelpers/FocusedApp.swift`**

```swift
import ProjectDescription

/// A small app target that embeds only the cores it lists. Add a target by appending
/// one literal to `FocusedApp.all`.
public struct FocusedApp {
    /// Lowercase id: bundle suffix `.dev.<slug>`.
    public let slug: String
    /// Name suffix: target and scheme `Provenance-Dev-<title>`.
    public let title: String
    public let cores: [CoreProduct]
    /// cores.yml names whose buildbot dylibs the app embeds.
    public let libretro: [String]
    /// SWIFT_ACTIVE_COMPILATION_CONDITIONS additions.
    public let flags: [String]

    public init(slug: String, title: String, cores: [CoreProduct], libretro: [String] = [], flags: [String] = []) {
        self.slug = slug
        self.title = title
        self.cores = cores
        self.libretro = libretro
        self.flags = flags
    }

    public var name: String { "Provenance-Dev-\(title)" }

    /// `cores` plus the non-core products every app embeds.
    public var allCores: [CoreProduct] { CoreProduct.nonCore + cores }

    /// OTHER_LDFLAGS for `project` links (empty until Task 3).
    var linkerSettings: SettingsDictionary { [:] }

    var coreDependencies: [TargetDependency] {
        allCores.flatMap { core -> [TargetDependency] in
            core.links.compactMap { link -> TargetDependency? in
                switch link {
                case let .package(_, product):
                    return .package(product: product, condition: .when(core.platforms))
                case let .prebuilt(path):
                    return path.hasSuffix(".xcframework")
                        ? .xcframework(path: .relativeToRoot(path), condition: .when(core.platforms))
                        : .framework(path: .relativeToRoot(path), condition: .when(core.platforms))
                case .project:
                    return nil
                }
            }
        }
    }

    public func target() -> Target {
        .target(
            name: name,
            destinations: [.iPhone, .iPad, .appleTv, .macWithiPadDesign],
            product: .app,
            productName: name,
            // Placeholder: PRODUCT_BUNDLE_IDENTIFIER is set per configuration in DevSettings.
            bundleId: "org.provenance-emu.provenance.dev.\(slug)",
            deploymentTargets: .multiplatform(iOS: "17.0", tvOS: "17.0"),
            infoPlist: .file(path: .relativeToRoot("Provenance/Provenance-Lite (AppStore)-Info.plist")),
            sources: [.glob(.relativeToRoot("Provenance/Main UI/**/*.swift"))],
            resources: DevSettings.appResources,
            entitlements: nil,
            scripts: [],
            dependencies: DevSettings.appDependencies + coreDependencies,
            settings: DevSettings.appSettings(for: self)
        )
    }

    public func scheme() -> Scheme {
        .scheme(
            name: name,
            shared: true,
            buildAction: .buildAction(targets: [.target(name)]),
            runAction: .runAction(configuration: .debug, executable: .target(name)),
            archiveAction: .archiveAction(configuration: .release)
        )
    }
}

public extension FocusedApp {
    static let ui = FocusedApp(slug: "ui", title: "UI", cores: [.mGBA, .stella], flags: ["PV_DEV_HARNESS"])

    static let all: [FocusedApp] = [.ui]
}
```

- [ ] **Step 4: Write `Dev/Config/Dev.xcconfig`**

```
// Base config for Dev/Provenance.xcodeproj (Tuist-generated; see Tuist/ProjectDescriptionHelpers).
// Build.xcconfig's path-valued settings are relative to the shipping project's SRCROOT (the
// repo root). This project's SRCROOT is Dev/, so those settings are restated here.
#include "../../Build-iOS.xcconfig"

PV_REPO_ROOT = $(SRCROOT)/..

// Provenance-Lite (AppStore) entitlements (Build.xcconfig's selector would resolve Dev/Provenance/...)
CODE_SIGN_ENTITLEMENTS = $(PV_REPO_ROOT)/Provenance/Provenance-AppStore.entitlements
CODE_SIGN_ENTITLEMENTS[sdk=appletvos*] = $(PV_REPO_ROOT)/ProvenanceTV/ProvenanceTV-AppStore.entitlements
CODE_SIGN_ENTITLEMENTS[sdk=appletvsimulator*] = $(PV_REPO_ROOT)/ProvenanceTV/ProvenanceTV-AppStore.entitlements

TVOS_DEPLOYMENT_TARGET = 17.0
```

- [ ] **Step 5: Write `Dev/Project.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

// Named "Provenance" on purpose: Build.xcconfig derives bundle ids, the app group and the
// iCloud container from $(PROJECT_NAME:lower). Generated into Dev/ so it never overwrites
// the shipping Provenance.xcodeproj.
let project = Project(
    name: "Provenance",
    options: .options(
        automaticSchemesOptions: .disabled,
        disableBundleAccessors: true,
        disableSynthesizedResourceAccessors: true
    ),
    packages: DevSettings.packages(for: FocusedApp.all),
    settings: DevSettings.projectSettings,
    targets: FocusedApp.all.map { $0.target() },
    schemes: FocusedApp.all.map { $0.scheme() }
)
```

- [ ] **Step 6: Point `Workspace.swift` at the helpers**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
    name: "Provenance-Dev",
    projects: ["Dev"],
    additionalFiles: ["docs/superpowers/specs/*.md"]
)
```

- [ ] **Step 7: Generate**

Run: `mise exec -- tuist generate --no-open 2>&1 | tail -20`
Expected: `Project generated.` The paths `Provenance-Dev.xcworkspace` and `Dev/Provenance.xcodeproj` exist.
If generation fails on a package product name, compare it with `grep -A3 '.library(' <pkg>/Package.swift` and fix the string in `DevSettings.appDependencies`. Do not drop the product.

- [ ] **Step 8: Build for iOS Simulator**

Run: `xcodebuild -workspace Provenance-Dev.xcworkspace -scheme Provenance-Dev-UI -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO -skipPackagePluginValidation -skipMacroValidation -derivedDataPath /tmp/claude-501/dev-dd build 2>&1 | tee /tmp/claude-501/t2-ios.log | tail -40`
Expected: `** BUILD SUCCEEDED **`.
If a path-valued build setting fails (`no such file`), restate it in `Dev/Config/Dev.xcconfig` against `$(PV_REPO_ROOT)`. Keep the shipping files unchanged.

- [ ] **Step 9: Build for tvOS Simulator**

Run: the Step 8 command with `-destination 'generic/platform=tvOS Simulator'` and log `/tmp/claude-501/t2-tvos.log`.
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 10: Check the bundle id**

Run: `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' /tmp/claude-501/dev-dd/Build/Products/Debug-iphonesimulator/Provenance-Dev-UI.app/Info.plist`
Expected: `org.provenance-emu.provenance.dev.ui`. If `CodeSigning.xcconfig` overrides `ORG_IDENTIFIER`, the prefix is yours.

- [ ] **Step 11: Lint and commit**

Run: `swiftlint lint --path Tuist/ProjectDescriptionHelpers --path Dev/Project.swift --path Workspace.swift`. Fix any errors; warnings in manifests are acceptable.

```bash
git add Tuist Dev/Project.swift Dev/Config/Dev.xcconfig Workspace.swift
git -c commit.gpgsign=false commit -m "build: add Tuist dev project with Provenance-Dev-UI" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: Project-linked cores, snes9x, PVCoreBridgeRetro, `make dev`  *(model: sonnet)*

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/CoreProduct.swift` (rows `snes9x`, `coreBridgeRetro`; add `coreBridgeRetro` to `nonCore`; `all`)
- Modify: `Tuist/ProjectDescriptionHelpers/FocusedApp.swift` (`linkerSettings`, project embed script, `workspaceProjects`)
- Modify: `Tuist/ProjectDescriptionHelpers/DevSettings.swift` (add `embedProjectFrameworksScript`)
- Modify: `Workspace.swift`
- Modify: `Makefile` (targets `dev`, `dev-generate`, `dev-ui`; `.PHONY`)

**Interfaces:**
- Consumes: `CoreLink`, `CoreProduct`, `FocusedApp`, `DevSettings` from Task 2.
- Produces:
  - `CoreProduct.snes9x` and `CoreProduct.coreBridgeRetro`.
  - `FocusedApp.workspaceProjects(for apps: [FocusedApp]) -> [String]` (repo-relative `.xcodeproj` paths, unique, sorted).
  - `DevSettings.embedProjectFrameworksScript(products: [String]) -> TargetScript`.
  - Make targets `dev`, `dev-generate`, `dev-ui`, plus the variables `TUIST ?= mise exec -- tuist`, `DEV_WORKSPACE := Provenance-Dev.xcworkspace` and `DEV_DERIVED ?= $(CURDIR)/build/dev-dd`.

- [ ] **Step 1: Add the project rows to `CoreProduct.swift`**

Insert after `stella`:

```swift
    // PVSNES9x.xcodeproj: target "PVSNES9x" builds PVSNES.framework, target "snes9x" builds snes9x.framework.
    static let snes9x = CoreProduct(
        id: "snes9x",
        link: .project(path: "Cores/snes9x/PVSNES9x.xcodeproj", target: "PVSNES9x", product: "PVSNES"),
        embeds: [.project(path: "Cores/snes9x/PVSNES9x.xcodeproj", target: "snes9x", product: "snes9x")]
    )
```

Insert before `nonCore`:

```swift
    static let coreBridgeRetro = CoreProduct(
        id: "pvcorebridgeretro",
        link: .project(path: "PVCoreBridgeRetro/PVCoreBridgeRetro.xcodeproj", target: "PVCoreBridgeRetro", product: "PVCoreBridgeRetro")
    )
```

Then change the two arrays to:

```swift
    static let nonCore: [CoreProduct] = [.cheevos, .moltenVK, .coreBridgeRetro]

    static let all: [CoreProduct] = [.mGBA, .stella, .snes9x] + nonCore
```

- [ ] **Step 2: Add the embed script to `DevSettings.swift`**

Add inside `enum DevSettings`:

```swift
    /// Copies frameworks built by the workspace's vendored .xcodeproj files into the app and
    /// signs them (ad-hoc when signing is off). Tuist can't embed products of projects it
    /// doesn't generate; the matching `-framework` linker flags make Xcode build them first.
    public static func embedProjectFrameworksScript(products: [String]) -> TargetScript {
        .post(
            script: """
            set -euo pipefail
            dest="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
            mkdir -p "$dest"
            identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
            if [ -z "$identity" ] || [ "${CODE_SIGNING_ALLOWED:-YES}" = "NO" ]; then identity="-"; fi
            for fw in \(products.joined(separator: " ")); do
              src="${BUILT_PRODUCTS_DIR}/${fw}.framework"
              if [ ! -d "$src" ]; then
                echo "error: ${fw}.framework was not built (expected ${src}); is its project in Provenance-Dev.xcworkspace?"
                exit 1
              fi
              /usr/bin/rsync -a --delete --exclude Headers --exclude PrivateHeaders --exclude Modules "$src/" "$dest/${fw}.framework/"
              /usr/bin/codesign --force --sign "$identity" --preserve-metadata=identifier,entitlements "$dest/${fw}.framework"
            done
            """,
            name: "Embed core frameworks",
            basedOnDependencyAnalysis: false
        )
    }
```

- [ ] **Step 3: Implement the project links in `FocusedApp.swift`**

Replace the `linkerSettings` stub with:

```swift
    /// Products of `project` links, in table order, without duplicates.
    var projectProducts: [(product: String, platforms: Set<PlatformFilter>)] {
        var seen = Set<String>()
        var result: [(product: String, platforms: Set<PlatformFilter>)] = []
        for core in allCores {
            for link in core.links {
                if case let .project(_, _, product) = link, seen.insert(product).inserted {
                    result.append((product, core.platforms))
                }
            }
        }
        return result
    }

    /// `-framework <Product>` per project link. Platform-limited rows get an sdk-conditioned key.
    var linkerSettings: SettingsDictionary {
        func flags(_ filter: (Set<PlatformFilter>) -> Bool) -> [String] {
            projectProducts.filter { filter($0.platforms) }.flatMap { ["-framework", $0.product] }
        }
        let shared = ["$(inherited)"] + flags { $0.contains(.ios) && $0.contains(.tvos) }
        var settings: SettingsDictionary = ["OTHER_LDFLAGS": .array(shared)]
        // A conditional key replaces the unconditional one for that SDK, so it repeats the shared flags.
        let iosOnly = flags { $0.contains(.ios) && !$0.contains(.tvos) }
        let tvosOnly = flags { $0.contains(.tvos) && !$0.contains(.ios) }
        if !iosOnly.isEmpty {
            settings["OTHER_LDFLAGS[sdk=iphone*]"] = .array(shared + iosOnly)
        }
        if !tvosOnly.isEmpty {
            settings["OTHER_LDFLAGS[sdk=appletv*]"] = .array(shared + tvosOnly)
        }
        return settings
    }

    var scripts: [TargetScript] {
        let products = projectProducts.map(\.product)
        return products.isEmpty ? [] : [DevSettings.embedProjectFrameworksScript(products: products)]
    }

    /// Vendored .xcodeproj files the workspace must contain for these apps.
    public static func workspaceProjects(for apps: [FocusedApp]) -> [String] {
        var paths = Set<String>()
        for app in apps {
            for core in app.allCores {
                for link in core.links {
                    if case let .project(path, _, _) = link { paths.insert(path) }
                }
            }
        }
        return paths.sorted()
    }
```

In `target()`, change `scripts: [],` to `scripts: scripts,`.

In the `ui` literal, change `cores: [.mGBA, .stella]` to `cores: [.mGBA, .stella, .snes9x]`.

- [ ] **Step 4: List the vendored projects in `Workspace.swift`**

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let workspace = Workspace(
    name: "Provenance-Dev",
    projects: ["Dev"],
    // A workspace FileRef to an .xcodeproj is a project reference: Xcode builds its targets
    // when the app links their products (implicit dependencies).
    additionalFiles: ["docs/superpowers/specs/*.md"]
        + FocusedApp.workspaceProjects(for: FocusedApp.all).map { .folderReference(path: .relativeToRoot($0)) }
)
```

- [ ] **Step 5: Generate and confirm the workspace sees the projects**

Run: `mise exec -- tuist generate --no-open 2>&1 | tail -5 && grep -n 'xcodeproj' Provenance-Dev.xcworkspace/contents.xcworkspacedata && xcodebuild -list -workspace Provenance-Dev.xcworkspace | sed -n '/Schemes:/,$p'`
Expected: the xcworkspacedata has `FileRef` entries for `Cores/snes9x/PVSNES9x.xcodeproj` and `PVCoreBridgeRetro/PVCoreBridgeRetro.xcodeproj`, and the scheme list includes `PVSNES9x`, `snes9x` and `PVCoreBridgeRetro`.
If Tuist writes the folder reference in a form that Xcode does not list as a project, replace `.folderReference(path: .relativeToRoot($0))` with `"\($0)"` (a plain glob string matching the bundle), generate again, and re-check.

- [ ] **Step 6: Build both simulators**

Run the Global Constraints build command for scheme `Provenance-Dev-UI`, iOS Simulator, log `/tmp/claude-501/t3-ios.log`. Then run it for tvOS Simulator, log `t3-tvos.log`.
Expected:
- `** BUILD SUCCEEDED **` for both.
- `grep -c "Add implicit dependency on target 'PVSNES9x'" /tmp/claude-501/t3-ios.log` reports at least 1. If it reports 0 and linking fails with `framework not found PVSNES`, report BLOCKED with the log. Do not hand-edit the generated project.
- `ls /tmp/claude-501/dev-dd/Build/Products/Debug-iphonesimulator/Provenance-Dev-UI.app/Frameworks` lists `PVSNES.framework`, `snes9x.framework`, `PVCoreBridgeRetro.framework`, `PVCheevos.framework`, `PVStella-Dynamic.framework` (or the product's framework name) and the mGBA product.

- [ ] **Step 7: Add the Makefile targets**

Append `dev dev-generate dev-ui` to the `.PHONY` list on line 8. Add after the `open:` target:

```make
## Dev workspace (Tuist; see docs/superpowers/specs/2026-10-10-dev-workspace-design.md)
TUIST ?= mise exec -- tuist
DEV_WORKSPACE := Provenance-Dev.xcworkspace
DEV_DERIVED ?= $(CURDIR)/build/dev-dd
DEV_DESTINATION ?= generic/platform=iOS Simulator

dev-generate:
	$(TUIST) generate --no-open

dev: dev-generate
	open $(DEV_WORKSPACE)

# Build one focused app: make _dev-build DEV_SCHEME=Provenance-Dev-UI
_dev-build: dev-generate
	xcodebuild build \
		-workspace $(DEV_WORKSPACE) \
		-scheme "$(DEV_SCHEME)" \
		-destination "$(DEV_DESTINATION)" \
		-derivedDataPath "$(DEV_DERIVED)" \
		-skipPackagePluginValidation \
		-skipMacroValidation \
		CODE_SIGNING_ALLOWED=NO

dev-ui:
	$(MAKE) _dev-build DEV_SCHEME=Provenance-Dev-UI
```

- [ ] **Step 8: Verify the Makefile**

Run: `make dev-ui 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`. `build/` is already gitignored.

- [ ] **Step 9: Commit**

```bash
git add Tuist Workspace.swift Makefile
git -c commit.gpgsign=false commit -m "build: link xcodeproj cores into dev apps; add make dev" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

# Batch 2 — Remaining rows and targets (develop)

### Task 4: Manifest checks  *(model: sonnet)*

**Files:**
- Create: `Dev/Tests/ManifestChecks/main.swift`
- Create: `Scripts/dev/check_dev_manifest.sh` (mode 755)
- Modify: `Scripts/maint/jobs.toml` (new job `dev-manifest`)

**Interfaces:**
- Consumes: `CoreProduct.all`, `CoreLink.paths`, `FocusedApp.all`, `FocusedApp.libretro`, `DevSettings.localPackagePaths(for:)`, `FocusedApp.workspaceProjects(for:)`.
- Produces: `Scripts/dev/check_dev_manifest.sh`. It exits 0 when all checks pass, 1 when any fails, and is used by T5, T7, T8 and T10.

- [ ] **Step 1: Write `Dev/Tests/ManifestChecks/main.swift`**

This file is compiled into the same module as the helper sources, so it uses them without `import ProjectDescriptionHelpers`.

```swift
import Foundation

// Compiled with Tuist/ProjectDescriptionHelpers/*.swift against Tuist's ProjectDescription
// framework by Scripts/dev/check_dev_manifest.sh. Argument 1: repo root.

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
var failures: [String] = []

func exists(_ relative: String) -> Bool {
    FileManager.default.fileExists(atPath: root.appendingPathComponent(relative).path)
}

/// Names in cores.yml whose entry has `enabled: true`.
func enabledLibretroNames() throws -> Set<String> {
    let text = try String(contentsOf: root.appendingPathComponent("CoresRetro/RetroArch/scripts/cores.yml"), encoding: .utf8)
    var enabled = Set<String>()
    var current: String?
    for rawLine in text.components(separatedBy: "\n") {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        if line.hasPrefix("- name:") {
            current = line.dropFirst("- name:".count)
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        } else if let name = current, line.hasPrefix("enabled:") {
            let value = line.dropFirst("enabled:".count).split(separator: "#").first?
                .trimmingCharacters(in: .whitespaces)
            if value == "true" { enabled.insert(name) }
        }
    }
    return enabled
}

// 1. Every libretro name is an enabled cores.yml entry.
let enabled = try enabledLibretroNames()
for app in FocusedApp.all {
    for name in app.libretro where !enabled.contains(name) {
        failures.append("\(app.name): libretro '\(name)' is not an enabled cores.yml entry")
    }
}

// 2. Every CoreProduct path exists.
for core in CoreProduct.all {
    for link in core.links {
        for path in link.paths where !exists(path) {
            failures.append("CoreProduct '\(core.id)': missing \(path)")
        }
    }
}

// 3. No local package declared twice, and each has a Package.swift.
let locals = DevSettings.localPackagePaths(for: FocusedApp.all)
if Set(locals).count != locals.count {
    failures.append("duplicate local packages: \(locals)")
}
for path in locals where !exists(path + "/Package.swift") {
    failures.append("local package without Package.swift: \(path)")
}

// 4. Target names are unique and every vendored project exists.
let names = FocusedApp.all.map(\.name)
if Set(names).count != names.count {
    failures.append("duplicate focused app names: \(names)")
}
for path in FocusedApp.workspaceProjects(for: FocusedApp.all) where !exists(path + "/project.pbxproj") {
    failures.append("workspace project missing: \(path)")
}

if failures.isEmpty {
    print("dev manifest: OK (\(FocusedApp.all.count) apps, \(CoreProduct.all.count) core rows, \(locals.count) local packages)")
    exit(0)
}
failures.forEach { print("dev manifest: FAIL \($0)") }
exit(1)
```

- [ ] **Step 2: Write `Scripts/dev/check_dev_manifest.sh`**

```bash
#!/bin/bash
# Compiles Tuist/ProjectDescriptionHelpers with Dev/Tests/ManifestChecks/main.swift against the
# ProjectDescription.framework of the pinned Tuist (.mise.toml) and runs the checks.
# Exit: 0 all checks pass, 1 a check failed, 2 setup error.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TUIST_DIR="$(mise where tuist 2>/dev/null || true)"
FRAMEWORKS="${TUIST_DIR}/bin"
if [ ! -d "${FRAMEWORKS}/ProjectDescription.framework" ]; then
    echo "check_dev_manifest: ProjectDescription.framework not found under '${FRAMEWORKS}' (run: mise install)" >&2
    exit 2
fi

OUT="$(mktemp -d "${TMPDIR:-/tmp}/dev-manifest.XXXXXX")"
trap 'rm -rf "$OUT"' EXIT

xcrun swiftc -swift-version 5 \
    -F "${FRAMEWORKS}" -framework ProjectDescription \
    -Xlinker -rpath -Xlinker "${FRAMEWORKS}" \
    "${ROOT}"/Tuist/ProjectDescriptionHelpers/*.swift \
    "${ROOT}/Dev/Tests/ManifestChecks/main.swift" \
    -o "${OUT}/manifest-checks" || exit 2

"${OUT}/manifest-checks" "${ROOT}"
```

Run: `chmod +x Scripts/dev/check_dev_manifest.sh`

- [ ] **Step 3: Run it, expecting a pass on the current table**

Run: `Scripts/dev/check_dev_manifest.sh`
Expected: `dev manifest: OK (1 apps, 6 core rows, …)`.

- [ ] **Step 4: Prove a failure is caught**

Temporarily change `stella`'s path in `CoreProduct.swift` to `"Cores/StellaX"`, then run `Scripts/dev/check_dev_manifest.sh; echo "exit=$?"`.
Expected: `dev manifest: FAIL CoreProduct 'stella': missing Cores/StellaX` and `exit=1`. Restore the path; it passes again.

- [ ] **Step 5: Register the job**

Append to `Scripts/maint/jobs.toml` after `[jobs.ra-script-tests]`:

```toml
[jobs.dev-manifest]
title = "Dev workspace manifest checks"
category = "Audits"
description = "Tuist helper tables: libretro names enabled in cores.yml, core paths exist, no duplicate local package."
check = ["Scripts/dev/check_dev_manifest.sh"]
files = ["Dev/Tests/ManifestChecks/main.swift"]
needs = ["macos", "mise"]
mode = "manual"
```

Run: `python3 Scripts/maint/maint.py status 2>&1 | grep -i -E "unregistered|dev-manifest"`
Expected: `dev-manifest` is listed and `check_dev_manifest.sh` is not unregistered.

- [ ] **Step 6: Commit**

```bash
git add Dev/Tests Scripts/dev/check_dev_manifest.sh Scripts/maint/jobs.toml
git -c commit.gpgsign=false commit -m "test: add dev workspace manifest checks" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Remaining KEEP core rows  *(model: haiku)*

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/CoreProduct.swift`

**Interfaces:**
- Produces: `CoreProduct.fceu`, `.genesis`, `.mupen64Plus`, `.mednafen`, `.proSystem`, `.picoDrive`, `.tgbDual`, `.azahar`, `.dolphin`. `CoreProduct.all` contains every row.

- [ ] **Step 1: Add the rows after `snes9x`**

Product and target names are from `Provenance (AppStore)`'s embed phase and each core's `.xcodeproj`.

```swift
    static let fceu = CoreProduct(
        id: "fceu",
        link: .project(path: "Cores/FCEU/PVFCEU.xcodeproj", target: "PVFCEU", product: "PVFCEU")
    )
    static let genesis = CoreProduct(
        id: "genesis",
        link: .project(path: "Cores/Genesis-Plus-GX/PVGenesis.xcodeproj", target: "PVGenesis", product: "PVGenesis")
    )
    static let mupen64Plus = CoreProduct(
        id: "mupen64plus",
        link: .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64Plus", product: "PVMupen64Plus"),
        embeds: [
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64PlusRspHLE", product: "PVMupen64PlusRspHLE"),
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64PlusBridge", product: "PVMupen64PlusBridge"),
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64PlusVideoGlideN64", product: "PVMupen64PlusVideoGlideN64"),
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVMupen64PlusVideoRice", product: "PVMupen64PlusVideoRice"),
            .project(path: "Cores/Mupen64Plus/PVMupen64Plus.xcodeproj", target: "PVRSPCXD4", product: "PVRSPCXD4"),
        ]
    )
    static let mednafen = CoreProduct(id: "mednafen", link: .package(path: "Cores/Mednafen", product: "PVCoreMednafen-Dynamic"))
    static let proSystem = CoreProduct(id: "prosystem", link: .package(path: "Cores/ProSystem", product: "PVProSystem-Dynamic"))
    static let picoDrive = CoreProduct(id: "picodrive", link: .package(path: "Cores/PicoDrive", product: "PVPicoDrive-Dynamic"))
    static let tgbDual = CoreProduct(id: "tgbdual", link: .package(path: "Cores/TGBDual", product: "PVTGBDual-Dynamic"))
    static let azahar = CoreProduct(
        id: "azahar",
        link: .project(path: "Cores/Azahar/PVAzahar.xcodeproj", target: "PVAzahar", product: "PVAzahar"),
        needsAggregate: "BuildPVlibAzahar"
    )
    // PVDolphin links PVlibDolphin.xcframework, which `Make XCFrameworks` (build_slice.py) produces.
    // Build.xcconfig excludes both from simulator SDKs; no focused app uses Dolphin yet.
    static let dolphin = CoreProduct(
        id: "dolphin",
        link: .project(path: "Cores/Dolphin/PVDolphin.xcodeproj", target: "PVDolphin", product: "PVDolphin"),
        embeds: [.prebuilt(path: "Cores/Dolphin/dolphin-ios/build/xcframework/PVlibDolphin.xcframework")],
        needsAggregate: "Make XCFrameworks"
    )
```

Change `all` to:

```swift
    static let all: [CoreProduct] = [
        .mGBA, .stella, .snes9x, .fceu, .genesis, .mupen64Plus, .mednafen,
        .proSystem, .picoDrive, .tgbDual, .azahar, .dolphin,
    ] + nonCore
```

- [ ] **Step 2: Run the manifest checks**

Run: `Scripts/dev/check_dev_manifest.sh`
Expected: `dev manifest: OK (1 apps, 15 core rows, …)`.
`PVlibDolphin.xcframework` exists only after a Dolphin build. If the check reports it missing, run `ls Cores/Dolphin/dolphin-ios/build/xcframework/`. If no Dolphin slice was ever built on this machine, that FAIL line is expected; note it in the commit body and do not build Dolphin here. Task 12 gives `build_slice.py` a way to produce it.

- [ ] **Step 3: Generate (the rows are unused, so nothing changes)**

Run: `mise exec -- tuist generate --no-open 2>&1 | tail -2`
Expected: `Project generated.`

- [ ] **Step 4: Commit**

```bash
git add Tuist/ProjectDescriptionHelpers/CoreProduct.swift
git -c commit.gpgsign=false commit -m "build: add the remaining audited core rows to the dev table" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: `get-modules.sh --urls <file>`  *(model: sonnet)*

**Files:**
- Modify: `CoresRetro/RetroArch/scripts/get-modules.sh`
- Modify: `Scripts/tests/test-get-modules-validation.sh`

**Interfaces:**
- Produces: `get-modules.sh [--urls <file>] [-appstore]`. With `--urls`:
  - the module list is that file;
  - download state (zips, `timestamp.txt`, `url_manifest.sha256`, `pinned_date.txt`) lives in `modules_compressed/<iOS|tvOS>-urls-<first 12 hex of sha256(file)>`;
  - dylibs go to the shared `modules/` directory;
  - nothing is pruned from `modules/`;
  - the fast path skips only when every listed dylib is present.
- Without `--urls`, behaviour is unchanged.

- [ ] **Step 1: Write the failing test**

In `Scripts/tests/test-get-modules-validation.sh`, add this function before `# ---- Run all tests ----`:

```bash
# ---- Test 6: --urls fetches only the listed dylibs and never prunes the shared modules/ ----
test_get_modules_custom_url_list() {
    local tmp
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/get_modules_urls.XXXXXX")
    local ra="$tmp/CoresRetro/RetroArch"
    mkdir -p "$ra/scripts" "$ra/modules" "$tmp/zips"

    # A minimal arm64 Mach-O dylib header: `file` reports "Mach-O 64-bit ... dynamically linked shared library".
    python3 - "$tmp" <<'PY'
import struct, sys, zipfile, os
root = sys.argv[1]
header = struct.pack("<IiiIIIII", 0xfeedfacf, 0x0100000c, 0, 6, 0, 0, 0, 0)
dylib = os.path.join(root, "fake_libretro_ios.dylib")
with open(dylib, "wb") as f:
    f.write(header)
with zipfile.ZipFile(os.path.join(root, "zips", "fake_libretro_ios.dylib.zip"), "w") as z:
    z.write(dylib, "fake_libretro_ios.dylib")
with open(os.path.join(root, "CoresRetro/RetroArch/modules/other_libretro_ios.dylib"), "wb") as f:
    f.write(header)
PY
    echo "file://$tmp/zips/fake_libretro_ios.dylib.zip" > "$tmp/urls.txt"

    local out rc=0
    out=$(SRCROOT="$tmp" PLATFORM_NAME=iphonesimulator GETMODULES_MIN_DYLIB_SIZE=1 \
        bash "$GET_MODULES" --urls "$tmp/urls.txt" 2>&1) || rc=$?

    local ok=1
    [ "$rc" -eq 0 ] || { echo "FAIL: --urls run exited $rc"; echo "$out" | tail -20; ok=0; }
    [ -f "$ra/modules/fake_libretro_ios.dylib" ] || { echo "FAIL: listed dylib not extracted"; ok=0; }
    [ -f "$ra/modules/other_libretro_ios.dylib" ] || { echo "FAIL: --urls pruned an unlisted dylib from shared modules/"; ok=0; }
    ls -d "$ra"/modules_compressed/iOS-urls-* >/dev/null 2>&1 || { echo "FAIL: no iOS-urls-<sha> state dir"; ok=0; }
    [ ! -f "$ra/modules_compressed/iOS/url_manifest.sha256" ] || { echo "FAIL: --urls wrote the shared iOS manifest"; ok=0; }

    # Second run: everything present and fresh -> fast path.
    out=$(SRCROOT="$tmp" PLATFORM_NAME=iphonesimulator GETMODULES_MIN_DYLIB_SIZE=1 \
        bash "$GET_MODULES" --urls "$tmp/urls.txt" 2>&1) || true
    echo "$out" | grep -q "all 1 listed dylib(s) present" || { echo "FAIL: second --urls run did not take the fast path"; ok=0; }

    rm -rf "$tmp"
    [ "$ok" -eq 1 ] && echo "PASS: --urls fetches the listed dylibs into shared modules/ without pruning"
    [ "$ok" -eq 1 ]
}
```

Add `run_test test_get_modules_custom_url_list` after the last `run_test` line.

- [ ] **Step 2: Run the test and see it fail**

Run: `bash Scripts/tests/test-get-modules-validation.sh`
Expected: Test 6 prints `FAIL:` lines (an unknown flag is ignored, so the script reads `urls.txt` from the empty fake `scripts/`). The script ends with `1 test(s) FAILED.`

- [ ] **Step 3: Parse the arguments in `get-modules.sh`**

Replace:

```bash
# Add parameter check
URL_SUFFIX=""
if [ "$1" = "-appstore" ]; then
    URL_SUFFIX="-appstore"
fi
```

with:

```bash
# Arguments: [-appstore] [--urls <file>]
#   --urls <file>  fetch exactly the URLs in <file> (a focused dev app's list). Download state
#                  lives in modules_compressed/<iOS|tvOS>-urls-<sha12> and modules/ is never
#                  pruned, because shipping builds share it.
URL_SUFFIX=""
CUSTOM_URLS=""
while [ $# -gt 0 ]; do
	case "$1" in
		-appstore) URL_SUFFIX="-appstore" ;;
		--urls)
			[ $# -ge 2 ] || { echo "GetModule: ERROR — --urls needs a file" >&2; exit 1; }
			CUSTOM_URLS="$2"; shift ;;
		*) echo "GetModule: WARNING — ignoring unknown argument '$1'" >&2 ;;
	esac
	shift
done
```

- [ ] **Step 4: Switch the list and the state dir after the platform `if`/`else`**

Immediately after the `fi` that closes the `if [ "${PLATFORM_NAME}" = "appletvos" ] || …` block, insert:

```bash
if [ -n "${CUSTOM_URLS}" ]; then
	if [ ! -f "${CUSTOM_URLS}" ]; then
		echo "GetModule: ERROR — --urls file not found: ${CUSTOM_URLS}" >&2
		exit 1
	fi
	MODULE_LIST="${CUSTOM_URLS}"
	CUSTOM_LIST_ID=$(shasum -a 256 "${CUSTOM_URLS}" | cut -c1-12)
	# Sibling of the platform dir, not a child: the shipping extraction runs `find` recursively there.
	CORES_ARCHIVE_DIR="${CORES_ARCHIVE_DIR}-urls-${CUSTOM_LIST_ID}"
	echo "GetModule: custom URL list ${CUSTOM_URLS} (state in ${CORES_ARCHIVE_DIR})"
fi
```

- [ ] **Step 5: Skip pruning for custom lists**

Replace:

```bash
prune_dylibs_not_in_manifest "${EFFECTIVE_MODULE_LIST}" "${CORES_DIR}"
```

with:

```bash
if [ -z "${CUSTOM_URLS}" ]; then
	prune_dylibs_not_in_manifest "${EFFECTIVE_MODULE_LIST}" "${CORES_DIR}"
fi
```

- [ ] **Step 6: Add a fast path for custom lists**

Insert immediately before the comment line `# Fast-path: when the platform is known (active_platform.txt exists), unchanged,`:

```bash
# Custom lists: skip when the timestamp is fresh and every listed dylib is already in modules/.
# (The count-based fast path below would count all ~100 shared dylibs.)
custom_list_present() {
	local url base stem missing=0 total=0
	while IFS= read -r url || [ -n "$url" ]; do
		case "$url" in \#*|"") continue ;; esac
		total=$((total + 1))
		base=$(basename "$url"); base="${base%.zip}"; stem="${base%.dylib}"
		if [ ! -f "${CORES_DIR}/${base}" ] && [ ! -f "${CORES_DIR}/${stem}_ios.dylib" ] && [ ! -f "${CORES_DIR}/${stem}_tvos.dylib" ]; then
			missing=$((missing + 1))
		fi
	done < "${EFFECTIVE_MODULE_LIST}"
	[ "$missing" -eq 0 ] && echo "$total"
}
if [ -n "${CUSTOM_URLS}" ] && (( TIMESTAMP <= LAST_TIMESTAMP )) && [ "${PLATFORM_CHANGED}" = "0" ] \
	&& [ "${PIN_CHANGED}" = "0" ] && [ "${MANIFEST_CHANGED}" = "0" ]; then
	if PRESENT=$(custom_list_present) && [ -n "${PRESENT}" ]; then
		echo "GetModule: custom list — all ${PRESENT} listed dylib(s) present, timestamp fresh — skipping"
		exit 0
	fi
fi
```

The main fast path must not fire for custom lists. Change its condition line from:

```bash
if (( TIMESTAMP <= LAST_TIMESTAMP )) && [ -n "${STORED_PLATFORM}" ] && [ "${PLATFORM_CHANGED}" = "0" ] && [ "${PIN_CHANGED}" = "0" ] && [ "${MANIFEST_CHANGED}" = "0" ]; then
```

to:

```bash
if [ -z "${CUSTOM_URLS}" ] && (( TIMESTAMP <= LAST_TIMESTAMP )) && [ -n "${STORED_PLATFORM}" ] && [ "${PLATFORM_CHANGED}" = "0" ] && [ "${PIN_CHANGED}" = "0" ] && [ "${MANIFEST_CHANGED}" = "0" ]; then
```

- [ ] **Step 7: Run the tests and see them pass**

Run: `bash Scripts/tests/test-get-modules-validation.sh`
Expected: all six tests PASS and `All tests passed.`

- [ ] **Step 8: Check that shipping behaviour is unchanged**

Run: `bash -n CoresRetro/RetroArch/scripts/get-modules.sh && grep -n 'CUSTOM_URLS' CoresRetro/RetroArch/scripts/get-modules.sh | wc -l`
Expected: no syntax error, and 8 or more references. Every new branch must be guarded by `CUSTOM_URLS`.

- [ ] **Step 9: Commit**

```bash
git add CoresRetro/RetroArch/scripts/get-modules.sh Scripts/tests/test-get-modules-validation.sh
git -c commit.gpgsign=false commit -m "feat(retroarch): get-modules.sh --urls for focused dylib lists" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: `LibretroCores` and `Provenance-Dev-Thin`  *(model: sonnet)*

**Files:**
- Create: `Tuist/ProjectDescriptionHelpers/LibretroCores.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/FocusedApp.swift` (scripts, new `thin` literal, `all`)

**Interfaces:**
- Consumes: `get-modules.sh --urls <file>` (Task 6); `make_frameworks_retroarch.sh <RetroArch dir> [filter urls file]`; `validate_frameworks.sh`; `FocusedApp.scripts` (Task 3).
- Produces: `public enum LibretroCores { static func scripts(slug: String, names: [String]) -> (pre: [TargetScript], post: [TargetScript]) }` and `FocusedApp.thin`.

- [ ] **Step 1: Write `LibretroCores.swift`**

```swift
import ProjectDescription

/// Buildbot libretro dylibs for one focused app, as two Run Scripts:
/// pre  — pick the names' URLs from the generated urls.txt / urls-tv.txt and fetch them;
/// post — wrap them as <name>.libretro.framework in the app and validate.
/// The URL comes from the generated list (cores.yml → generate_core_lists.py) because a few
/// cores ship neutral filenames (ppsspp_libretro.dylib.zip) without an _ios/_tvos suffix.
public enum LibretroCores {
    public static func scripts(slug: String, names: [String]) -> (pre: [TargetScript], post: [TargetScript]) {
        guard !names.isEmpty else { return ([], []) }
        let pattern = names.joined(separator: "|")
        let pre: TargetScript = .pre(
            script: #"""
            set -euo pipefail
            # LIBRETRO_CORES: \#(names.joined(separator: " "))
            repo="${SRCROOT}/.."
            scripts="${repo}/CoresRetro/RetroArch/scripts"
            case "${PLATFORM_NAME}" in
              appletvos|appletvsimulator) list="${scripts}/urls-tv.txt" ;;
              *) list="${scripts}/urls.txt" ;;
            esac
            mkdir -p "${DERIVED_FILE_DIR}"
            grep -E '^https://.*/(\#(pattern))_libretro(_ios|_tvos)?\.dylib\.zip$' "${list}" > "${DERIVED_FILE_DIR}/urls.txt" || true
            got=$(grep -c . "${DERIVED_FILE_DIR}/urls.txt" || true)
            if [ "${got}" != "\#(names.count)" ]; then
              echo "error: expected \#(names.count) libretro URLs in ${list}, found ${got}:"
              cat "${DERIVED_FILE_DIR}/urls.txt"
              exit 1
            fi
            SRCROOT="${repo}" /bin/bash "${scripts}/get-modules.sh" --urls "${DERIVED_FILE_DIR}/urls.txt"
            """#,
            name: "Get libretro cores (\(slug))",
            basedOnDependencyAnalysis: false
        )
        let post: TargetScript = .post(
            script: #"""
            set -euo pipefail
            repo="${SRCROOT}/.."
            /bin/bash "${repo}/CoresRetro/RetroArch/scripts/make_frameworks_retroarch.sh" "${repo}/CoresRetro/RetroArch" "${DERIVED_FILE_DIR}/urls.txt"
            /bin/bash "${repo}/CoresRetro/RetroArch/scripts/validate_frameworks.sh"
            """#,
            name: "Generate libretro frameworks (\(slug))",
            basedOnDependencyAnalysis: false
        )
        return ([pre], [post])
    }
}
```

- [ ] **Step 2: Wire the scripts into `FocusedApp`**

Replace the `scripts` property from Task 3 with:

```swift
    var scripts: [TargetScript] {
        let libretroScripts = LibretroCores.scripts(slug: slug, names: libretro)
        let products = projectProducts.map(\.product)
        let embed = products.isEmpty ? [] : [DevSettings.embedProjectFrameworksScript(products: products)]
        // Post order: embed vendored frameworks, then wrap libretro dylibs, then validate.
        return libretroScripts.pre + embed + libretroScripts.post
    }
```

Add the literal and extend `all`:

```swift
    static let thin = FocusedApp(
        slug: "thin",
        title: "Thin",
        cores: [],
        libretro: ["mednafen_psx_hw", "mupen64plus_next", "snes9x", "ppsspp"],
        flags: ["PV_DEV_HARNESS"]
    )

    static let all: [FocusedApp] = [.ui, .thin]
```

- [ ] **Step 3: Run the manifest checks**

Run: `Scripts/dev/check_dev_manifest.sh`
Expected: `dev manifest: OK (2 apps, …)`. Any libretro typo fails here.

- [ ] **Step 4: Generate and build Thin on both simulators**

Run: `mise exec -- tuist generate --no-open`. Then run the Global Constraints build command with scheme `Provenance-Dev-Thin` for iOS Simulator (log `t7-ios.log`) and for tvOS Simulator (log `t7-tvos.log`).
Expected: `** BUILD SUCCEEDED **` for both. Then:
- `grep -E "GetModule: (custom URL list|Completed|custom list)" /tmp/claude-501/t7-ios.log` shows a match.
- `ls /tmp/claude-501/dev-dd/Build/Products/Debug-iphonesimulator/Provenance-Dev-Thin.app/Frameworks | grep libretro` lists exactly 4 frameworks for the iOS build. Local cores (`local: true`, e.g. `virtualjaguar`) bypass the filter, so on a machine where they are present they appear too.
- `ls CoresRetro/RetroArch/modules | wc -l` is unchanged from before the build: nothing was pruned.

- [ ] **Step 5: Re-run the UI build to confirm no regression**

Run: the iOS Simulator build for `Provenance-Dev-UI`.
Expected: `** BUILD SUCCEEDED **` and no "Get libretro cores" phase in its log.

- [ ] **Step 6: Commit**

```bash
git add Tuist
git -c commit.gpgsign=false commit -m "build: add Provenance-Dev-Thin with per-target libretro dylibs" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: `Provenance-Dev-Azahar`, `make dev-azahar`, `make dev-thin`  *(model: sonnet)*

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/FocusedApp.swift`
- Modify: `Makefile`

**Interfaces:**
- Consumes: `CoreProduct.azahar` (Task 5) and the project-link mechanism (Task 3).
- Produces: `FocusedApp.azahar`; Make targets `dev-azahar` and `dev-thin`.

- [ ] **Step 1: Add the target**

```swift
    // PVAzahar depends on its BuildPVlibAzahar aggregate inside PVAzahar.xcodeproj, so the
    // implicit dependency on PVAzahar also builds (or cache-links) the PVlibAzahar slice.
    static let azahar = FocusedApp(slug: "azahar", title: "Azahar", cores: [.azahar], flags: ["PV_DEV_HARNESS"])

    static let all: [FocusedApp] = [.ui, .azahar, .thin]
```

- [ ] **Step 2: Add the Makefile targets**

Add `dev-azahar dev-thin` to `.PHONY`, and after `dev-ui:` add:

```make
dev-azahar:
	$(MAKE) _dev-build DEV_SCHEME=Provenance-Dev-Azahar

dev-thin:
	$(MAKE) _dev-build DEV_SCHEME=Provenance-Dev-Thin
```

- [ ] **Step 3: Check the slice is warm**

Run: `ls Cores/Azahar/build/xcframework/PVlibAzahar-ios-sim.framework/PVlibAzahar && cat Cores/Azahar/build/SIMULATORARM64/.gitlink && git -C Cores/Azahar/azahar rev-parse HEAD`
Expected: the archive exists and the two SHAs match, so the aggregate skips the 30–40 minute build. If they don't match, report it and continue: the build in Step 5 will rebuild the slice. Run that build in the background and poll its log.

- [ ] **Step 4: Run the manifest checks and generate**

Run: `Scripts/dev/check_dev_manifest.sh && mise exec -- tuist generate --no-open 2>&1 | tail -2`
Expected: `OK (3 apps, …)` and `Project generated.`

- [ ] **Step 5: Build Azahar for iOS Simulator**

Run: the build command with scheme `Provenance-Dev-Azahar`, iOS Simulator, log `t8-ios.log`.
Expected:
- `** BUILD SUCCEEDED **`.
- `grep "PVlibAzahar ios-sim is current" /tmp/claude-501/t8-ios.log` matches on a warm cache.
- `ls …/Provenance-Dev-Azahar.app/Frameworks/PVAzahar.framework` exists.
No tvOS build here: the spec verifies Azahar on the iOS Simulator only.

- [ ] **Step 6: Run the Makefile path**

Run: `make dev-thin 2>&1 | tail -2`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add Tuist Makefile
git -c commit.gpgsign=false commit -m "build: add Provenance-Dev-Azahar and make dev-azahar/dev-thin" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

> **Batches 5–6 are outlines (batches 3–4 are detailed below).** Each task gives its files, interfaces, model tier, and what it does and how it is verified. Full step-by-step code is written when that batch starts. The facts below were verified against the tree on 2026-10-10.

# Batch 3 — Core harness (develop)

### Task 9: `PVDevHarness` package and its pure core `PVDevHarnessKit`  *(model: sonnet)*

**Files:**
- Create: `PVDevHarness/Package.swift`
- Create: `PVDevHarness/Sources/PVDevHarnessKit/HarnessArguments.swift`
- Create: `PVDevHarness/Sources/PVDevHarnessKit/HarnessOutput.swift`
- Create: `PVDevHarness/Sources/PVDevHarness/DevHarness.swift` (placeholder in this task; Task 10 replaces it)
- Test: `PVDevHarness/Tests/PVDevHarnessKitTests/HarnessKitTests.swift`

**Interfaces:**
- Produces, in module `PVDevHarnessKit`:
  - `public struct HarnessArguments: Equatable, Sendable { romPath: String; coreIdentifier: String?; frames: Int; outputPath: String?; exitWhenDone: Bool }`
  - `static let defaultFrames = 300`; `static func parse(_ arguments: [String]) -> HarnessArguments?`
  - `func romURL(home: URL) -> URL`; `func outputDirectory(home: URL, documents: URL, now: Date) -> URL`; `static func timestamp(_ date: Date) -> String`
  - `public struct HarnessReport: Codable, Equatable, Sendable { core, game: String; frames: Int; frameCountSource: String; frameInterval, fps, waitedSeconds, elapsedSeconds: Double }`
  - `public enum HarnessOutput` with the file-name constants `screenshotFile`, `framesFile`, `logFile`, `errorFile`, and `prepare(_:)`, `writeReport(_:to:)`, `writeError(_:to:)`, `writeScreenshot(_:to:)`, `copyLog(from:to:)`, `waitSeconds(frames:frameInterval:)`.
- Product `PVDevHarness` (library). On iOS and tvOS it depends on PVUI, PVLibrary and PVLogging. On macOS those dependencies are skipped, so `swift test` builds and runs only the Kit tests.

- [ ] **Step 1: Write `PVDevHarness/Package.swift`**

```swift
// swift-tools-version:6.0
import PackageDescription

// Dev-only launch-argument harness, compiled into Tuist focused apps under PV_DEV_HARNESS.
// PVDevHarnessKit is platform-neutral (arguments, report, output files) and unit-tested with
// `swift test` on macOS; PVDevHarness drives the app and only builds for iOS/tvOS.
let appPlatforms: [Platform] = [.iOS, .tvOS]

let package = Package(
    name: "PVDevHarness",
    platforms: [.iOS(.v17), .tvOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "PVDevHarness", targets: ["PVDevHarness"]),
    ],
    dependencies: [
        .package(path: "../PVUI"),
        .package(path: "../PVLibrary"),
        .package(path: "../PVLogging"),
    ],
    targets: [
        .target(name: "PVDevHarnessKit"),
        .target(
            name: "PVDevHarness",
            dependencies: [
                "PVDevHarnessKit",
                .product(name: "PVUI", package: "PVUI", condition: .when(platforms: appPlatforms)),
                .product(name: "PVLibrary", package: "PVLibrary", condition: .when(platforms: appPlatforms)),
                .product(name: "PVLogging", package: "PVLogging", condition: .when(platforms: appPlatforms)),
            ]
        ),
        .testTarget(name: "PVDevHarnessKitTests", dependencies: ["PVDevHarnessKit"]),
    ],
    swiftLanguageModes: [.v5]
)
```

- [ ] **Step 2: Write the failing tests**

`PVDevHarness/Tests/PVDevHarnessKitTests/HarnessKitTests.swift`:

```swift
import XCTest
@testable import PVDevHarnessKit

final class HarnessArgumentsTests: XCTestCase {
    func testNoROMMeansNormalLaunch() {
        XCTAssertNil(HarnessArguments.parse(["/app", "-NSDoubleLocalizedStrings", "YES"]))
    }

    func testDefaults() throws {
        let args = try XCTUnwrap(HarnessArguments.parse(["/app", "-PVHarnessROM", "/tmp/a.gba"]))
        XCTAssertEqual(args.romPath, "/tmp/a.gba")
        XCTAssertNil(args.coreIdentifier)
        XCTAssertEqual(args.frames, HarnessArguments.defaultFrames)
        XCTAssertNil(args.outputPath)
        XCTAssertTrue(args.exitWhenDone)
    }

    func testAllArguments() throws {
        let args = try XCTUnwrap(HarnessArguments.parse([
            "/app", "-PVHarnessROM", "Documents/a.gba", "-PVHarnessCore", "com.provenance.core.mgba",
            "-PVHarnessFrames", "120", "-PVHarnessOut", "Documents/out", "-PVHarnessExit", "0",
        ]))
        XCTAssertEqual(args.coreIdentifier, "com.provenance.core.mgba")
        XCTAssertEqual(args.frames, 120)
        XCTAssertEqual(args.outputPath, "Documents/out")
        XCTAssertFalse(args.exitWhenDone)
    }

    func testBadFramesFallBackAndClamp() throws {
        XCTAssertEqual(HarnessArguments.parse(["-PVHarnessROM", "a", "-PVHarnessFrames", "abc"])?.frames, 300)
        XCTAssertEqual(HarnessArguments.parse(["-PVHarnessROM", "a", "-PVHarnessFrames", "0"])?.frames, 1)
    }

    func testMissingValueIsIgnored() {
        XCTAssertNil(HarnessArguments.parse(["-PVHarnessROM", "-PVHarnessFrames", "10"]))
    }

    func testPathsResolveAgainstHome() throws {
        let home = URL(fileURLWithPath: "/container", isDirectory: true)
        let relative = try XCTUnwrap(HarnessArguments.parse(["-PVHarnessROM", "Documents/a.gba", "-PVHarnessOut", "Documents/out"]))
        XCTAssertEqual(relative.romURL(home: home).path, "/container/Documents/a.gba")
        XCTAssertEqual(relative.outputDirectory(home: home, documents: home, now: Date()).path, "/container/Documents/out")
        let absolute = try XCTUnwrap(HarnessArguments.parse(["-PVHarnessROM", "/roms/a.gba"]))
        XCTAssertEqual(absolute.romURL(home: home).path, "/roms/a.gba")
    }

    func testDefaultOutputDirectoryIsTimestamped() throws {
        let args = try XCTUnwrap(HarnessArguments.parse(["-PVHarnessROM", "a"]))
        let docs = URL(fileURLWithPath: "/docs", isDirectory: true)
        let date = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(args.outputDirectory(home: docs, documents: docs, now: date).path, "/docs/Harness/19700101-000000")
    }
}

final class HarnessOutputTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try HarnessOutput.prepare(dir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testReportRoundTrips() throws {
        let report = HarnessReport(core: "c", game: "g", frames: 300, frameCountSource: "estimated",
                                   frameInterval: 1.0 / 60.0, fps: 60, waitedSeconds: 5, elapsedSeconds: 9.5)
        try HarnessOutput.writeReport(report, to: dir)
        let data = try Data(contentsOf: dir.appendingPathComponent(HarnessOutput.framesFile))
        XCTAssertEqual(try JSONDecoder().decode(HarnessReport.self, from: data), report)
    }

    func testErrorAndScreenshotAndLog() throws {
        try HarnessOutput.writeError("boom", to: dir)
        try HarnessOutput.writeScreenshot(Data([0x89, 0x50]), to: dir)
        let log = dir.appendingPathComponent("source.log")
        try "line".write(to: log, atomically: true, encoding: .utf8)
        try HarnessOutput.copyLog(from: log, to: dir)
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent(HarnessOutput.errorFile), encoding: .utf8), "boom\n")
        XCTAssertEqual(try Data(contentsOf: dir.appendingPathComponent(HarnessOutput.screenshotFile)), Data([0x89, 0x50]))
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent(HarnessOutput.logFile), encoding: .utf8), "line")
    }

    func testMissingLogStillWritesAFile() throws {
        try HarnessOutput.copyLog(from: nil, to: dir)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent(HarnessOutput.logFile).path))
    }

    func testWaitSeconds() {
        XCTAssertEqual(HarnessOutput.waitSeconds(frames: 300, frameInterval: 1.0 / 60.0), 5, accuracy: 0.0001)
        XCTAssertEqual(HarnessOutput.waitSeconds(frames: 120, frameInterval: 0), 2, accuracy: 0.0001)
    }
}
```

Write the placeholder `PVDevHarness/Sources/PVDevHarness/DevHarness.swift` so the package resolves:

```swift
// Replaced in the next task with the app driver (iOS/tvOS only).
import PVDevHarnessKit
```

- [ ] **Step 3: Run the tests and see them fail**

Run: `cd PVDevHarness && swift test 2>&1 | tail -15`
Expected: compile errors such as `cannot find 'HarnessArguments' in scope`.

- [ ] **Step 4: Write `HarnessArguments.swift`**

```swift
import Foundation

/// Launch arguments of the dev harness. A normal launch has no `-PVHarnessROM` and
/// `parse(_:)` returns nil.
public struct HarnessArguments: Equatable, Sendable {
    public enum Key {
        public static let rom = "-PVHarnessROM"
        public static let core = "-PVHarnessCore"
        public static let frames = "-PVHarnessFrames"
        public static let out = "-PVHarnessOut"
        public static let exit = "-PVHarnessExit"
        static let prefix = "-PVHarness"
    }

    public static let defaultFrames = 300

    public var romPath: String
    public var coreIdentifier: String?
    public var frames: Int
    public var outputPath: String?
    public var exitWhenDone: Bool

    public init(romPath: String, coreIdentifier: String? = nil, frames: Int = defaultFrames,
                outputPath: String? = nil, exitWhenDone: Bool = true) {
        self.romPath = romPath
        self.coreIdentifier = coreIdentifier
        self.frames = frames
        self.outputPath = outputPath
        self.exitWhenDone = exitWhenDone
    }

    public static func parse(_ arguments: [String]) -> HarnessArguments? {
        func value(_ key: String) -> String? {
            guard let index = arguments.firstIndex(of: key), index + 1 < arguments.count else { return nil }
            let candidate = arguments[index + 1]
            return candidate.hasPrefix(Key.prefix) ? nil : candidate
        }
        guard let rom = value(Key.rom), !rom.isEmpty else { return nil }
        let frames = value(Key.frames).flatMap(Int.init).map { max(1, $0) } ?? defaultFrames
        return HarnessArguments(
            romPath: rom,
            coreIdentifier: value(Key.core),
            frames: frames,
            outputPath: value(Key.out),
            exitWhenDone: value(Key.exit).map { $0 != "0" } ?? true
        )
    }

    /// Absolute paths as given; anything else relative to the app's home (its data container).
    static func resolve(_ path: String, home: URL) -> URL {
        path.hasPrefix("/") ? URL(fileURLWithPath: path) : home.appendingPathComponent(path)
    }

    public func romURL(home: URL) -> URL { Self.resolve(romPath, home: home) }

    /// `-PVHarnessOut`, else `<documents>/Harness/<yyyyMMdd-HHmmss>` (UTC).
    public func outputDirectory(home: URL, documents: URL, now: Date) -> URL {
        if let outputPath { return Self.resolve(outputPath, home: home) }
        return documents.appendingPathComponent("Harness", isDirectory: true)
            .appendingPathComponent(Self.timestamp(now), isDirectory: true)
    }

    public static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 5: Write `HarnessOutput.swift`**

```swift
import Foundation

/// What a harness run measured. `frameCountSource` is "estimated": no core exposes a public
/// frame counter, so `frames` frames are assumed to render in `frames * frameInterval` seconds.
public struct HarnessReport: Codable, Equatable, Sendable {
    public var core: String
    public var game: String
    public var frames: Int
    public var frameCountSource: String
    public var frameInterval: Double
    public var fps: Double
    public var waitedSeconds: Double
    public var elapsedSeconds: Double

    public init(core: String, game: String, frames: Int, frameCountSource: String, frameInterval: Double,
                fps: Double, waitedSeconds: Double, elapsedSeconds: Double) {
        self.core = core
        self.game = game
        self.frames = frames
        self.frameCountSource = frameCountSource
        self.frameInterval = frameInterval
        self.fps = fps
        self.waitedSeconds = waitedSeconds
        self.elapsedSeconds = elapsedSeconds
    }
}

/// The files a harness run leaves in its output directory.
public enum HarnessOutput {
    public static let screenshotFile = "screenshot.png"
    public static let framesFile = "frames.json"
    public static let logFile = "log.txt"
    public static let errorFile = "error.txt"

    /// Frame interval used when the core reports none.
    static let fallbackFrameInterval = 1.0 / 60.0

    public static func prepare(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static func writeReport(_ report: HarnessReport, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: directory.appendingPathComponent(framesFile), options: .atomic)
    }

    public static func writeError(_ message: String, to directory: URL) throws {
        try (message + "\n").write(to: directory.appendingPathComponent(errorFile), atomically: true, encoding: .utf8)
    }

    public static func writeScreenshot(_ png: Data, to directory: URL) throws {
        try png.write(to: directory.appendingPathComponent(screenshotFile), options: .atomic)
    }

    /// Copies the current log file; writes a one-line note when there is none.
    public static func copyLog(from source: URL?, to directory: URL) throws {
        let destination = directory.appendingPathComponent(logFile)
        try? FileManager.default.removeItem(at: destination)
        if let source, FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(at: source, to: destination)
        } else {
            try "no log file\n".write(to: destination, atomically: true, encoding: .utf8)
        }
    }

    public static func waitSeconds(frames: Int, frameInterval: Double) -> Double {
        Double(frames) * (frameInterval > 0 ? frameInterval : fallbackFrameInterval)
    }
}
```

- [ ] **Step 6: Run the tests and see them pass**

Run: `cd PVDevHarness && swift test 2>&1 | tail -5`
Expected: `Executed 11 tests, with 0 failures`. On macOS the iOS-only dependencies are skipped. If SwiftPM still tries to build PVUI on macOS, run the tests on the simulator instead: `cd PVDevHarness && xcodebuild test -scheme PVDevHarness-Package -destination 'platform=iOS Simulator,name=iPhone 17' -skipPackagePluginValidation -skipMacroValidation`. Record which command passed in the commit body.

- [ ] **Step 7: Lint and commit**

Run: `swiftlint lint --path PVDevHarness`

```bash
git add PVDevHarness
git -c commit.gpgsign=false commit -m "feat(harness): add PVDevHarness package with argument/report kit" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 10: Harness runtime, app hook, Tuist wiring  *(model: sonnet)*

**Files:**
- Modify: `PVDevHarness/Sources/PVDevHarness/DevHarness.swift` (replace the placeholder)
- Modify: `Provenance/Main UI/ProvenanceApp.swift` (import and hook, both under `#if PV_DEV_HARNESS`)
- Modify: `Tuist/ProjectDescriptionHelpers/DevSettings.swift`, `Tuist/ProjectDescriptionHelpers/FocusedApp.swift`

**Interfaces:**
- Consumes:
  - `HarnessArguments`, `HarnessReport`, `HarnessOutput` (Task 9).
  - `AppState` (`bootupState: AppBootupState.State`, `emulationUIState.currentGame/currentCore/core`), `SceneCoordinator.shared.openEmulatorScene()`, `GameImporter.shared.addImports(forPaths:)` and `.startProcessing()`, `Paths.romsImportPath`, `URL.documentsPath`, `RomDatabase.sharedInstance.realm` / `.all(_:)`, `PVLogFileManager.shared.currentSessionURL` / `.logFiles()`, `PVLogging.shared.flushLogs()`.
- Produces: `@MainActor public enum DevHarness { static func start(appState: AppState, arguments: [String] = ProcessInfo.processInfo.arguments) }`; `DevSettings.harnessFlag = "PV_DEV_HARNESS"`.

- [ ] **Step 1: Write `DevHarness.swift`**

```swift
#if os(iOS) || os(tvOS)
import Foundation
import UIKit
import PVDevHarnessKit
import PVLibrary
import PVLogging
import PVUIBase

/// Launch-argument harness for the Tuist focused apps (`-PVHarnessROM <path>` …): imports the
/// ROM if needed, launches it through the normal emulator-scene path, waits, writes
/// screenshot.png / frames.json / log.txt (or error.txt) and exits.
@MainActor
public enum DevHarness {
    enum HarnessError: Error, CustomStringConvertible {
        case bootTimedOut
        case bootFailed(String)
        case romNotFound(String)
        case importTimedOut(String)
        case coreNotFound(String)
        case noCoreForSystem(String)
        case coreDidNotStart(String)
        case screenshotFailed

        var description: String {
            switch self {
            case .bootTimedOut: return "app bootup did not complete"
            case let .bootFailed(reason): return "app bootup failed: \(reason)"
            case let .romNotFound(path): return "ROM not found: \(path)"
            case let .importTimedOut(name): return "import of \(name) did not finish"
            case let .coreNotFound(id): return "no registered core \(id)"
            case let .noCoreForSystem(id): return "no enabled core for system \(id)"
            case let .coreDidNotStart(id): return "core \(id) did not start running"
            case .screenshotFailed: return "could not snapshot a window"
            }
        }
    }

    static let bootTimeout: TimeInterval = 120
    static let importTimeout: TimeInterval = 180
    static let coreStartTimeout: TimeInterval = 60
    static let pollNanoseconds: UInt64 = 250_000_000
    static let frameCountSource = "estimated"

    private static var started = false

    public static func start(appState: AppState, arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard !started, let args = HarnessArguments.parse(arguments) else { return }
        started = true
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let output = args.outputDirectory(home: home, documents: URL.documentsPath, now: Date())
        ILOG("DevHarness: ROM \(args.romPath), \(args.frames) frames, output \(output.path)")
        Task { @MainActor in
            let began = Date()
            do {
                try HarnessOutput.prepare(output)
                let report = try await run(args, appState: appState, home: home, began: began)
                guard let png = screenshotPNG() else { throw HarnessError.screenshotFailed }
                try HarnessOutput.writeScreenshot(png, to: output)
                try HarnessOutput.writeReport(report, to: output)
                finish(args, output: output, status: 0)
            } catch {
                ELOG("DevHarness: \(error)")
                try? HarnessOutput.writeError(String(describing: error), to: output)
                finish(args, output: output, status: 1)
            }
        }
    }

    private static func run(_ args: HarnessArguments, appState: AppState, home: URL, began: Date) async throws -> HarnessReport {
        let booted = await waitUntil(bootTimeout) {
            if case .completed = appState.bootupState { return true }
            return false
        }
        if case let .error(error) = appState.bootupState { throw HarnessError.bootFailed(String(describing: error)) }
        guard booted else { throw HarnessError.bootTimedOut }

        let game = try await importIfNeeded(args.romURL(home: home))
        let core = try resolveCore(args.coreIdentifier, for: game)
        ILOG("DevHarness: launching \(game.title) with \(core.identifier)")

        // Same path as ProvenanceApp.openEmulatorSceneIfNeeded(): the scene reads these.
        appState.emulationUIState.currentCore = core
        appState.emulationUIState.currentGame = game
        SceneCoordinator.shared.openEmulatorScene()

        let coreID = core.identifier
        guard await waitUntil(coreStartTimeout, { appState.emulationUIState.core?.isRunning == true }) else {
            throw HarnessError.coreDidNotStart(coreID)
        }
        let frameInterval = appState.emulationUIState.core?.frameInterval ?? 0
        let wait = HarnessOutput.waitSeconds(frames: args.frames, frameInterval: frameInterval)
        let waitStart = Date()
        try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        let waited = Date().timeIntervalSince(waitStart)
        return HarnessReport(
            core: coreID,
            game: game.title,
            frames: args.frames,
            frameCountSource: frameCountSource,
            frameInterval: frameInterval,
            fps: waited > 0 ? Double(args.frames) / waited : 0,
            waitedSeconds: waited,
            elapsedSeconds: Date().timeIntervalSince(began)
        )
    }

    // MARK: Import

    private static func findGame(named fileName: String) -> PVGame? {
        let database = RomDatabase.sharedInstance
        database.realm.refresh()
        return database.all(PVGame.self).filter("romPath ENDSWITH[c] %@", fileName).first
    }

    private static func importIfNeeded(_ romURL: URL) async throws -> PVGame {
        let fileName = romURL.lastPathComponent
        if let game = findGame(named: fileName) { return game }
        guard FileManager.default.fileExists(atPath: romURL.path) else { throw HarnessError.romNotFound(romURL.path) }

        let importDirectory = Paths.romsImportPath
        try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        let staged = importDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: staged.path) {
            try FileManager.default.copyItem(at: romURL, to: staged)
        }
        await GameImporter.shared.addImports(forPaths: [staged])
        GameImporter.shared.startProcessing()

        var found: PVGame?
        _ = await waitUntil(importTimeout) {
            found = findGame(named: fileName)
            return found != nil
        }
        guard let game = found else { throw HarnessError.importTimedOut(fileName) }
        return game
    }

    // MARK: Core choice: explicit, else the game's, else the system's preference, else the first enabled core.

    private static func resolveCore(_ explicit: String?, for game: PVGame) throws -> PVCore {
        let realm = RomDatabase.sharedInstance.realm
        func core(_ identifier: String?) -> PVCore? {
            identifier.flatMap { realm.object(ofType: PVCore.self, forPrimaryKey: $0) }
        }
        if let explicit {
            guard let chosen = core(explicit) else { throw HarnessError.coreNotFound(explicit) }
            return chosen
        }
        if let preferred = core(game.userPreferredCoreID) ?? core(game.system?.userPreferredCoreID) {
            return preferred
        }
        guard let first = game.system?.cores.filter("disabled == false").sorted(byKeyPath: "identifier").first else {
            throw HarnessError.noCoreForSystem(game.systemIdentifier)
        }
        return first
    }

    // MARK: Output

    private static func screenshotPNG() -> Data? {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        guard let window = windows.first(where: \.isKeyWindow) ?? windows.first else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.pngData { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private static func finish(_ args: HarnessArguments, output: URL, status: Int32) {
        PVLogging.shared.flushLogs()
        let log = PVLogFileManager.shared.currentSessionURL ?? PVLogFileManager.shared.logFiles().last
        try? HarnessOutput.copyLog(from: log, to: output)
        ILOG("DevHarness: done (status \(status)) → \(output.path)")
        if args.exitWhenDone { exit(status) }
    }

    private static func waitUntil(_ timeout: TimeInterval, _ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }
        return condition()
    }
}
#endif
```

If a symbol does not resolve, fix the import. Do not change the API being used:
- `PVLogFileManager` is in PVLogging.
- `Paths`, `URL.documentsPath`, `PVGame` and `PVCore` are re-exported by PVLibrary.
- `AppState` and `SceneCoordinator` are in PVUIBase.

- [ ] **Step 2: Hook the app**

In `Provenance/Main UI/ProvenanceApp.swift`, after the `#if canImport(WhatsNewKit)` import block (around line 20), add:

```swift
#if PV_DEV_HARNESS
import PVDevHarness
#endif
```

In `.onAppear {`, directly after `appDelegate.appState = appState`, add:

```swift
#if PV_DEV_HARNESS
                    // Tuist focused apps only (-PVHarnessROM …); a no-op without harness arguments.
                    DevHarness.start(appState: appState)
#endif
```

- [ ] **Step 3: Wire the package into Tuist**

In `DevSettings`:

```swift
    /// Compilation condition that pulls PVDevHarness into a focused app.
    public static let harnessFlag = "PV_DEV_HARNESS"
```

In `localPackagePaths(for:)`, after the `for app in apps` loop and before `return`:

```swift
        if apps.contains(where: { $0.flags.contains(harnessFlag) }) {
            paths.insert("PVDevHarness")
        }
```

In `FocusedApp.target()`, change the `dependencies:` argument to:

```swift
            dependencies: DevSettings.appDependencies + coreDependencies
                + (flags.contains(DevSettings.harnessFlag) ? [.package(product: "PVDevHarness")] : []),
```

- [ ] **Step 4: Check that the shipping app is unaffected**

Run: `grep -rn "PV_DEV_HARNESS" Provenance.xcodeproj/project.pbxproj Build.xcconfig || echo "not defined in shipping"`
Expected: `not defined in shipping`. The shipping targets compile the hook out.

- [ ] **Step 5: Run the manifest checks, generate, and build both simulators**

Dev simulator builds are ad-hoc signed by `Dev/Config/Dev.xcconfig`, so these commands pass no signing flags.

```bash
Scripts/dev/check_dev_manifest.sh
mise exec -- tuist generate --no-open
for dest in 'generic/platform=iOS Simulator' 'generic/platform=tvOS Simulator'; do
  xcodebuild -workspace Provenance-Dev.xcworkspace -scheme Provenance-Dev-UI -destination "$dest" \
    -skipPackagePluginValidation -skipMacroValidation -derivedDataPath /tmp/claude-501/dev-dd build \
    2>&1 | tee "/tmp/claude-501/t10-$(echo "$dest" | tr -cd 'a-zA-Z').log" | tail -3
done
```

Expected: `dev manifest: OK (3 apps, …)` (`PVDevHarness` is now a local package), and `** BUILD SUCCEEDED **` twice.

- [ ] **Step 6: A normal launch is unaffected**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
xcrun simctl install booted /tmp/claude-501/dev-dd/Build/Products/Debug-iphonesimulator/Provenance-Dev-UI.app
timeout 60 xcrun simctl launch --console-pty --terminate-running-process booted org.provenance-emu.provenance.dev.ui 2>&1 | grep -m1 -E "DevHarness|Bootup completed" || true
```

Expected: no `DevHarness:` line before `Bootup completed`. Without `-PVHarnessROM`, `start` returns immediately. Quit with `xcrun simctl terminate booted org.provenance-emu.provenance.dev.ui`.

- [ ] **Step 7: Lint and commit**


Run: `swiftlint lint --path PVDevHarness --path "Provenance/Main UI/ProvenanceApp.swift"`

```bash
git add PVDevHarness "Provenance/Main UI/ProvenanceApp.swift" Tuist
git -c commit.gpgsign=false commit -m "feat(harness): drive ROM launch, screenshot and report in dev apps" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 11: Test ROM, `make dev-harness`, and simulator runs  *(model: sonnet)*

**Files:**
- Create: `Scripts/dev/make_harness_rom.py` (mode 755): writes a minimal Atari 2600 ROM.
- Create: `Scripts/dev/run_harness.sh` (mode 755)
- Modify: `Makefile`, `Scripts/maint/jobs.toml`

**Interfaces:**
- Consumes:
  - the `-PVHarness*` arguments and the output files `error.txt`, `frames.json`, `screenshot.png`, `log.txt` (Tasks 9–10);
  - `Provenance-Dev-UI` (bundle id `org.provenance-emu.provenance.dev.ui`), which embeds the native SPM cores Stella (`com.provenance.core.stella`, system `com.provenance.2600`, extensions `a26`/`bin`/`zip`), mGBA (`com.provenance.core.mGBA`) and snes9x (`com.provenance.core.snes9x`);
  - Make variables `DEV_WORKSPACE`, `DEV_DERIVED`, and the `_var_%` "must be set" rule.
- Produces:
  - `make_harness_rom.py <out.a26>`, a 4 KiB ROM that loops forever (`JMP $F000`) and renders black;
  - `run_harness.sh <rom> [ui|azahar] [frames] [core id]`, which exits 0 on success, 1 on a harness error or missing outputs, and 2 on usage or setup errors, and copies the outputs to `build/harness/<Scheme>/`;
  - `make dev-harness ROM=<path> [TARGET=ui] [FRAMES=300] [CORE=<id>]`.

**Simulator scope.** The libretro buildbot dylibs are iOS-platform Mach-O binaries and cannot be loaded (`dlopen`) in a simulator process. Simulator runs therefore use native SPM cores in `Provenance-Dev-UI`. `Provenance-Dev-Thin` runs the harness on a device only, through Xcode's scheme arguments (Step 7); `run_harness.sh` refuses `thin`. `Provenance-Dev-Azahar` runs on the arm64 simulator, but a 3DS test ROM is not in the repo, so this task does not exercise it.

- [ ] **Step 1: Write `Scripts/dev/make_harness_rom.py`**

```python
#!/usr/bin/env python3
"""Write a minimal 4 KiB Atari 2600 ROM for the dev harness (Stella).

The ROM is `JMP $F000` at $F000, NOP padding, and reset/IRQ vectors pointing at $F000: it
loops forever and draws a black screen, which is enough to prove import -> launch -> run.
Usage: make_harness_rom.py <output.a26>
"""
import sys
from pathlib import Path

ROM_SIZE = 4096
ENTRY = 0xF000
NOP = 0xEA
JMP_ABS = 0x4C


def rom_bytes() -> bytes:
    data = bytearray([NOP] * ROM_SIZE)
    data[0:3] = bytes([JMP_ABS, ENTRY & 0xFF, ENTRY >> 8])
    for vector in (0xFFC, 0xFFE):  # RESET, IRQ/BRK
        data[vector] = ENTRY & 0xFF
        data[vector + 1] = ENTRY >> 8
    return bytes(data)


def main(argv):
    if len(argv) != 2:
        print(__doc__.strip().splitlines()[-1], file=sys.stderr)
        return 2
    out = Path(argv[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(rom_bytes())
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

Run: `chmod +x Scripts/dev/make_harness_rom.py && Scripts/dev/make_harness_rom.py /tmp/claude-501/harness/loop.a26 && xxd -s 0 -l 4 /tmp/claude-501/harness/loop.a26 && xxd -s 4092 -l 4 /tmp/claude-501/harness/loop.a26`
Expected: the path, then `4c00 f0ea`, then `00f0 00f0`.

- [ ] **Step 2: Write `Scripts/dev/run_harness.sh`**

```bash
#!/bin/bash
# Builds a Tuist focused app for the iOS Simulator, installs it on the booted simulator, runs
# the dev harness against a ROM and copies its outputs to build/harness/<Scheme>/.
# Usage: Scripts/dev/run_harness.sh <rom path> [ui|azahar] [frames] [core identifier]
# Exit: 0 success, 1 harness error (error.txt) or missing outputs, 2 usage/setup error.
# Provenance-Dev-Thin is device-only: buildbot libretro dylibs are iOS-platform binaries and
# cannot be dlopen'ed in a simulator process.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ROM="${1:-}"
TARGET="${2:-ui}"
FRAMES="${3:-300}"
CORE="${4:-}"
[ -n "$ROM" ] && [ -f "$ROM" ] || { echo "usage: $0 <rom path> [ui|azahar] [frames] [core id]" >&2; exit 2; }

case "$TARGET" in
    ui) SCHEME="Provenance-Dev-UI" ;;
    azahar) SCHEME="Provenance-Dev-Azahar" ;;
    thin) echo "run_harness: Provenance-Dev-Thin runs the harness on a device only (libretro dylibs can't load in the simulator)" >&2; exit 2 ;;
    *) echo "run_harness: unknown target '$TARGET' (ui|azahar)" >&2; exit 2 ;;
esac

xcrun simctl list devices booted | grep -q Booted || { echo "run_harness: boot a simulator first (xcrun simctl boot \"iPhone 17\")" >&2; exit 2; }

DERIVED="${DEV_DERIVED:-$ROOT/build/dev-dd}"
(cd "$ROOT" && mise exec -- tuist generate --no-open)
# Ad-hoc signing for simulator SDKs comes from Dev/Config/Dev.xcconfig.
xcodebuild build -workspace "$ROOT/Provenance-Dev.xcworkspace" -scheme "$SCHEME" \
    -destination "generic/platform=iOS Simulator" -derivedDataPath "$DERIVED" \
    -skipPackagePluginValidation -skipMacroValidation 2>&1 | tail -3

APP="$DERIVED/Build/Products/Debug-iphonesimulator/$SCHEME.app"
[ -d "$APP" ] || { echo "run_harness: build produced no $APP" >&2; exit 2; }
BUNDLE=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
xcrun simctl install booted "$APP"

OUT_REL="Documents/Harness/run"
DATA=$(xcrun simctl get_app_container booted "$BUNDLE" data)
rm -rf "${DATA:?}/$OUT_REL"
ROM_ABS="$(cd "$(dirname "$ROM")" && pwd)/$(basename "$ROM")"
ARGS=(-PVHarnessROM "$ROM_ABS" -PVHarnessFrames "$FRAMES" -PVHarnessOut "$OUT_REL")
[ -n "$CORE" ] && ARGS+=(-PVHarnessCore "$CORE")

# --console-pty blocks until the app exits; the harness calls exit() when it is done.
xcrun simctl launch --console-pty --terminate-running-process booted "$BUNDLE" "${ARGS[@]}" || true

DEST="$ROOT/build/harness/$SCHEME"
rm -rf "$DEST" && mkdir -p "$DEST"
cp -R "$DATA/$OUT_REL/." "$DEST/" 2>/dev/null || true
ls -1 "$DEST"
if [ -f "$DEST/error.txt" ]; then
    echo "run_harness: harness error: $(cat "$DEST/error.txt")"
    exit 1
fi
for f in frames.json screenshot.png log.txt; do
    [ -f "$DEST/$f" ] || { echo "run_harness: missing $f" >&2; exit 1; }
done
cat "$DEST/frames.json"
```

Run: `chmod +x Scripts/dev/run_harness.sh && bash -n Scripts/dev/run_harness.sh && Scripts/dev/run_harness.sh; echo "exit=$?"`
Expected: the usage line and `exit=2`.

- [ ] **Step 3: Add the Makefile target**

Add `dev-harness` to `.PHONY`. Then, after `dev-thin:`, add:

```make
## Run the dev harness on the booted simulator:
##   make dev-harness ROM=path/to/rom [TARGET=ui|azahar] [FRAMES=300] [CORE=com.provenance.core.stella]
## Provenance-Dev-Thin is device-only (libretro dylibs don't load in the simulator).
TARGET ?= ui
FRAMES ?= 300
CORE ?=
dev-harness: | _var_ROM
	DEV_DERIVED="$(DEV_DERIVED)" Scripts/dev/run_harness.sh "$(ROM)" "$(TARGET)" "$(FRAMES)" "$(CORE)"
```

Run: `make dev-harness 2>&1 | tail -2`
Expected: the `_var_%` rule fails, asking for `ROM`.

- [ ] **Step 4: Register both scripts**

Append to `Scripts/maint/jobs.toml`:

```toml
[jobs.dev-harness]
title = "Dev harness run"
category = "Dev workspace"
description = "Builds a focused app for the iOS Simulator and runs a ROM through the launch-argument harness (Thin: device only)."
run = ["Scripts/dev/run_harness.sh"]
args_hint = "<rom> [ui|azahar] [frames] [core id]"
files = ["Scripts/dev/make_harness_rom.py"]
needs = ["macos", "mise"]
cli_only = true
```

Run: `python3 Scripts/maint/maint.py status 2>&1 | grep -i unregistered || echo "no unregistered scripts"`
Expected: `no unregistered scripts`.

- [ ] **Step 5: Success path on the simulator (Stella, native SPM core)**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null || true
Scripts/dev/make_harness_rom.py /tmp/claude-501/harness/loop.a26
make dev-harness ROM=/tmp/claude-501/harness/loop.a26 TARGET=ui FRAMES=120 CORE=com.provenance.core.stella; echo "exit=$?"
```

Expected:
- `exit=0`.
- `build/harness/Provenance-Dev-UI/` holds `frames.json`, `screenshot.png` and `log.txt`, and no `error.txt`.
- `frames.json` shows `"core" : "com.provenance.core.stella"`, `"frames" : 120`, `"frameCountSource" : "estimated"`, and `"waitedSeconds"` ≈ 2.
- `file build/harness/Provenance-Dev-UI/screenshot.png` reports `PNG image data`.

If the run ends with `error.txt`, read `log.txt` (it holds the `DevHarness:` lines) and report the failing stage. Do not weaken the harness.

- [ ] **Step 6: Error path on the simulator**

```bash
printf 'x' > /tmp/claude-501/harness/garbage.a26
Scripts/dev/run_harness.sh /tmp/claude-501/harness/garbage.a26 ui 60; echo "exit=$?"
```

Expected: `exit=1`, `run_harness: harness error: …` (`did not start running` or `import of garbage.a26 did not finish`), and `error.txt` plus `log.txt` in `build/harness/Provenance-Dev-UI/`. The default system core is chosen because no `CORE` is passed, which also covers that branch. This run can take up to the 180 s import timeout plus 60 s for the core to start.

- [ ] **Step 7: Document the device-only Thin run (no command to execute here)**

Add this comment block above the `dev-harness` Makefile target:

```make
## Thin on a device: run Provenance-Dev-Thin from Xcode with scheme arguments
##   -PVHarnessROM Documents/<rom> -PVHarnessFrames 300
## after copying the ROM into the app's Documents (Files app or Xcode's Devices window), then
## download the container and read Documents/Harness/<timestamp>/.
```

- [ ] **Step 8: Commit**

```bash
git add Scripts/dev/make_harness_rom.py Scripts/dev/run_harness.sh Makefile Scripts/maint/jobs.toml
git -c commit.gpgsign=false commit -m "feat(harness): add make dev-harness and a 2600 test ROM" -m "Simulator runs: Stella success path and garbage-ROM error path." -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

# Batch 4 — Slice cache (develop)

### Task 12: `Scripts/cores/build_slice.py` and its tests  *(model: sonnet)*

**Files:**
- Create: `Scripts/cores/build_slice.py` (mode 755)
- Test: `Scripts/cores/tests/test_build_slice.py`

**Interfaces:**
- Consumes:
  - `Cores/Azahar/build_azahar_core.py`: `AzaharBuilder(verbose=)`, `.build_platform(<OS64|SIMULATORARM64|TVOS|SIMULATOR_TVOS>)`, `write_gitlink_stamps([platform])`, `.create_xcframework()`. It needs Python ≥ 3.10.
  - `Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py`: `DolphinBuilder(verbose=)`, `.build_platform(p) -> bool`, `.dylibs[p]`, `.create_framework(dylib, p)`, and the CLI flag `-x` (xcframework only).
- Produces:
  - `build_slice.py <azahar|dolphin> <ios|ios-sim|tvos|tvos-sim> [--print-key] [--force] [--cache-dir DIR] [--xcframework] [--repo-root DIR]`;
  - Python functions `core_specs(repo) -> Dict[str, CoreSpec]`, `key_inputs(spec, slice_name, runner, env) -> Dict[str, str]`, `compute_key(spec, slice_name, runner, env) -> str`, `ensure_slice(spec, slice_name, cache, key, inputs, force, builder) -> Path`, `main(argv) -> int`;
  - cache layout `<cache>/<core>/<slice>/<key[:12]>/<Product>-<slice>.framework` + `stamp.json`;
  - legacy symlinks `Cores/Azahar/build/xcframework/PVlibAzahar-<slice>.framework` and `Cores/Dolphin/dolphin-ios/build/xcframework/PVlibDolphin-<slice>.framework`;
  - default cache `$PV_CORE_CACHE`, else `~/Library/Caches/Provenance/cores`.
  - Python 3.9-compatible: Dolphin's Xcode phase runs `/usr/bin/python3`.

- [ ] **Step 1: Write the failing tests**

`Scripts/cores/tests/test_build_slice.py`:

```python
#!/usr/bin/env python3
"""Unit tests for Scripts/cores/build_slice.py (stdlib unittest; no git, Xcode or network)."""
from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_slice  # noqa: E402


def write(path: Path, text: str) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)
    return path


class FakeRunner:
    """Stands in for git / xcodebuild / xcrun."""

    def __init__(self, head="aaaa", status=" bbbb externals/x (v1)\n-cccc externals/y", xcode="Xcode 26.3\nBuild version 17C1", sdk="26.2"):
        self.head, self.status, self.xcode, self.sdk = head, status, xcode, sdk

    def __call__(self, cmd, cwd=None):
        if cmd[-2:] == ["rev-parse", "HEAD"]:
            return self.head
        if "submodule" in cmd:
            return self.status
        if cmd[:2] == ["xcodebuild", "-version"]:
            return self.xcode
        if cmd[0] == "xcrun":
            return self.sdk
        raise AssertionError(f"unexpected command {cmd}")


class FakeRepo:
    def __init__(self, root: Path):
        self.root = root
        write(root / "Cores/Azahar/build_azahar_core.py", "CMAKE_OPTIONS = ['-DENABLE_LTO=OFF']\n")
        write(root / "Cores/Azahar/cmake/ios.toolchain.cmake", "toolchain v1\n")
        (root / "Cores/Azahar/azahar").mkdir(parents=True)
        for mvk in ("ios-arm64", "ios-arm64_x86_64-simulator", "tvos-arm64_arm64e", "tvos-arm64_x86_64-simulator"):
            write(root / f"MoltenVK/MoltenVK/static/MoltenVK.xcframework/{mvk}/libMoltenVK.a", f"mvk {mvk}\n")
        write(root / "Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py", "# dolphin\n")
        write(root / "Cores/Dolphin/dolphin-ios/Externals/ios-cmake/ios.toolchain.cmake", "dolphin toolchain\n")
        self.specs = build_slice.core_specs(root)


class KeyTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.repo = FakeRepo(Path(self.tmp.name))
        self.azahar = self.repo.specs["azahar"]
        self.dolphin = self.repo.specs["dolphin"]

    def tearDown(self):
        self.tmp.cleanup()

    def key(self, spec=None, slice_name="ios-sim", runner=None, env=None):
        return build_slice.compute_key(spec or self.azahar, slice_name, runner or FakeRunner(), env or {})

    def test_stable(self):
        self.assertEqual(self.key(), self.key())

    def test_changes_with_submodule_head(self):
        self.assertNotEqual(self.key(), self.key(runner=FakeRunner(head="dddd")))

    def test_changes_with_nested_submodule(self):
        self.assertNotEqual(self.key(), self.key(runner=FakeRunner(status=" eeee externals/x (v2)")))

    def test_submodule_init_state_does_not_change_key(self):
        a = FakeRunner(status=" bbbb externals/x (v1)")
        b = FakeRunner(status="-bbbb externals/x")
        self.assertEqual(self.key(runner=a), self.key(runner=b))

    def test_changes_with_script_and_toolchain(self):
        before = self.key()
        write(self.repo.root / "Cores/Azahar/build_azahar_core.py", "CMAKE_OPTIONS = ['-DENABLE_LTO=ON']\n")
        after_script = self.key()
        write(self.repo.root / "Cores/Azahar/cmake/ios.toolchain.cmake", "toolchain v2\n")
        self.assertNotEqual(before, after_script)
        self.assertNotEqual(after_script, self.key())

    def test_changes_with_xcode_and_sdk(self):
        self.assertNotEqual(self.key(), self.key(runner=FakeRunner(xcode="Xcode 26.4")))
        self.assertNotEqual(self.key(), self.key(runner=FakeRunner(sdk="26.4")))

    def test_changes_with_moltenvk_slice(self):
        before = self.key()
        write(self.repo.root / "MoltenVK/MoltenVK/static/MoltenVK.xcframework/ios-arm64_x86_64-simulator/libMoltenVK.a", "new\n")
        self.assertNotEqual(before, self.key())

    def test_slices_differ(self):
        self.assertNotEqual(self.key(slice_name="ios"), self.key(slice_name="ios-sim"))

    def test_dolphin_flags_and_profile(self):
        base = self.key(self.dolphin)
        self.assertNotEqual(base, self.key(self.dolphin, env={"DOL_FULL_LTO": "1"}))
        profile = write(self.repo.root / "Cores/Dolphin/dolphin-ios/pgo/icube.profdata", "profile v1")
        with_profile = self.key(self.dolphin)
        self.assertNotEqual(base, with_profile)
        profile.write_text("profile v2")
        self.assertNotEqual(with_profile, self.key(self.dolphin))
        self.assertEqual(base, self.key(self.dolphin, env={"DOL_PGO": "off"}))


class CacheTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        self.repo = FakeRepo(root / "repo")
        self.cache = root / "cache"
        self.spec = self.repo.specs["azahar"]
        self.legacy = self.spec.legacy_dir / "PVlibAzahar-ios-sim.framework"

    def tearDown(self):
        self.tmp.cleanup()

    def fake_build(self, calls):
        def builder(spec, slice_name):
            calls.append(slice_name)
            assert not self.legacy.exists() and not self.legacy.is_symlink(), "legacy path must be cleared before building"
            write(self.legacy / "PVlibAzahar", "archive")
        return builder

    def test_miss_builds_moves_and_links(self):
        calls = []
        fw = build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {"a": "b"}, False, self.fake_build(calls))
        self.assertEqual(calls, ["ios-sim"])
        self.assertEqual(fw, self.cache / "azahar/ios-sim" / ("k" * 12) / "PVlibAzahar-ios-sim.framework")
        self.assertTrue((fw / "PVlibAzahar").is_file())
        self.assertTrue(self.legacy.is_symlink())
        self.assertEqual(Path(os.readlink(self.legacy)), fw)
        stamp = json.loads((fw.parent / "stamp.json").read_text())
        self.assertEqual(stamp["key"], "k" * 64)
        self.assertEqual(stamp["inputs"], {"a": "b"})

    def test_hit_only_links(self):
        calls = []
        build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, False, self.fake_build(calls))
        self.legacy.unlink()
        write(self.legacy / "PVlibAzahar", "stale real dir from an old build")

        def must_not_build(spec, slice_name):
            raise AssertionError("cache hit must not build")

        fw = build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, False, must_not_build)
        self.assertTrue(self.legacy.is_symlink())
        self.assertEqual(Path(os.readlink(self.legacy)), fw)

    def test_force_rebuilds_over_existing_symlink(self):
        calls = []
        build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, False, self.fake_build(calls))
        build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, True, self.fake_build(calls))
        self.assertEqual(calls, ["ios-sim", "ios-sim"])
        self.assertTrue(self.legacy.is_symlink())

    def test_old_entries_pruned(self):
        calls = []
        for key in ("a" * 64, "b" * 64, "c" * 64):
            build_slice.ensure_slice(self.spec, "ios-sim", self.cache, key, {}, False, self.fake_build(calls))
        entries = sorted(p.name for p in (self.cache / "azahar/ios-sim").iterdir())
        self.assertEqual(len(entries), build_slice.KEEP_ENTRIES)
        self.assertIn("c" * 12, entries)

    def test_missing_product_fails(self):
        with self.assertRaises(SystemExit):
            build_slice.ensure_slice(self.spec, "ios-sim", self.cache, "k" * 64, {}, False, lambda spec, s: None)


class CLITests(unittest.TestCase):
    def test_print_key_matches_compute_key(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = FakeRepo(Path(tmp))
            runner = FakeRunner()
            out = io.StringIO()
            with redirect_stdout(out):
                code = build_slice.main(["azahar", "tvos", "--print-key", "--repo-root", tmp], runner=runner, env={})
            self.assertEqual(code, 0)
            self.assertEqual(out.getvalue().strip(), build_slice.compute_key(repo.specs["azahar"], "tvos", runner, {}))

    def test_slice_from_platform_name(self):
        self.assertEqual(build_slice.SLICE_FOR_PLATFORM_NAME["appletvsimulator"], "tvos-sim")
        self.assertEqual(build_slice.SLICE_FOR_PLATFORM_NAME["iphoneos"], "ios")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests and see them fail**

Run: `python3 -m unittest Scripts/cores/tests/test_build_slice.py 2>&1 | tail -3`
Expected: `ModuleNotFoundError: No module named 'build_slice'`.

- [ ] **Step 3: Write `Scripts/cores/build_slice.py`**

```python
#!/usr/bin/env python3
"""Build one Azahar or Dolphin core slice outside the app, cached by a content key.

  build_slice.py <azahar|dolphin> <ios|ios-sim|tvos|tvos-sim> [--print-key] [--force]
                 [--cache-dir DIR] [--xcframework]

Key: sha256 over the core submodule HEAD and `git submodule status --recursive` inside it,
the wrapped build script and CMake toolchain contents (Azahar's CMAKE_OPTIONS live in its
script), Dolphin's DOL_FULL_LTO / DOL_PGO / DOL_PGO_PROFILE and the PGO profile it would use,
`xcodebuild -version`, the slice SDK version and, for Azahar, the MoltenVK static slice it
configures against. `--print-key` prints it (CI cache keys).

Cache: $PV_CORE_CACHE or ~/Library/Caches/Provenance/cores, laid out as
<core>/<slice>/<key[:12]>/<Product>-<slice>.framework + stamp.json. On a hit the legacy output
path (Cores/Azahar/build/xcframework/PVlibAzahar-<slice>.framework,
Cores/Dolphin/dolphin-ios/build/xcframework/PVlibDolphin-<slice>.framework) becomes a symlink
into the cache, so PVAzahar's PVAZAHAR_ARCHIVE path and PVDolphin's references don't change.
On a miss the wrapped builder builds that one slice (its per-platform methods, not its main(),
which would also repack the xcframework), the product moves into the cache and is linked.
--xcframework repacks <Product>.xcframework for distribution; Dolphin also repacks it when it
is missing, since PVDolphin.xcodeproj links the xcframework at planning time.

Python 3.9 compatible (Dolphin's Xcode phase runs /usr/bin/python3). Azahar's builder needs
3.10+, so it runs in a separate interpreter (PV_PYTHON3, Homebrew python3, python3.1x).
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Dict, List, Mapping, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CACHE = Path.home() / "Library" / "Caches" / "Provenance" / "cores"
KEEP_ENTRIES = 2
HOMEBREW_BIN = "/opt/homebrew/bin"

SLICES: Dict[str, Dict[str, str]] = {
    "ios": {"cmake": "OS64", "sdk": "iphoneos", "mvk": "ios-arm64"},
    "ios-sim": {"cmake": "SIMULATORARM64", "sdk": "iphonesimulator", "mvk": "ios-arm64_x86_64-simulator"},
    "tvos": {"cmake": "TVOS", "sdk": "appletvos", "mvk": "tvos-arm64_arm64e"},
    "tvos-sim": {"cmake": "SIMULATOR_TVOS", "sdk": "appletvsimulator", "mvk": "tvos-arm64_x86_64-simulator"},
}

SLICE_FOR_PLATFORM_NAME: Dict[str, str] = {
    "iphoneos": "ios",
    "iphonesimulator": "ios-sim",
    "appletvos": "tvos",
    "appletvsimulator": "tvos-sim",
}

Runner = Callable[[List[str], Optional[Path]], str]
Builder = Callable[["CoreSpec", str], None]


@dataclass(frozen=True)
class CoreSpec:
    name: str
    product: str
    submodule: Path
    script: Path
    toolchain: Path
    legacy_dir: Path
    env_flags: Tuple[str, ...]
    moltenvk: Optional[Path]


def core_specs(repo: Path) -> Dict[str, CoreSpec]:
    return {
        "azahar": CoreSpec(
            name="azahar",
            product="PVlibAzahar",
            submodule=repo / "Cores/Azahar/azahar",
            script=repo / "Cores/Azahar/build_azahar_core.py",
            toolchain=repo / "Cores/Azahar/cmake/ios.toolchain.cmake",
            legacy_dir=repo / "Cores/Azahar/build/xcframework",
            env_flags=(),
            moltenvk=repo / "MoltenVK/MoltenVK/static/MoltenVK.xcframework",
        ),
        "dolphin": CoreSpec(
            name="dolphin",
            product="PVlibDolphin",
            submodule=repo / "Cores/Dolphin/dolphin-ios",
            script=repo / "Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py",
            toolchain=repo / "Cores/Dolphin/dolphin-ios/Externals/ios-cmake/ios.toolchain.cmake",
            legacy_dir=repo / "Cores/Dolphin/dolphin-ios/build/xcframework",
            env_flags=("DOL_FULL_LTO", "DOL_PGO", "DOL_PGO_PROFILE"),
            moltenvk=None,
        ),
    }


def log(message: str) -> None:
    print(f"build_slice: {message}", file=sys.stderr, flush=True)


def default_runner(cmd: List[str], cwd: Optional[Path] = None) -> str:
    result = subprocess.run(cmd, cwd=str(cwd) if cwd else None, check=True, capture_output=True, text=True)
    return result.stdout.strip()


def file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def normalize_submodule_status(text: str) -> str:
    """'<flag><sha> <path> (<describe>)' -> '<sha> <path>', sorted. Init state and describe drop out."""
    entries = []
    for line in text.splitlines():
        if not line.strip():
            continue
        body = line[1:] if line[:1] in " +-U" else line
        parts = body.split()
        if len(parts) >= 2:
            entries.append(f"{parts[0]} {parts[1]}")
    return "\n".join(sorted(entries))


def dolphin_profile(spec: CoreSpec, env: Mapping[str, str]) -> Optional[Path]:
    """The profile BuildiOSXCFramework.resolve_pgo would use (None for off/generate)."""
    mode = env.get("DOL_PGO", "").strip().lower()
    if mode in ("off", "generate"):
        return None
    explicit = env.get("DOL_PGO_PROFILE", "").strip()
    if explicit:
        return Path(explicit)
    default = spec.submodule / "pgo" / "icube.profdata"
    return default if default.exists() else None


def key_inputs(spec: CoreSpec, slice_name: str, runner: Runner, env: Mapping[str, str]) -> Dict[str, str]:
    sl = SLICES[slice_name]
    inputs = {
        "core": spec.name,
        "slice": slice_name,
        "submodule_head": runner(["git", "-C", str(spec.submodule), "rev-parse", "HEAD"], None),
        "submodule_tree": normalize_submodule_status(
            runner(["git", "-C", str(spec.submodule), "submodule", "status", "--recursive"], None)),
        "script": file_hash(spec.script),
        "toolchain": file_hash(spec.toolchain),
        "xcode": runner(["xcodebuild", "-version"], None),
        "sdk": runner(["xcrun", "--sdk", sl["sdk"], "--show-sdk-version"], None),
    }
    for name in spec.env_flags:
        inputs["env:" + name] = env.get(name, "")
    if spec.name == "dolphin":
        profile = dolphin_profile(spec, env)
        inputs["pgo_profile"] = file_hash(profile) if profile is not None and profile.exists() else ""
    if spec.moltenvk is not None:
        inputs["moltenvk"] = file_hash(spec.moltenvk / sl["mvk"] / "libMoltenVK.a")
    return inputs


def compute_key(spec: CoreSpec, slice_name: str, runner: Runner, env: Mapping[str, str]) -> str:
    blob = json.dumps(key_inputs(spec, slice_name, runner, env), sort_keys=True).encode()
    return hashlib.sha256(blob).hexdigest()


def framework_name(spec: CoreSpec, slice_name: str) -> str:
    return f"{spec.product}-{slice_name}.framework"


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def link_legacy(spec: CoreSpec, slice_name: str, target: Path) -> Path:
    legacy = spec.legacy_dir / framework_name(spec, slice_name)
    remove_path(legacy)
    legacy.parent.mkdir(parents=True, exist_ok=True)
    os.symlink(str(target), str(legacy))
    return legacy


def prune_entries(slice_dir: Path, keep: int, current: Path) -> None:
    entries = [p for p in slice_dir.iterdir() if p.is_dir() and p != current]
    entries.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    for stale in entries[max(0, keep - 1):]:
        log(f"pruning old cache entry {stale}")
        shutil.rmtree(stale)


def ensure_slice(spec: CoreSpec, slice_name: str, cache: Path, key: str, inputs: Mapping[str, str],
                 force: bool, builder: Builder) -> Path:
    entry = cache / spec.name / slice_name / key[:12]
    framework = entry / framework_name(spec, slice_name)
    stamp = entry / "stamp.json"
    if not force and framework.is_dir() and stamp.is_file():
        link_legacy(spec, slice_name, framework)
        log(f"{spec.name} {slice_name}: cache hit {key[:12]}")
        return framework

    legacy = spec.legacy_dir / framework_name(spec, slice_name)
    remove_path(legacy)  # the builders rmtree() this path, which fails on a symlink
    log(f"{spec.name} {slice_name}: cache miss {key[:12]}; building")
    builder(spec, slice_name)
    if legacy.is_symlink() or not legacy.is_dir():
        raise SystemExit(f"build_slice: {legacy} was not produced by the {spec.name} builder")

    remove_path(entry)
    entry.mkdir(parents=True)
    shutil.move(str(legacy), str(framework))
    stamp.write_text(json.dumps({
        "key": key,
        "inputs": dict(inputs),
        "built": datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z",
    }, indent=2, sort_keys=True) + "\n")
    link_legacy(spec, slice_name, framework)
    prune_entries(entry.parent, KEEP_ENTRIES, entry)
    log(f"{spec.name} {slice_name}: cached {framework}")
    return framework


AZAHAR_BUILD = (
    "import sys; sys.path.insert(0, sys.argv[1]); import build_azahar_core as b; "
    "builder = b.AzaharBuilder(verbose=True); builder.build_platform(sys.argv[2]); "
    "b.write_gitlink_stamps([sys.argv[2]])"
)
AZAHAR_XCFRAMEWORK = (
    "import sys; sys.path.insert(0, sys.argv[1]); import build_azahar_core as b; "
    "b.AzaharBuilder(verbose=True).create_xcframework()"
)
DOLPHIN_BUILD = (
    "import sys; sys.path.insert(0, sys.argv[1]); import BuildiOSXCFramework as d; "
    "builder = d.DolphinBuilder(verbose=True); p = sys.argv[2]; ok = builder.build_platform(p); "
    "sys.exit(1) if ok is False or p not in builder.dylibs else builder.create_framework(builder.dylibs[p], p)"
)


def python_for(spec: CoreSpec) -> str:
    if spec.name != "azahar":
        return sys.executable
    candidates = [os.environ.get("PV_PYTHON3", ""), HOMEBREW_BIN + "/python3", "python3", "python3.12", "python3.11", "python3.10"]
    for candidate in candidates:
        if not candidate:
            continue
        path = candidate if os.path.isabs(candidate) else shutil.which(candidate)
        if not path or not os.path.exists(path):
            continue
        check = subprocess.run([path, "-c", "import sys; print(sys.version_info >= (3, 10))"],
                               capture_output=True, text=True)
        if check.stdout.strip() == "True":
            return path
    raise SystemExit("build_slice: Azahar needs python3 >= 3.10 (brew install python@3.12, or set PV_PYTHON3)")


def build_env() -> Dict[str, str]:
    env = dict(os.environ)
    env["PATH"] = HOMEBREW_BIN + os.pathsep + env.get("PATH", "")
    return env


def run_wrapped_build(spec: CoreSpec, slice_name: str) -> None:
    snippet = AZAHAR_BUILD if spec.name == "azahar" else DOLPHIN_BUILD
    subprocess.run([python_for(spec), "-c", snippet, str(spec.script.parent), SLICES[slice_name]["cmake"]],
                   check=True, env=build_env(), cwd=str(spec.script.parent))


def pack_xcframework(spec: CoreSpec) -> None:
    log(f"{spec.name}: packing {spec.product}.xcframework from the slices present")
    if spec.name == "azahar":
        cmd = [python_for(spec), "-c", AZAHAR_XCFRAMEWORK, str(spec.script.parent)]
    else:
        cmd = [sys.executable, str(spec.script), "-x"]
    subprocess.run(cmd, check=True, env=build_env(), cwd=str(spec.script.parent))


def main(argv: Optional[List[str]] = None, runner: Runner = default_runner,
         env: Optional[Mapping[str, str]] = None, builder: Builder = run_wrapped_build) -> int:
    parser = argparse.ArgumentParser(description="Build or link one cached Azahar/Dolphin core slice.")
    parser.add_argument("core", choices=["azahar", "dolphin"])
    parser.add_argument("slice", choices=sorted(SLICES))
    parser.add_argument("--print-key", action="store_true", help="print the cache key and exit")
    parser.add_argument("--force", action="store_true", help="rebuild even on a cache hit")
    parser.add_argument("--cache-dir", type=Path, help="cache root (default $PV_CORE_CACHE or ~/Library/Caches/Provenance/cores)")
    parser.add_argument("--xcframework", action="store_true", help="also repack <Product>.xcframework (distribution)")
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT, help=argparse.SUPPRESS)
    args = parser.parse_args(argv)

    environment = dict(os.environ) if env is None else dict(env)
    spec = core_specs(args.repo_root.resolve())[args.core]
    inputs = key_inputs(spec, args.slice, runner, environment)
    key = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    if args.print_key:
        print(key)
        return 0

    cache = args.cache_dir or Path(environment.get("PV_CORE_CACHE") or DEFAULT_CACHE)
    ensure_slice(spec, args.slice, cache.expanduser(), key, inputs, args.force, builder)
    xcframework = spec.legacy_dir / f"{spec.product}.xcframework"
    if args.xcframework or (spec.name == "dolphin" and not xcframework.exists()):
        pack_xcframework(spec)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

Run: `chmod +x Scripts/cores/build_slice.py`

- [ ] **Step 4: Run the tests and see them pass**

Run: `python3 -m unittest Scripts/cores/tests/test_build_slice.py -v 2>&1 | tail -5`
Expected: `Ran 16 tests` … `OK`.
Then run `/usr/bin/python3 -m unittest Scripts/cores/tests/test_build_slice.py 2>&1 | tail -2`.
Expected: `OK` (Python 3.9).

- [ ] **Step 5: Check the real key**

Run: `python3 Scripts/cores/build_slice.py azahar ios-sim --print-key; python3 Scripts/cores/build_slice.py azahar ios-sim --print-key`
Expected: the same 64-hex line twice.

- [ ] **Step 6: Commit**

```bash
git add Scripts/cores
git -c commit.gpgsign=false commit -m "feat(cores): cache Azahar/Dolphin slices by content key" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 13: Aggregates call `build_slice.py`; registry; `dev-generate` pre-build  *(model: sonnet)*

**Files:**
- Modify: `Cores/Azahar/PVAzahar.xcodeproj/project.pbxproj` (the shell of phase `3EEEB32A1ECE41C0CF0EE800 /* Build PVlibAzahar */`)
- Modify: `Cores/Azahar/project.yml` (`BuildPVlibAzahar.buildScripts[0].script`)
- Modify: `Cores/Dolphin/PVDolphin.xcodeproj/project.pbxproj` (the shell of phase `B3DE9E412E2D7333008E97F6 /* build_dolphin_core */` in aggregate `Make XCFrameworks`)
- Modify: `Scripts/maint/jobs.toml`, `Makefile`

**Interfaces:**
- Consumes: `build_slice.py <core> <slice>` (Task 12).
- Produces: aggregates that cache-link or build the active slice; Make variables `DEV_PREBUILT_CORES ?=` and `DEV_SLICE ?= ios-sim`.

- [ ] **Step 1: Write the new Azahar script into `project.yml`**

Replace the whole `script: |` block of `BuildPVlibAzahar` (from `set -euo pipefail` to the final `fi`) with:

```yaml
        script: |
          set -euo pipefail
          if [ ! -f "$PROJECT_DIR/azahar/CMakeLists.txt" ]; then
            echo "error: azahar submodule not initialized. Run 'git submodule update --init --recursive Cores/Azahar' (or 'make setup'), then rebuild."; exit 1
          fi
          command -v cmake >/dev/null 2>&1 || [ -x /opt/homebrew/bin/cmake ] || { echo "error: cmake not found - 'brew install cmake ninja'"; exit 1; }
          command -v ninja >/dev/null 2>&1 || [ -x /opt/homebrew/bin/ninja ] || { echo "error: ninja not found - 'brew install cmake ninja'"; exit 1; }
          export PATH="/opt/homebrew/bin:$PATH"
          case "${PLATFORM_NAME}" in
            iphoneos)         slice=ios ;;
            iphonesimulator)  slice=ios-sim ;;
            appletvos)        slice=tvos ;;
            appletvsimulator) slice=tvos-sim ;;
            *) echo "error: unsupported PLATFORM_NAME ${PLATFORM_NAME}"; exit 1 ;;
          esac
          # Links the cached slice for this content key into build/xcframework/PVlibAzahar-<slice>.framework
          # (the archive PVAzahar links via PVAZAHAR_ARCHIVE), building it on a miss. Never repacks the xcframework.
          python3 "$PROJECT_DIR/../../Scripts/cores/build_slice.py" azahar "$slice"
```

- [ ] **Step 2: Mirror it into the hand-edited pbxproj**

Do not run xcodegen. Run this Python from the repo root. It reads the script back out of `project.yml`, so the two copies stay identical:

```bash
python3 - <<'PY'
from pathlib import Path

yml = Path("Cores/Azahar/project.yml").read_text().splitlines()
start = next(i for i, l in enumerate(yml) if l.strip() == "script: |" and "Build PVlibAzahar" in "\n".join(yml[i-4:i]))
indent = len(yml[start + 1]) - len(yml[start + 1].lstrip())
body = []
for line in yml[start + 1:]:
    if line.strip() and (len(line) - len(line.lstrip())) < indent:
        break
    body.append(line[indent:])
while body and not body[-1].strip():
    body.pop()
script = "\n".join(body) + "\n"

def pbx_quote(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t").replace("\n", "\\n")

p = Path("Cores/Azahar/PVAzahar.xcodeproj/project.pbxproj")
lines = p.read_text().split("\n")
idx = [i for i, l in enumerate(lines) if l.lstrip().startswith("shellScript = ") and "build_azahar_core.py" in l]
assert len(idx) == 1, idx
lead = lines[idx[0]][: len(lines[idx[0]]) - len(lines[idx[0]].lstrip())]
lines[idx[0]] = f'{lead}shellScript = "{pbx_quote(script)}";'
p.write_text("\n".join(lines))
print("updated", p)
PY
```

Run: `plutil -lint Cores/Azahar/PVAzahar.xcodeproj/project.pbxproj && grep -c 'build_slice.py' Cores/Azahar/PVAzahar.xcodeproj/project.pbxproj`
Expected: `OK` and `1`.

- [ ] **Step 3: Replace the Dolphin phase script**

The new script for `build_dolphin_core` keeps the preflight and the rsync, and replaces the direct `BuildiOSXCFramework.py` call:

```bash
set -euo pipefail

SCRIPT="$PROJECT_DIR/dolphin-ios/BuildiOSXCFramework.py"

# --- Preflight: fail early with actionable guidance instead of an opaque 'no XCFramework found' link error ---
if [ ! -f "$SCRIPT" ]; then
  echo "error: Dolphin submodule not initialized - $SCRIPT is missing. Run 'git submodule update --init --recursive' (or 'make setup') from the repo root, then rebuild."
  exit 1
fi
if [ ! -x /opt/homebrew/bin/cmake ] && ! command -v cmake >/dev/null 2>&1; then
  echo "error: cmake not found - required to build the Dolphin core. Install with 'brew install cmake ninja' (or run 'make setup'), then rebuild."
  exit 1
fi
if [ ! -x /opt/homebrew/bin/ninja ] && ! command -v ninja >/dev/null 2>&1; then
  echo "error: ninja not found - required to build the Dolphin core. Install with 'brew install ninja' (or run 'make setup'), then rebuild."
  exit 1
fi

case "${PLATFORM_NAME}" in
  iphoneos)         slice="ios" ;;
  iphonesimulator)  slice="ios-sim" ;;
  appletvos)        slice="tvos" ;;
  appletvsimulator) slice="tvos-sim" ;;
  *) echo "error: unsupported PLATFORM_NAME ${PLATFORM_NAME} (Mac Catalyst is not supported)"; exit 1 ;;
esac

# Links the cached slice for this content key into dolphin-ios/build/xcframework/PVlibDolphin-<slice>.framework,
# building it on a miss; packs PVlibDolphin.xcframework only when it is missing.
/usr/bin/python3 "$PROJECT_DIR/../../Scripts/cores/build_slice.py" dolphin "$slice"

# Xcode's ProcessXCFramework step copies the slice into BUILT_PRODUCTS_DIR BEFORE this phase
# has rebuilt it, so the first app build after any core change would link and embed the
# PREVIOUS core. Put the slice that was just built where the linker and the embed step look.
fresh="$PROJECT_DIR/dolphin-ios/build/xcframework/PVlibDolphin-${slice}.framework"
if [[ -d "${fresh}" && -n "${BUILT_PRODUCTS_DIR:-}" ]]; then
  mkdir -p "${BUILT_PRODUCTS_DIR}/PVlibDolphin-${slice}.framework"
  /usr/bin/rsync -a --delete "${fresh}/" "${BUILT_PRODUCTS_DIR}/PVlibDolphin-${slice}.framework/"
  echo "Synced fresh PVlibDolphin-${slice}.framework into ${BUILT_PRODUCTS_DIR}"
fi
```

Save it as `/tmp/claude-501/dolphin-phase.sh`, then substitute it:

```bash
python3 - <<'PY'
from pathlib import Path

script = Path("/tmp/claude-501/dolphin-phase.sh").read_text()
if not script.endswith("\n"):
    script += "\n"

def pbx_quote(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\t", "\\t").replace("\n", "\\n")

p = Path("Cores/Dolphin/PVDolphin.xcodeproj/project.pbxproj")
lines = p.read_text().split("\n")
idx = [i for i, l in enumerate(lines) if l.lstrip().startswith("shellScript = ") and "BuildiOSXCFramework.py" in l]
assert len(idx) == 1, idx
lead = lines[idx[0]][: len(lines[idx[0]]) - len(lines[idx[0]].lstrip())]
lines[idx[0]] = f'{lead}shellScript = "{pbx_quote(script)}";'
p.write_text("\n".join(lines))
print("updated", p)
PY
plutil -lint Cores/Dolphin/PVDolphin.xcodeproj/project.pbxproj
```

Expected: `updated …` and `OK`.

- [ ] **Step 4: Verify Azahar through the aggregate (warm and cold-link paths)**

Run: `xcodebuild -project Cores/Azahar/PVAzahar.xcodeproj -target BuildPVlibAzahar -sdk iphonesimulator -configuration Debug build 2>&1 | grep -E "build_slice|BUILD" | tail -5`
Expected:
- The first run prints `build_slice: azahar ios-sim: cache miss …`. If `Cores/Azahar/build/SIMULATORARM64` already holds a finished ninja tree, ninja relinks in minutes; otherwise this is the 30–40 minute cold build, so run it in the background and poll.
- `ls -l Cores/Azahar/build/xcframework/PVlibAzahar-ios-sim.framework` shows a symlink into `~/Library/Caches/Provenance/cores/azahar/ios-sim/`.
- A second run prints `cache hit` and finishes in seconds.

- [ ] **Step 5: Verify the Azahar dev app still links**

Run: `make dev-azahar 2>&1 | tail -2`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Register in `jobs.toml`**

Add under `[ignore].paths`:

```toml
  # Wrapped by Scripts/cores/build_slice.py (outside the scan roots; listed for discoverability).
  "Cores/Azahar/build_azahar_core.py",
  "Cores/Dolphin/dolphin-ios/BuildiOSXCFramework.py",
```

Add a job:

```toml
[jobs.core-slices]
title = "Build or link a cached core slice"
category = "Dev workspace"
description = "Azahar/Dolphin per-slice build keyed by submodule, script, toolchain, flags, Xcode and SDK; called by the BuildPVlibAzahar and Make XCFrameworks aggregates."
run = ["python3", "Scripts/cores/build_slice.py"]
args_hint = "<azahar|dolphin> <ios|ios-sim|tvos|tvos-sim> [--print-key] [--force] [--xcframework]"
files = ["Scripts/cores/tests/*.py"]
needs = ["macos", "submodules"]
cli_only = true
```

In `[jobs.script-tests]`, add `&& python3 -m unittest discover -s Scripts/cores/tests -p 'test_*.py'` before `&& bash Scripts/tests/test-get-modules-validation.sh`.

Run: `python3 Scripts/maint/maint.py status 2>&1 | grep -i unregistered || echo "no unregistered scripts"`
Expected: `no unregistered scripts`.

- [ ] **Step 7: Add the `dev-generate` pre-build**

Replace the `dev-generate` recipe from Task 3 with:

```make
# Cores linked as .prebuilt xcframeworks must exist before `tuist generate` (Tuist reads them
# eagerly). None of the initial focused apps use one; add e.g. "dolphin" when one does.
DEV_PREBUILT_CORES ?=
DEV_SLICE ?= ios-sim
dev-generate:
	@for core in $(DEV_PREBUILT_CORES); do python3 Scripts/cores/build_slice.py $$core $(DEV_SLICE) || exit 1; done
	$(TUIST) generate --no-open
```

Run: `make dev-generate 2>&1 | tail -1`
Expected: `Project generated.`

- [ ] **Step 8: Commit**

```bash
git add Cores/Azahar/project.yml Cores/Azahar/PVAzahar.xcodeproj/project.pbxproj Cores/Dolphin/PVDolphin.xcodeproj/project.pbxproj Scripts/maint/jobs.toml Makefile
git -c commit.gpgsign=false commit -m "build(cores): Azahar and Dolphin aggregates use the slice cache" -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

The Dolphin aggregate is not built here: a cold Dolphin slice takes 30–60 minutes. CI in Task 14 exercises it on both legs.

---

### Task 14: CI caches and `dev-workspace.yml`  *(model: sonnet)*

**Files:**
- Modify: `.github/workflows/build.yml`, `.github/workflows/testflight.yml`
- Create: `.github/workflows/dev-workspace.yml`

**Interfaces:**
- Consumes: `build_slice.py --print-key`; `Provenance-Dev-UI`.
- Produces: per-leg cache `cores-${{ runner.os }}-<sdk|platform>-<azahar16>-<dolphin16>`.

The GitHub Actions bot cannot push workflow changes, so this task commits locally only. The coordinator pushes it.

- [ ] **Step 1: `build.yml`: exclude the Dolphin build trees from the submodules cache**

In the `Cache submodules` step's `path:` list, after `!Cores/Azahar/build`, add:

```yaml
            !Cores/Dolphin/dolphin-ios/build-*
```

- [ ] **Step 2: `build.yml`: replace the Azahar cache with the slice cache**

Delete the steps `Azahar submodule gitlink` and `Cache azahar build`, including their comments. Insert in their place:

```yaml
      # Core slices (Azahar, Dolphin) are cached by Scripts/cores/build_slice.py content keys:
      # submodule + nested externals, build script, toolchain, flags, Xcode and SDK. One entry per
      # leg; the aggregates then link the cached slice instead of rebuilding it.
      - name: Core slice cache keys
        id: core-keys
        run: |
          case "${{ matrix.sdk }}" in
            iphoneos) slice=ios ;;
            appletvos) slice=tvos ;;
            *) echo "::error::unknown sdk ${{ matrix.sdk }}"; exit 1 ;;
          esac
          echo "slice=$slice" >> "$GITHUB_OUTPUT"
          echo "azahar=$(python3 Scripts/cores/build_slice.py azahar "$slice" --print-key | cut -c1-16)" >> "$GITHUB_OUTPUT"
          echo "dolphin=$(python3 Scripts/cores/build_slice.py dolphin "$slice" --print-key | cut -c1-16)" >> "$GITHUB_OUTPUT"

      - name: Cache core slices
        uses: actions/cache@v4
        with:
          path: ~/Library/Caches/Provenance/cores
          key: cores-${{ runner.os }}-${{ matrix.sdk }}-${{ steps.core-keys.outputs.azahar }}-${{ steps.core-keys.outputs.dolphin }}
          restore-keys: |
            cores-${{ runner.os }}-${{ matrix.sdk }}-
```

These steps sit where the old ones were, which is after `Initialize submodules` and `Setup Xcode`. Both are required: the key reads submodule HEADs and `xcodebuild -version`. Confirm with `grep -n "name: Initialize submodules\|name: Setup Xcode\|name: Core slice cache keys" .github/workflows/build.yml`: the line numbers increase in that order.

- [ ] **Step 3: `testflight.yml`: same caches**

In its `Cache submodules` `path:` list, add `!Cores/Azahar/build` and `!Cores/Dolphin/dolphin-ios/build-*`. After the `Setup Xcode` step, insert:

```yaml
      - name: Core slice cache keys
        id: core-keys
        run: |
          slice="${{ matrix.platform }}"   # ios | tvos (device slices)
          echo "azahar=$(python3 Scripts/cores/build_slice.py azahar "$slice" --print-key | cut -c1-16)" >> "$GITHUB_OUTPUT"
          echo "dolphin=$(python3 Scripts/cores/build_slice.py dolphin "$slice" --print-key | cut -c1-16)" >> "$GITHUB_OUTPUT"

      - name: Cache core slices
        uses: actions/cache@v4
        with:
          path: ~/Library/Caches/Provenance/cores
          key: cores-${{ runner.os }}-${{ matrix.platform }}-${{ steps.core-keys.outputs.azahar }}-${{ steps.core-keys.outputs.dolphin }}
          restore-keys: |
            cores-${{ runner.os }}-${{ matrix.platform }}-
```

- [ ] **Step 4: Write `.github/workflows/dev-workspace.yml`**

```yaml
name: Dev workspace

# Generates Provenance-Dev.xcworkspace with Tuist and builds Provenance-Dev-UI for both
# simulators (ad-hoc signed by Dev/Config/Dev.xcconfig). The fast smoke build for agent PRs
# (replaces Provenance-CI in a follow-up).
on:
  pull_request:
    branches: [develop]
    paths:
      - "Tuist.swift"
      - "Workspace.swift"
      - "Tuist/**"
      - "Dev/**"
      - ".mise.toml"
      - "Build.xcconfig"
      - "Build-iOS.xcconfig"
      - "Provenance/Main UI/**"
      - "Provenance/Provenance-Lite (AppStore)-Info.plist"
      - "PV*/**"
      - "Cores/mGBA/**"
      - "Cores/Stella/**"
      - "Cores/snes9x/**"
      - ".github/workflows/dev-workspace.yml"
  push:
    branches: [develop]
  workflow_dispatch:

concurrency:
  group: dev-workspace-${{ github.ref }}
  cancel-in-progress: true

env:
  TUIST_VERSION: "4.200.0"

jobs:
  build:
    name: Provenance-Dev-UI (${{ matrix.destination }})
    runs-on: macos-26
    timeout-minutes: 90
    strategy:
      fail-fast: false
      matrix:
        destination: ["generic/platform=iOS Simulator", "generic/platform=tvOS Simulator"]
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: false
          fetch-depth: 1

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_26.3.app

      # Same set as agent-validation's smoke build (package resolution needs them), plus the
      # three cores Provenance-Dev-UI embeds.
      - name: Init required submodules (shallow)
        run: |
          git submodule update --init --depth 1 \
            Cores/4DO \
            Cores/Bliss \
            Cores/CrabEMU \
            Dependencies/HexColors \
            Dependencies/SWCompression \
            Cores/Mednafen/ThirdParty/libchdr \
            PVRcheevos/rcheevos \
            Cores/mGBA/Sources/libmGBA-embed/mgba \
            Cores/Stella/Sources/libstella/stella \
            Cores/snes9x/snes9x-src \
            Cores/snes9x/libretro-snes9x
          git submodule update --init --depth 1 --recursive Cores/VirtualJaguar
          if ! git submodule update --init --depth 1 Dependencies/ZipArchive 2>/dev/null; then
            rm -rf Dependencies/ZipArchive
            git clone --depth 1 https://github.com/ZipArchive/ZipArchive.git Dependencies/ZipArchive
          fi

      - name: Cache libretro cheat database
        uses: actions/cache@v4
        with:
          path: PVLookup/Sources/LibretroCheatDB/Resources/libretro_cheats.sqlite.zip
          key: ${{ runner.os }}-cheatdb-${{ hashFiles('Scripts/generators/generate_cheatdb.py', 'PVLookup/Scripts/generate_cheatdb_if_needed.sh') }}

      - name: Generate libretro cheat database if missing
        run: ./PVLookup/Scripts/generate_cheatdb_if_needed.sh

      - name: Install Tuist (mise)
        run: |
          curl -fsSL https://mise.run | sh
          echo "$HOME/.local/bin" >> "$GITHUB_PATH"
          echo "$HOME/.local/share/mise/shims" >> "$GITHUB_PATH"
          "$HOME/.local/bin/mise" install "tuist@${TUIST_VERSION}"

      - name: Manifest checks
        run: Scripts/dev/check_dev_manifest.sh

      - name: Generate
        run: mise exec -- tuist generate --no-open

      - name: Build
        run: |
          set -o pipefail
          xcodebuild build \
            -workspace Provenance-Dev.xcworkspace \
            -scheme Provenance-Dev-UI \
            -destination "${{ matrix.destination }}" \
            -skipPackagePluginValidation -skipMacroValidation \
            2>&1 | tee /tmp/dev-xcodebuild.log | grep -E "(: (fatal )?error:|BUILD (SUCCEEDED|FAILED)|The following build commands failed)" | tail -60

      - name: Upload log on failure
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: dev-xcodebuild-log-${{ strategy.job-index }}
          path: /tmp/dev-xcodebuild.log
          retention-days: 3
```

Check the submodule paths for snes9x against `.gitmodules` (`path = Cores/snes9x/libretro-snes9x` and `path = Cores/snes9x/snes9x-src` at the time of writing). Remove one if `grep -n "path = Cores/snes9x" .gitmodules` disagrees.

- [ ] **Step 5: Validate the workflow syntax**

Run: `python3 -c "import yaml,sys; [yaml.safe_load(open(f)) for f in sys.argv[1:]]; print('ok')" .github/workflows/build.yml .github/workflows/testflight.yml .github/workflows/dev-workspace.yml 2>/dev/null || ruby -ryaml -e 'ARGV.each { |f| YAML.load_file(f) }; puts "ok"' .github/workflows/build.yml .github/workflows/testflight.yml .github/workflows/dev-workspace.yml`
Expected: `ok`. If `actionlint` is installed, also run `actionlint .github/workflows/dev-workspace.yml .github/workflows/build.yml .github/workflows/testflight.yml`.

- [ ] **Step 6: Commit**

```bash
git add .github/workflows/build.yml .github/workflows/testflight.yml .github/workflows/dev-workspace.yml
git -c commit.gpgsign=false commit -m "ci: cache core slices per leg; add dev workspace smoke build" -m "Workflow files: a maintainer must push (bot lacks workflows permission)." -m "Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

# Batch 5 — Pruning PR (branch `feature/prune-dead-cores`; merged only after `build.yml` passes both legs)

### Task 15: Retired-core model, per-system migration, save-state flag, prune guard  *(model: sonnet)*

**Files:** `PVLibrary/Sources/PVRealm/RealmPlatform/Entities/PVCore.swift`, `PVLibrary/Sources/PVLibrary/Migration/RetiredCoreMigration.swift`, `PVLibrary/Sources/PVLibrary/Configuration/PVEmulatorConfiguration+Frameworks.swift` (stale-core prune at line ~295), `PVLibrary/Tests/PVLibraryTests/RetiredCoreMigrationTests.swift`.

**Interfaces:** produces
- `public enum RetiredCoreID` and `public enum LibretroCoreID` (string constants; the Jaguar entry moves onto them);
- `public struct RetiredBatterySaveRule { location: .batterySaves | .saveStates; fileExtension; moveToBatterySaves; copyToSRM }`;
- `public struct RetiredCore { replacement; systemReplacements: [SystemIdentifier: String]; migratesSaveStates; batterySaves; func replacement(forSystem:) ; allReplacements }`;
- `PVCore.retiredCores: [String: RetiredCore]` and `PVCore.activeRetiredCores` (every replacement bundled). The existing `retiredCoreReplacements` / `activeRetiredCoreReplacements` stay as derived views;
- `currentIdentifier(for:)` remaps only entries with `migratesSaveStates == true`;
- `RetiredCoreMigration.migrate(in:retiredCores:)`.

What it does:
- `migrate` checks that every replacement is registered. It then repoints game and system preferences and recents through `replacement(forSystem:)`, using the game's or system's identifier. It moves save states only when `migratesSaveStates` is true.
- The stale-core prune skips identifiers in `PVCore.retiredCores`. Otherwise the disabled row would be deleted, leaving unmigrated save states with a nil core; Lite builds, which bundle no replacements, would be hit too.

Verified by the PVLibrary-UnitTests scheme (`-only-testing:PVLibraryTests/RetiredCoreMigrationTests`): the existing tests adapted, plus per-system choice (Coleco vs SG-1000), states left alone when formats differ, and a testable `currentIdentifier(for:in:)`.

### Task 16: Battery-save file pass  *(model: sonnet)*

**Files:** new `PVLibrary/Sources/PVLibrary/Migration/RetiredBatterySaveMigration.swift`, `PVEmulatorConfiguration+Frameworks.swift` (launch after migrate + prune), new `PVLibrary/Tests/PVLibraryTests/RetiredBatterySaveMigrationTests.swift`.

**Interfaces:** `struct RetiredBatterySaveJob: Sendable { retiredID; rules; romBases }`; `enum RetiredBatterySaveMigration { migrate(romBase:rules:batteryRoot:saveStatesRoot:fileManager:) -> [String]; run(_:batteryRoot:saveStatesRoot:fileManager:defaults:); isDone/markDone (UserDefaults key "RetiredBatterySaveMigration.<id>") }`.

What it does:
- Games are chosen through the retired core row's `supportedSystems`. The ROM base is computed from `game.romPath` without touching iCloud paths, outside the Realm write.
- A detached utility task then resolves `Paths.batterySavesPath` and `Paths.saveSavesPath`.
- For each rule, the source `<root>/<rom>/<rom>.<ext>` is optionally moved into `Battery States/<rom>/`, then copied to `<rom>.srm` if that file is absent. Nothing is overwritten. The pass logs what it did and runs once per retired core.

Verified by temp-dir unit tests: copy to `.srm` keeping the original; no overwrite of an existing `.srm`; move from Save States plus `.srm` (melonDS); `.dsv` move without `.srm` (DeSmuME); a missing source is a no-op; `run` marks the core done in an injected `UserDefaults(suiteName:)`.

### Task 17: Retired-core entries  *(model: sonnet)*

**Files:** `PVCore.swift` (table), `RetiredCoreMigrationTests.swift` (table test).

What it adds:

| Retired ID | Replacement |
|---|---|
| `com.provenance.core.atari800` | `atari800.libretro.framework`; `.Atari5200` → `a5200.libretro.framework` |
| `com.provenance.core.bliss` | `freeintv` |
| `com.provenance.core.crabemu` | `genesis.plus.gx`; `.ColecoVision` → `gearcoleco`. The plist also lists the non-existent `com.provenance.sms` |
| `com.provenance.core.gambatte` | `gambatte` |
| `com.provenance.core.odyssey2` | `o2em` |
| `com.provenance.core.pokemini` | `pokemini` |
| `com.provenance.core.visualboyadvance` | `vbam` |
| `com.provenance.core.desmume2015` | `desmume` |
| `com.provenance.core.MelonDS` | `melonds` |
| `beetlepsx` | `mednafen.psx.hw` |
| `FreeIntv` | `freeintv` |
| `GME` | `gme` |
| `gearcoleco` | `gearcoleco` |
| `Mu` | `mu` |
| `mupen64plusnx` | `mupen64plus.next` |
| `potator` | `potator` |
| `minivmac` | `minivmac` (not App Store; the retirement stays inactive where it isn't bundled) |
| `Yabause` | `yabause` |
| `PCSXRearmed` | `pcsx.rearmed` |
| `Fuse` | `fuse` |
| `opera` | `opera` |

In the table, IDs without a prefix are `com.provenance.core.<id>`, and every replacement is `<name>.libretro.framework`. All replacements are `enabled: true` for iOS and tvOS in `cores.yml`.

Battery rules, read from each bridge:

| Retired core | Rule |
|---|---|
| CrabEMU | `.sav` in Battery States (not Coleco) → `.srm` |
| Gambatte | `.sav` → `.srm`; `.rtc` is not carried |
| PokeMini | `.eep` → `.srm` |
| VBA-M | `.sav2` → `.srm` |
| melonDS | `.sav` in Save States → move + `.srm` |
| Desmume2015 | `.sav` and `.dsv` in Save States → move |
| Atari800 | none: the bridge says `batterySavesPath` is unused |
| Bliss, O2EM | no battery code found |
| Legacy-libretro-bridge cores (BeetlePSX, FreeIntv, GME, Gearcoleco, Mu, Potator, Mini vMac, Yabause, PCSX-ReARMed, Fuse, Opera) | none: `PVLibRetroCore+Saves.m` never persisted `RETRO_MEMORY_SAVE_RAM` |
| Mupen64Plus-NX | none: its per-type mupen files differ from libretro's combined SAVE_RAM |

`migratesSaveStates` is false for all new entries; Jaguar keeps true.

Skipped as never runnable: DosBox and VecX (`PVDisabled`), snesticle (no producer), supergrafx (no Core.plist), and DuckStation, Play and Reicast (never embedded).

Verified by a test that locates the repo through `#filePath`, reads `CoresRetro/RetroArch/Core.plist`, and asserts every replacement ID is a `PVCoreIdentifier` there.

### Task 18: Prune the shipping project with a script  *(model: opus)*

**Files:** new `Scripts/dev/prune_cores.rb` (registered under `[ignore]` "Developer one-offs"), `Provenance.xcodeproj/project.pbxproj`, `Provenance.xcworkspace/contents.xcworkspacedata`, `.gitmodules`, `Cores/<X>` (deleted).

What it does: a Ruby `xcodeproj` script with a `CORES` table and the flags `--dry-run` (default) and `--apply`. Per core it removes these object kinds:
- `PBXBuildFile`s in every target's Frameworks and Embed (copy-files) phases, matched by file-ref basename or by `product_ref.product_name`;
- target `packageProductDependencies` and every `XCSwiftPackageProductDependency` with those product names (many lack a `package` key, so match on `productName`);
- `XCLocalSwiftPackageReference` objects (root list and orphans) by `relativePath`;
- `PBXFileReference`s by basename;
- any `PBXContainerItemProxy` / `PBXReferenceProxy` / `projectReferences` entries that point at a removed `.xcodeproj`;
- `LIBRARY_/FRAMEWORK_/HEADER_SEARCH_PATHS` entries containing `Cores/<X>/` (e.g. `Cores/Play/lib`);
- the workspace `<FileRef location = "group:Cores/<X>/….xcodeproj">` elements (text edit);
- the core directories and their `.gitmodules` sections, via `git rm -r -f Cores/<X>` and then `rm -rf` of the untracked leftovers.

The table:

| Core | Frameworks / products | Package or project |
|---|---|---|
| Atari800 | `PVAtari800-Dynamic` | package `Cores/Atari800` |
| Bliss | `PVBliss-Dynamic` | package `Cores/Bliss` |
| CrabEMU | `PVCrabEmu-Dynamic` | package `Cores/CrabEMU` |
| Gambatte | `PVGambatte`, `PVGambatte-Dynamic` | package `Cores/Gambatte` |
| PokeMini | `PVPokeMini-Dynamic` | package `Cores/PokeMini` |
| VisualBoyAdvance-M | `PVVisualBoyAdvance-Dynamic` | package `Cores/VisualBoyAdvance-M` |
| VirtualJaguar | `PVVirtualJaguar-Dynamic` | package `Cores/VirtualJaguar` |
| O2EM | `PVO2EM.framework` | `Cores/O2EM/PVO2EM.xcodeproj` |
| Desmume2015 | `PVDesmume2015.framework` | `Cores/Desmume2015/PVDesmume2015.xcodeproj` |
| melonDS | `PVMelonDS.framework`, `PVMelonDSRetro.framework` | `Cores/melonDS/PVMelonDS.xcodeproj` |
| BeetlePSX | `PVBeetlePSX.framework` | `Cores/BeetlePSX/PVBeetlePSX.xcodeproj` |
| DosBox | `PVDosBox.framework`, `PVDosBoxRetro.framework` | `Cores/DosBox/PVDosBox.xcodeproj` |
| DuckStation | — | workspace only |
| FreeIntv | `PVFreeIntv.framework` | `Cores/FreeIntv/PVFreeIntv.xcodeproj` |
| GameMusicEmu | `PVGME.framework` | `Cores/GameMusicEmu/PVGME.xcodeproj` |
| Gearcoleco | `PVGearcoleco.framework` | `Cores/Gearcoleco/PVGearcoleco.xcodeproj` |
| Mini_vMac | `PVMiniVMac.framework`, `PVMiniVMacRetro.framework` | `Cores/Mini_vMac/PVMiniVMac.xcodeproj` |
| Mu | `PVMu.framework` | `Cores/Mu/PVMu.xcodeproj` |
| Mupen64Plus-NX | `PVMupen64Plus-NX.framework` | `Cores/Mupen64Plus-NX/PVMupen64Plus-NX.xcodeproj` |
| Potator | `PVPotator.framework` | `Cores/Potator/PVPotator.xcodeproj` |
| Reicast | — | workspace only |
| VecX | `PVVecX.framework` | `Cores/VecX/PVVecX.xcodeproj` |
| Yabause | `PVYabause.framework` | `Cores/Yabause/PVYabause.xcodeproj` |
| fuse | `PVFuse.framework` | `Cores/fuse/PVFuse.xcodeproj` |
| opera | `PVOpera.framework` | `Cores/opera/PVOpera.xcodeproj` |
| pcsx_rearmed | `PVPCSXRearmed.framework` | `Cores/pcsx_rearmed/PVPCSXRearmed.xcodeproj` |
| supergrafx | `PVSupergrafx.framework` | `Cores/supergrafx/PVSupergrafx.xcodeproj` |
| snesticle | `PVSnesticle.framework` | — |
| Play | — | search path only |
| JollyGoodEmulation, Sudachi, sm64ex | — | directory and submodules only |

Orphans with no producer: `PVLibRetro.framework` and `PVFreeDO.framework`. Only the framework reference goes; `PVFreeDO-Dynamic` (4DO) stays.

**`Cores/Debug` stays.** `PVMupen64Plus.xcodeproj`, `PVDolphin.xcodeproj`, `PVPPSSPP.xcodeproj` and `Provenance.xcodeproj` reference `PVDebug.c`.

Verified by:
1. A round-trip check first: open and save with no changes, then `git diff --stat Provenance.xcodeproj` must be near zero. Gemfile.lock pins xcodeproj 1.25.0; if it can't open objectVersion 74, use `gem install --user-install xcodeproj -v '>= 1.27'`, and stop if the format churns.
2. The dry-run report (counts per object kind per core), reviewed before `--apply`.
3. After applying: `plutil -lint`; `xcodebuild -list -workspace Provenance.xcworkspace` has no removed project; `grep` finds no removed product names left in the pbxproj.

### Task 19: Remaining references to pruned cores  *(model: sonnet)*

**Files:**
- `PVCoreLoader/Package.swift`: drop the `../Cores/Atari800`, `PokeMini`, `VirtualJaguar` and `VisualBoyAdvance-M` dependencies and their `PVCoreEnumerator` products;
- `PVCoreLoader/Sources/PVCoreEnumerator/CoreEnumerator.swift`: drop the four `canImport` cases;
- `Scripts/ci/ci-init-submodules.sh`: `REQUIRED_FILES` currently names `Cores/VirtualJaguar/Package.swift`; pick a kept package such as `Cores/Stella/Package.swift`;
- `Scripts/tests/test-ci-init-submodules.sh`;
- `.github/workflows/agent-validation.yml` (smoke-build and pvcorebridgeretro-test init lists: Bliss, CrabEMU, VirtualJaguar) and `dev-workspace.yml`;
- `Scripts/audits/pbxproj_sources_allowlist.txt` and `check_pbxproj_sources.py` inputs;
- `Scripts/maint/jobs.toml`.

Verified by:
- `grep -rn` for each pruned directory and product name across `*.swift`, `Package.swift`, `*.yml`, `*.sh`, `*.toml`, `*.pbxproj` and `*.xcworkspacedata` (worktrees and `.build` excluded) returns nothing;
- `bash Scripts/tests/test-ci-init-submodules.sh` and `python3 Scripts/audits/check_pbxproj_sources.py` pass;
- PVLibrary-UnitTests are green;
- `make dev-ui` is green.

The coordinator then pushes the branch and triggers `build.yml` (owner PRs need the label or `/build`).

### Task 20: Pruning-PR docs  *(model: haiku)*

**Files:** `CLAUDE.md` (core taxonomy: drop Jaguar and "Flycast" from the active natives, link the audit doc, add "no new `Cores/` project without an audit row"), `docs/RELEASE_SMOKE_TESTS.md` (a DS game boots through `melondsds` with a migrated `.sav` → `.srm`; one native-core battery save shows up in its thin replacement).

Verified by a review of the diff. The PR description lists the retirements and accepted losses: Gambatte/VBA-M cheats; the Atari800, Gambatte, PokeMini and VBA-M rcheevos maps; Atari800 mouse; Gambatte `.rtc`; Lite (AppStore) losing the pruned systems.

# Batch 6 — Docs (develop)

### Task 21: CLAUDE.md "Dev workspace", fast-iteration skill, roadmap  *(model: sonnet)*

**Files:** `CLAUDE.md` (new "Dev workspace" section: `make dev` / `dev-generate`, the three targets, the harness arguments, the slice cache and `--print-key`, the helper location `Tuist/ProjectDescriptionHelpers`, the `.xcodeproj` link mechanism, the pruning rule), `.claude/skills/fast-iteration/SKILL.md` (four recipes: add a focused target, build one core slice, run the harness against a ROM, add a libretro dylib to a target), `docs/superpowers/specs/2026-10-09-dev-velocity-roadmap.md` (mark Workstream A done; follow-ups: move CI, fastlane and release.sh to the generated project, retire `Provenance-CI` and `create_ci_target.rb`).

Verified by: the skill's commands are copy-pasted from the merged Makefile and scripts. The coordinator writes the handoff memory file.

---

# Self-review

## Spec coverage

| Spec § | Requirement | Task(s) |
|---|---|---|
| §2.1 | Second workspace; shipping project untouched | T1–T3 (Global Constraints) |
| §2.2 | Generated files gitignored | T1 |
| §2.3 | Tuist 4.200.0 in `.mise.toml` | T1 |
| §2.4 | Only audited cores modelled; prune RETIRE + DS + 7 save-check cores | T2, T3, T5 (rows); T15–T19 (outlined) |
| §2.5 | iOS + tvOS from the start | T2, T3, T7 (both-sim builds); T8 is iOS-only per §12 |
| §2.6 | Project named `Provenance` in `Dev/` | T2 |
| §3 | Layout, `Tuist.swift`, `Workspace.swift`, `Dev.xcconfig`, delete root `project.yml`, local package pattern | T1, T2 (helpers moved to `Tuist/ProjectDescriptionHelpers`, deviation 1) |
| §4 | `CoreLink` / `CoreProduct` table | T2, T3, T5 (`.project` reinterpreted, deviation 2) |
| §5 | `FocusedApp` template and target table | T2, T3, T7, T8 |
| §6 | `LibretroCores` pre/post scripts; `get-modules.sh --urls` | T6, T7 (deviations 4, 5) |
| §7 | `PVDevHarness`, app hook, `make dev-harness` | T9–T11 (detailed; Thin harness is device-only) |
| §8 | `build_slice.py`, aggregates, registry | T12, T13 (detailed; deviation 6) |
| §9 | `build.yml` / `testflight.yml` caches, `dev-workspace.yml` | T14 (detailed) |
| §10 | Pruning, `RetiredCoreMigration` entries, battery rules, docs | T15–T20 (outlined; Debug kept, deviation 7) |
| §11 | CLAUDE.md, fast-iteration skill, roadmap | T20, T21 (outlined) |
| §12 | Verification: generate, builds, harness, unittest, manifest tests, pruning CI | T2/T3/T7/T8 builds, T4 manifest checks, T11, T12, T19 |
| §13 | Six batches | Batches 1–6 |
| §14 | Out of scope | Not touched |

Batches 4–6 are outlined only; batch 3 was detailed on 2026-10-10. Each remaining batch gets full step-by-step code when it starts.

## Placeholder scan

Batches 1–2 contain no TBD, TODO or "similar to Task N"; every code step shows the code. The intentionally empty values are `DEV_PREBUILT_CORES` (empty by default, explained) and `linkerSettings` returning `[:]` in T2, which T3 replaces with the shown code. Batches 4–6 are outlines by the coordinator's scope cut; batch 3 (T9–T11) is detailed.

## Name consistency

- `CoreLink.package/project/prebuilt` and `.paths`, `CoreProduct.links/all/nonCore`, and `FocusedApp.allCores/projectProducts/linkerSettings/scripts/workspaceProjects(for:)` are used identically in T2, T3, T4, T5, T7 and T8.
- `DevSettings.localPackagePaths(for:)`, `packages(for:)`, `appSettings(for:)`, `embedProjectFrameworksScript(products:)` and `harnessFlag` (T10) are consistent.
- `LibretroCores.scripts(slug:names:) -> (pre:, post:)` is consumed in T7.
- Scheme names `Provenance-Dev-UI/-Azahar/-Thin` match `FocusedApp.name` = `"Provenance-Dev-\(title)"`.
- Core row counts in T4 (6) and T5 (15) match the arrays as written.
