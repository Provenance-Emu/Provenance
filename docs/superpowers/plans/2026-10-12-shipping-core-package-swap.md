# Shipping-Project Core Package Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `Provenance.xcodeproj` consumes snes9x, FCEU, Genesis-Plus-GX and Mupen64Plus as local SwiftPM packages (like Stella and mGBA already are) instead of the hand-maintained `Cores/<X>/*.xcodeproj` frameworks. Azahar and Dolphin get a recorded keep-or-move decision, and the per-core xcodeprojs are deleted only after a TestFlight build passes on devices.

**Architecture:** Each swap is one commit per core that, together, (1) deletes the core's `BUILT_PRODUCTS_DIR` framework references from every app target, (2) adds an `XCLocalSwiftPackageReference` plus the `-Dynamic` product (link + "Embed Frameworks", `CodeSignOnCopy`) to the same targets, and (3) drops the core's xcodeproj from `Provenance.xcworkspace`. A text-editing Ruby script does the pbxproj edits (the `xcodeproj` gem is used read-only for lookups, because an open/save through the gem reorders objects and drops `attributesByRelativePath`, see `Scripts/dev/prune_cores.rb`). The gate per core is the CI archive on iOS and tvOS plus an unchanged set of core identifiers in the IPAs, measured by a fixed `Scripts/ci/ci-core-manifest.py`.

**Tech Stack:** Xcode 26 project format, SwiftPM local packages, Ruby (`xcodeproj` 1.27 gem, system Ruby, no Bundler), Python 3 (stdlib only), GitHub Actions `build.yml`.

**Spec:** `docs/superpowers/specs/2026-10-11-core-spm-conversion.md` (phases 1–4 done in PR #3739; it lists this swap as the next, out-of-scope step). Research behind this plan: the core-by-target table and pipeline findings below were taken from the pbxproj, workspace, schemes, `Scripts/release/release.sh` and the workflows on 2026-10-12.

## Global Constraints

- iOS 17+ and tvOS 17+; arm64 only on every SDK (Intel unsupported, `Build.xcconfig` excludes x86_64 simulator slices).
- `Provenance.xcodeproj` keeps shipping through `Scripts/release/release.sh` (scheme `Provenance (AppStore)`) and `build.yml` (scheme `Provenance (AppStore) (Release)`); neither may change scheme or destination in this plan.
- Keep each core's current target set exactly. snes9x, FCEU, Genesis, Mupen64Plus: `Provenance`, `Provenance (AppStore)`, `Provenance-XL`, `Provenance-Lite (AppStore)`. Not `Provenance-Lite`, `Provenance-UnderDevelopment`, `Provenance-CI`.
- Always the `-Dynamic` product. Do not copy the Mednafen/Gambatte precedent of linking the non-Dynamic product in some targets.
- New pbxproj object IDs start with `C0C0CAFE` (24 hex chars total).
- Never commit a `Package.resolved` that drops to `"version" : 2` or loses the `ziparchive` pin (stale-regeneration hazard).
- No local `xcodebuild` builds or test runs during implementation; CI and the user's device tests are the gates. `xcodebuild -resolvePackageDependencies` (resolution only) is allowed.
- Every new script under `Scripts/` is registered in `Scripts/maint/jobs.toml`.
- Commits: conventional prefixes, subject < 72 chars, ending with the session's `Co-Authored-By` line.

## Review Focus

- **Resource files a core reads at runtime.** In a package the files sit in `<Package>_<Target>.bundle` at the app root, not in the framework, so `bundleForClass:`/`Bundle(for:)` misses them. Audited 2026-10-12: only Mupen64Plus had extra files (ini + `mupencheat.txt`), fixed in `38cebb9af3`. Task 6 re-checks the built IPA for those files.
- **Two copies of one core.** `CoreLoader` does not de-duplicate `Core.plist`s, so a target that embeds both the old framework and the package shows the core twice (and two images define the same ObjC classes). Every swap task's verify step asserts zero old framework references in every target.
- **Principal-class/module mismatch.** `NSClassFromString(PVPrincipleClass)` returns nil if the package's Swift module differs from the plist prefix. Mupen was wrong until `d19b00d5bd`; Task 1's test pins all four modules.
- **Package pin drift.** Adding a local package can add or bump remote pins in `Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved`; each swap task diffs it and rejects unexpected bumps.
- **Mupen plugin loading by name.** The bridge `dlopen`s `<name>.framework/<name>` then `<name>-Dynamic.framework/<name>-Dynamic`; all four plugin products must be embedded in every Mupen target, which Task 6's verify step checks.

---

## Core × target today (from `Provenance.xcodeproj/project.pbxproj`)

| Core | Old framework file references | Package (path → product) | Targets |
|---|---|---|---|
| snes9x | `PVSNES.framework`, `snes9x.framework` | `Cores/snes9x` → `PVSNES9x-Dynamic` | Provenance, AppStore, XL, Lite (AppStore) |
| FCEU | `PVFCEU.framework` | `Cores/FCEU` → `PVFCEU-Dynamic` | same four |
| Genesis | `PVGenesis.framework` | `Cores/Genesis-Plus-GX` → `PVCoreGenesisPlus-Dynamic` | same four |
| Mupen64Plus | `PVMupen64Plus`, `PVMupen64PlusBridge`, `PVMupen64PlusRspHLE`, `PVMupen64PlusVideoRice`, `PVMupen64PlusVideoGlideN64`, `PVRSPCXD4` (`.framework`) | `Cores/Mupen64Plus` → `PVMupenGameCore-Dynamic` + `PVMupen64PlusRspHLE-Dynamic`, `PVRSPCXD4-Dynamic`, `PVMupen64PlusVideoRice-Dynamic`, `PVMupen64PlusVideoGlideN64-Dynamic` | same four |
| Azahar | `PVAzahar.framework` | `Cores/Azahar` → `PVAzahar-Dynamic` | the four + Provenance-Lite |
| Dolphin | `PVDolphin.framework` (+ `PVlibDolphin.xcframework` in AppStore) | `Cores/Dolphin` → `PVDolphin-Dynamic` | Provenance, AppStore, XL |

Cores reach the app only through the workspace (no `PBXTargetDependency`/`PBXReferenceProxy`; implicit build order). No app, UI or extension code imports these core modules, and runtime discovery is by `Core.plist` scan plus `PVCoreIdentifier`/`PVPrincipleClass`, so the framework name and bundle id changing (e.g. `PVSNES.framework`/`org.provenance-emu.PVSNES` → `PVSNES9x-Dynamic.framework`/`snes9x.PVSNES9x-Dynamic`) affects no user data. Stella and mGBA already ship this way.

## File map

| File | Responsibility |
|---|---|
| `Scripts/ci/ci-core-manifest.py` (modify) | Also report package cores (`<bundle>.bundle/Core.plist` at the app root); `--identifiers` prints one `PVCoreIdentifier` per line per IPA for diffs |
| `Scripts/tests/test_ci_core_manifest.py` (create) | Synthetic-IPA tests for the above |
| `Scripts/tests/test_core_package_modules.py` (create) | Pins Swift module name == `PVPrincipleClass` prefix for every converted package |
| `Scripts/dev/swap_core_to_package.rb` (create) | Text-edits `Provenance.xcodeproj` + workspace for one core: remove old framework refs, add package + product deps; `--verify` mode |
| `Scripts/tests/test_swap_core_to_package.py` (create) | Runs the script on a temp copy of the project and checks the result with `plutil -convert json` |
| `Scripts/maint/jobs.toml` (modify) | Registers the new scripts |
| `Provenance.xcodeproj/project.pbxproj`, `Provenance.xcworkspace/contents.xcworkspacedata`, `Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved` (modify, per core) | The swaps |
| `docs/superpowers/specs/2026-10-12-azahar-dolphin-package-decision.md` (create) | Task 7's recorded decision |
| `Cores/{snes9x,FCEU,Genesis-Plus-GX,Mupen64Plus}/*.xcodeproj` (delete, Task 8) | Cleanup after device pass |

---

### Task 1: Manifest sees package cores; module-name guard

**Files:**
- Modify: `Scripts/ci/ci-core-manifest.py` (`read_ipa`, new `core_identifiers`, `main` arg parsing)
- Create: `Scripts/tests/test_ci_core_manifest.py`
- Create: `Scripts/tests/test_core_package_modules.py`

**Interfaces:**
- Produces: `read_ipa(path) -> IPAReport` whose `frameworks` now also holds package cores as `Framework(name="<Bundle>.bundle", core_plist=...)`; `core_identifiers(report) -> list[str]` (sorted `PVCoreIdentifier`s of native cores); CLI `ci-core-manifest.py --identifiers IPA...` printing `<ipa-basename>\t<identifier>` lines.

- [ ] **Step 1: Write the failing tests**

`Scripts/tests/test_ci_core_manifest.py`:

```python
"""Tests for Scripts/ci/ci-core-manifest.py using synthetic IPAs."""
import importlib.util
import io
import plistlib
import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/ci/ci-core-manifest.py"
spec = importlib.util.spec_from_file_location("ci_core_manifest", SCRIPT)
manifest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manifest)

APP = "Payload/Provenance.app"


def core_plist(identifier: str) -> bytes:
    return plistlib.dumps({"PVCoreIdentifier": identifier, "PVProjectName": identifier})


def make_ipa(path: Path) -> None:
    with zipfile.ZipFile(path, "w") as zf:
        zf.writestr(f"{APP}/Provenance", b"x" * 10)
        # xcodeproj-style core: Core.plist inside the framework
        zf.writestr(f"{APP}/Frameworks/PVSNES.framework/PVSNES", b"x" * 100)
        zf.writestr(f"{APP}/Frameworks/PVSNES.framework/Core.plist", core_plist("com.provenance.core.snes9x"))
        # SwiftPM-style core: code in the -Dynamic framework, Core.plist in a root resource bundle
        zf.writestr(f"{APP}/Frameworks/PVStella-Dynamic.framework/PVStella-Dynamic", b"x" * 100)
        zf.writestr(f"{APP}/PVCoreStella_PVStella.bundle/Core.plist", core_plist("com.provenance.core.stella"))
        # nested Core.plist deeper in a bundle must not count
        zf.writestr(f"{APP}/Other.bundle/Sub/Core.plist", core_plist("com.provenance.core.bogus"))
        zf.writestr(f"{APP}/Frameworks/mgba.libretro.framework/mgba", b"x" * 50)
        zf.writestr(f"{APP}/Frameworks/PVLibrary.framework/PVLibrary", b"x" * 70)


class ManifestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.ipa = Path(self.tmp.name) / "Provenance-iOS.ipa"
        make_ipa(self.ipa)

    def tearDown(self):
        self.tmp.cleanup()

    def test_both_core_layouts_are_native_cores(self):
        report = manifest.read_ipa(str(self.ipa))
        self.assertEqual(
            manifest.core_identifiers(report),
            ["com.provenance.core.snes9x", "com.provenance.core.stella"],
        )

    def test_package_core_reported_by_bundle_name(self):
        report = manifest.read_ipa(str(self.ipa))
        names = {f.name for f in report.frameworks if f.is_native_core}
        self.assertIn("PVCoreStella_PVStella.bundle", names)

    def test_identifiers_cli(self):
        out = subprocess.run(
            [sys.executable, str(SCRIPT), "--identifiers", str(self.ipa)],
            check=True, capture_output=True, text=True,
        ).stdout.splitlines()
        self.assertEqual(out, [
            "Provenance-iOS.ipa\tcom.provenance.core.snes9x",
            "Provenance-iOS.ipa\tcom.provenance.core.stella",
        ])


if __name__ == "__main__":
    unittest.main()
```

`Scripts/tests/test_core_package_modules.py`:

```python
"""A package core's Swift module must equal its Core.plist PVPrincipleClass prefix,
or NSClassFromString returns nil and the core never instantiates (Mupen, 2026-10-12)."""
import plistlib
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# core dir -> Core.plist path (relative to the core dir) of the package's Swift target
CORES = {
    "snes9x": "PVSNES/Core.plist",
    "FCEU": "PVFCEU/Core.plist",
    "Genesis-Plus-GX": "Sources/PVCoreGenesisPlus/Resources/Core.plist",
    "Mupen64Plus": "Sources/PVMupen/Resources/Core.plist",
    "Azahar": "PVAzahar/Core.plist",
    "Dolphin": "PVDolphin/Core.plist",
}


def swift_target_names(manifest: str) -> set[str]:
    return set(re.findall(r'\.target\(\s*name:\s*"([^"]+)"', manifest))


class ModuleNameTests(unittest.TestCase):
    def test_principal_class_module_is_a_package_target(self):
        for core, plist_rel in CORES.items():
            with self.subTest(core=core):
                plist = plistlib.loads((ROOT / "Cores" / core / plist_rel).read_bytes())
                module = plist["PVPrincipleClass"].split(".")[0]
                manifest = (ROOT / "Cores" / core / "Package.swift").read_text()
                self.assertIn(module, swift_target_names(manifest))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `python3 -m unittest Scripts/tests/test_ci_core_manifest.py Scripts/tests/test_core_package_modules.py -v`
Expected: manifest tests FAIL (`AttributeError: ... has no attribute 'core_identifiers'`). The module test should PASS already (Mupen fixed in `d19b00d5bd`); if a core fails, the regex misses a target declared through a `let x: Target = .target(` variable. Widen the regex to `r'name:\s*"([^"]+)"'` inside `.target(` blocks only if that happens, and re-run.

- [ ] **Step 3: Implement**

In `read_ipa`, inside the `for info in zf.infolist():` loop, before `match = re.search(r"/Frameworks/...`, add:

```python
            # SwiftPM cores keep Core.plist in a resource bundle at the app root
            # (<Package>_<Target>.bundle), not in their -Dynamic framework.
            bundle = re.match(r"Payload/[^/]+\.app/([^/]+\.bundle)/(.*)$", name)
            if bundle:
                b_name, rest = bundle.group(1), bundle.group(2)
                if rest == "Core.plist":
                    fw = frameworks.setdefault(b_name, Framework(name=b_name))
                    try:
                        fw.core_plist = plistlib.loads(zf.read(name))
                    except Exception as exc:
                        print(f"::warning::{report.ipa}: unreadable Core.plist in "
                              f"{b_name}: {exc}", file=sys.stderr)
                elif b_name in frameworks:
                    frameworks[b_name].size += info.file_size
                continue
```

Add after `read_ipa`:

```python
def core_identifiers(report: IPAReport) -> list[str]:
    """Sorted PVCoreIdentifiers of the native cores, for before/after diffs."""
    return sorted(
        (f.core_plist or {}).get("PVCoreIdentifier", f.name)
        for f in report.frameworks if f.is_native_core
    )
```

In `main`, add `parser.add_argument("--identifiers", action="store_true", help="print '<ipa>\\t<PVCoreIdentifier>' lines and exit")`, make `--out` optional (`required=False`), and before rendering:

```python
    if args.identifiers:
        for path in args.ipas:
            report = read_ipa(path)
            for ident in core_identifiers(report):
                print(f"{report.ipa}\t{ident}")
        return 0
    if not args.out:
        parser.error("--out is required unless --identifiers is given")
```

(Match the existing positional name for the IPA list; read `main` first and reuse its variable.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `python3 -m unittest Scripts/tests/test_ci_core_manifest.py Scripts/tests/test_core_package_modules.py -v`
Expected: all PASS.

- [ ] **Step 5: Record the baseline from the newest develop alpha**

```bash
mkdir -p build/core-baseline && cd build/core-baseline
gh release download --repo Provenance-Emu/Provenance --pattern '*.ipa' "$(gh release list --repo Provenance-Emu/Provenance --limit 1 --json tagName -q '.[0].tagName')"
python3 ../../Scripts/ci/ci-core-manifest.py --identifiers *.ipa > baseline.txt
wc -l baseline.txt
```

Expected: one line per core per IPA, including `com.provenance.core.stella` (previously invisible to the manifest). `build/` is gitignored; keep the file for every later gate.

- [ ] **Step 6: Commit**

```bash
git add Scripts/ci/ci-core-manifest.py Scripts/tests/test_ci_core_manifest.py Scripts/tests/test_core_package_modules.py
git commit -m "fix(ci): core manifest reports SwiftPM cores; add --identifiers"
```

---

### Task 2: The swap script

**Files:**
- Create: `Scripts/dev/swap_core_to_package.rb`
- Create: `Scripts/tests/test_swap_core_to_package.py`
- Modify: `Scripts/maint/jobs.toml` (`[ignore].paths`, "Developer one-offs" group)

**Interfaces:**
- Produces: `ruby Scripts/dev/swap_core_to_package.rb <core> [--apply] [--verify]` where `<core>` ∈ `snes9x fceu genesis mupen64plus`. Default prints a unified diff of a temp copy. `--apply` edits in place. `--verify` exits 0 when no target references an old framework and every listed target has every product (link + embed), else prints the offenders and exits 1. `PROJECT_DIR` env var overrides the repo root (tests use it).

- [ ] **Step 1: Write the failing test**

`Scripts/tests/test_swap_core_to_package.py`:

```python
"""Runs swap_core_to_package.rb against a temp copy of the shipping project."""
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "Scripts/dev/swap_core_to_package.rb"
TARGETS = ["Provenance", "Provenance (AppStore)", "Provenance-XL", "Provenance-Lite (AppStore)"]


def have_gem() -> bool:
    return subprocess.run(["ruby", "-e", 'require "xcodeproj"'], capture_output=True).returncode == 0


@unittest.skipUnless(have_gem(), "xcodeproj gem not installed")
class SwapTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        shutil.copytree(ROOT / "Provenance.xcodeproj", self.tmp / "Provenance.xcodeproj")
        (self.tmp / "Provenance.xcworkspace").mkdir()
        shutil.copy(ROOT / "Provenance.xcworkspace/contents.xcworkspacedata",
                    self.tmp / "Provenance.xcworkspace/contents.xcworkspacedata")

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_script(self, *args):
        env = dict(os.environ, PROJECT_DIR=str(self.tmp))  # keep PATH: the gem lives in the user's Ruby
        return subprocess.run(["ruby", str(SCRIPT), *args], env=env, capture_output=True, text=True)

    def objects(self):
        out = subprocess.check_output(["plutil", "-convert", "json", "-o", "-",
                                       str(self.tmp / "Provenance.xcodeproj/project.pbxproj")])
        return json.loads(out)["objects"]

    def test_snes9x_swap(self):
        self.assertEqual(self.run_script("snes9x", "--verify").returncode, 1)
        res = self.run_script("snes9x", "--apply")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.assertEqual(self.run_script("snes9x", "--verify").returncode, 0)
        subprocess.run(["plutil", "-lint", str(self.tmp / "Provenance.xcodeproj/project.pbxproj")], check=True)

        objs = self.objects()
        targets = {o["name"]: o for o in objs.values() if o.get("isa") == "PBXNativeTarget"}
        for t in TARGETS:
            deps = [objs[d]["productName"] for d in targets[t].get("packageProductDependencies", [])]
            self.assertIn("PVSNES9x-Dynamic", deps, t)
        old = [o for o in objs.values() if o.get("isa") == "PBXFileReference"
               and o.get("path") in ("PVSNES.framework", "snes9x.framework")]
        self.assertEqual(old, [])
        ws = (self.tmp / "Provenance.xcworkspace/contents.xcworkspacedata").read_text()
        self.assertNotIn("Cores/snes9x/PVSNES9x.xcodeproj", ws)

    def test_apply_is_idempotent(self):
        self.assertEqual(self.run_script("fceu", "--apply").returncode, 0)
        before = (self.tmp / "Provenance.xcodeproj/project.pbxproj").read_text()
        self.assertEqual(self.run_script("fceu", "--apply").returncode, 0)
        self.assertEqual(before, (self.tmp / "Provenance.xcodeproj/project.pbxproj").read_text())

    def test_mupen_embeds_all_plugins(self):
        self.assertEqual(self.run_script("mupen64plus", "--apply").returncode, 0)
        objs = self.objects()
        targets = {o["name"]: o for o in objs.values() if o.get("isa") == "PBXNativeTarget"}
        for t in TARGETS:
            deps = {objs[d]["productName"] for d in targets[t].get("packageProductDependencies", [])}
            self.assertTrue({"PVMupenGameCore-Dynamic", "PVMupen64PlusRspHLE-Dynamic", "PVRSPCXD4-Dynamic",
                             "PVMupen64PlusVideoRice-Dynamic", "PVMupen64PlusVideoGlideN64-Dynamic"} <= deps, t)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run it to verify it fails**

Run: `python3 -m unittest Scripts/tests/test_swap_core_to_package.py -v`
Expected: FAIL/ERROR (script missing).

- [ ] **Step 3: Write the script**

`Scripts/dev/swap_core_to_package.rb`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Swaps one native core in the shipping project from its hand-maintained xcodeproj framework to
# its local SwiftPM package (docs/superpowers/plans/2026-10-12-shipping-core-package-swap.md).
#
#   ruby Scripts/dev/swap_core_to_package.rb snes9x            # dry run: diff of a temp copy
#   ruby Scripts/dev/swap_core_to_package.rb snes9x --apply    # edit in place
#   ruby Scripts/dev/swap_core_to_package.rb snes9x --verify   # 0 = swapped cleanly, 1 = not
#
# The xcodeproj gem is used READ-ONLY to find UUIDs. Writes are text edits, like
# Scripts/dev/prune_cores.rb: a gem open/save reorders objects and drops attributesByRelativePath.

require 'digest'
require 'fileutils'
require 'open3'
require 'set'
require 'tmpdir'
require 'xcodeproj'

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

TARGETS = ['Provenance', 'Provenance (AppStore)', 'Provenance-XL', 'Provenance-Lite (AppStore)'].freeze

CORES = {
  'snes9x' => { frameworks: %w[PVSNES.framework snes9x.framework], package: 'Cores/snes9x',
                products: %w[PVSNES9x-Dynamic], xcodeproj: 'Cores/snes9x/PVSNES9x.xcodeproj' },
  'fceu' => { frameworks: %w[PVFCEU.framework], package: 'Cores/FCEU',
              products: %w[PVFCEU-Dynamic], xcodeproj: 'Cores/FCEU/PVFCEU.xcodeproj' },
  'genesis' => { frameworks: %w[PVGenesis.framework], package: 'Cores/Genesis-Plus-GX',
                 products: %w[PVCoreGenesisPlus-Dynamic], xcodeproj: 'Cores/Genesis-Plus-GX/PVGenesis.xcodeproj' },
  'mupen64plus' => {
    frameworks: %w[PVMupen64Plus.framework PVMupen64PlusBridge.framework PVMupen64PlusRspHLE.framework
                   PVMupen64PlusVideoRice.framework PVMupen64PlusVideoGlideN64.framework PVRSPCXD4.framework],
    package: 'Cores/Mupen64Plus',
    products: %w[PVMupenGameCore-Dynamic PVMupen64PlusRspHLE-Dynamic PVRSPCXD4-Dynamic
                 PVMupen64PlusVideoRice-Dynamic PVMupen64PlusVideoGlideN64-Dynamic],
    xcodeproj: 'Cores/Mupen64Plus/PVMupen64Plus.xcodeproj'
  }
}.freeze

core_name = ARGV.find { |a| !a.start_with?('--') }
abort "usage: #{$PROGRAM_NAME} <#{CORES.keys.join('|')}> [--apply|--verify]" unless CORES.key?(core_name)
CORE = CORES.fetch(core_name)
ROOT = ENV.fetch('PROJECT_DIR', File.expand_path('../..', __dir__))
PBXPROJ = 'Provenance.xcodeproj/project.pbxproj'
WORKSPACE = 'Provenance.xcworkspace/contents.xcworkspacedata'

def uuid(*parts)
  'C0C0CAFE' + Digest::SHA1.hexdigest(parts.join('|'))[0, 16].upcase
end

# Old framework build files / file refs per the read-only gem model.
def old_refs(project)
  refs = project.objects.select { |o| o.isa == 'PBXFileReference' && CORE[:frameworks].include?(File.basename(o.path.to_s)) }
  ref_ids = refs.map(&:uuid).to_set
  build_files = project.objects.select { |o| o.isa == 'PBXBuildFile' && o.file_ref && ref_ids.include?(o.file_ref.uuid) }
  [refs, build_files]
end

def embed_phase(target)
  target.copy_files_build_phases.find { |p| p.dst_subfolder_spec == '10' && p.name.to_s.include?('Embed Frameworks') } ||
    target.copy_files_build_phases.find { |p| p.dst_subfolder_spec == '10' }
end

def verify(project_dir)
  project = Xcodeproj::Project.open(File.join(project_dir, 'Provenance.xcodeproj'))
  problems = []
  refs, build_files = old_refs(project)
  problems << "old file refs: #{refs.map(&:path).join(', ')}" unless refs.empty?
  problems << "old build files: #{build_files.size}" unless build_files.empty?
  TARGETS.each do |name|
    target = project.native_targets.find { |t| t.name == name } or (problems << "missing target #{name}"; next)
    have = target.package_product_dependencies.map(&:product_name)
    (CORE[:products] - have).each { |p| problems << "#{name}: no product #{p}" }
    linked = target.frameworks_build_phase.files.map { |f| f.product_ref&.product_name }.compact
    embedded = embed_phase(target)&.files&.map { |f| f.product_ref&.product_name }&.compact || []
    (CORE[:products] - linked).each { |p| problems << "#{name}: #{p} not linked" }
    (CORE[:products] - embedded).each { |p| problems << "#{name}: #{p} not embedded" }
  end
  ws = File.read(File.join(project_dir, WORKSPACE))
  problems << "workspace still lists #{CORE[:xcodeproj]}" if ws.include?(CORE[:xcodeproj])
  problems
end

def insert_list_line(text, owner_uuid, list_key, line)
  # Inserts `line` into the `list_key = ( ... );` list of the object owner_uuid, unless present.
  start = text.index(/^\t\t#{owner_uuid}(?: \/\*.*?\*\/)? = \{/) or raise "object #{owner_uuid} not found"
  stop = text.index(/^\t\t\};$/, start)
  body = text[start..stop]
  return text if body.include?(line.strip)

  if (m = body.match(/^(\t+)#{Regexp.escape(list_key)} = \(\n/))
    pos = start + m.end(0)
    text.insert(pos, "#{m[1]}\t#{line.strip}\n")
  else
    # list absent (e.g. a target without packageProductDependencies): add it before `name = `
    indent = body[/^(\t+)name = /, 1] or raise "cannot place #{list_key} in #{owner_uuid}"
    pos = start + body.index(/^\t+name = /)
    text.insert(pos, "#{indent}#{list_key} = (\n#{indent}\t#{line.strip}\n#{indent});\n")
  end
  text
end

def insert_object(text, section, definition)
  return text if text.include?(definition.lines.first.strip)

  marker = "/* End #{section} section */"
  if text.include?(marker)
    text.sub(marker) { "#{definition}#{marker}" }
  else
    text.sub("/* End PBXVariantGroup section */") { |m| "#{m}\n\n/* Begin #{section} section */\n#{definition}/* End #{section} section */" }
  end
end

def delete_objects_and_lines(text, ids)
  ids.each do |id|
    text = text.gsub(/^\t\t#{id}(?: \/\*.*?\*\/)? = \{[^\n]*\};\n/, '') # one-line objects
    text = text.gsub(/^\t\t#{id}(?: \/\*.*?\*\/)? = \{\n.*?^\t\t\};\n/m, '') # multi-line objects
    text = text.gsub(/^\s*#{id}(?: \/\*.*?\*\/)?,\n/, '') # list entries
  end
  text
end

def swap(project_dir)
  project = Xcodeproj::Project.open(File.join(project_dir, 'Provenance.xcodeproj'))
  path = File.join(project_dir, PBXPROJ)
  text = File.read(path)

  refs, build_files = old_refs(project)
  text = delete_objects_and_lines(text, (build_files + refs).map(&:uuid))

  pkg = uuid('pkg', CORE[:package])
  pkg_comment = %(XCLocalSwiftPackageReference "#{CORE[:package]}")
  text = insert_object(text, 'XCLocalSwiftPackageReference',
                       "\t\t#{pkg} /* #{pkg_comment} */ = {\n\t\t\tisa = XCLocalSwiftPackageReference;\n" \
                       "\t\t\trelativePath = #{CORE[:package]};\n\t\t};\n")
  text = insert_list_line(text, project.root_object.uuid, 'packageReferences', "#{pkg} /* #{pkg_comment} */,")

  TARGETS.each do |name|
    target = project.native_targets.find { |t| t.name == name } or raise "target #{name} not found"
    embed = embed_phase(target) or raise "#{name} has no Embed Frameworks phase"
    CORE[:products].each do |product|
      dep = uuid('dep', name, product)
      link = uuid('link', name, product)
      emb = uuid('embed', name, product)
      text = insert_object(text, 'XCSwiftPackageProductDependency',
                           "\t\t#{dep} /* #{product} */ = {\n\t\t\tisa = XCSwiftPackageProductDependency;\n" \
                           "\t\t\tpackage = #{pkg} /* #{pkg_comment} */;\n\t\t\tproductName = \"#{product}\";\n\t\t};\n")
      text = insert_object(text, 'PBXBuildFile',
                           "\t\t#{link} /* #{product} in Frameworks */ = {isa = PBXBuildFile; productRef = #{dep} /* #{product} */; };\n")
      text = insert_object(text, 'PBXBuildFile',
                           "\t\t#{emb} /* #{product} in Embed Frameworks */ = {isa = PBXBuildFile; productRef = #{dep} /* #{product} */; " \
                           "settings = {ATTRIBUTES = (CodeSignOnCopy, ); }; };\n")
      text = insert_list_line(text, target.uuid, 'packageProductDependencies', "#{dep} /* #{product} */,")
      text = insert_list_line(text, target.frameworks_build_phase.uuid, 'files', "#{link} /* #{product} in Frameworks */,")
      text = insert_list_line(text, embed.uuid, 'files', "#{emb} /* #{product} in Embed Frameworks */,")
    end
  end
  File.write(path, text)

  ws_path = File.join(project_dir, WORKSPACE)
  ws = File.read(ws_path)
  ws = ws.gsub(%r{\s*<FileRef\s+location = "group:#{Regexp.escape(CORE[:xcodeproj])}">\s*</FileRef>}m, '')
  File.write(ws_path, ws)
end

if ARGV.include?('--verify')
  problems = verify(ROOT)
  problems.each { |p| warn p }
  exit(problems.empty? ? 0 : 1)
elsif ARGV.include?('--apply')
  swap(ROOT)
  out, status = Open3.capture2e('plutil', '-lint', File.join(ROOT, PBXPROJ))
  abort out unless status.success?
  puts "swapped #{core_name}; run with --verify"
else
  Dir.mktmpdir do |tmp|
    FileUtils.cp_r(File.join(ROOT, 'Provenance.xcodeproj'), tmp)
    FileUtils.mkdir_p(File.join(tmp, 'Provenance.xcworkspace'))
    FileUtils.cp(File.join(ROOT, WORKSPACE), File.join(tmp, WORKSPACE))
    swap(tmp)
    system('git', 'diff', '--no-index', '--stat', File.join(ROOT, PBXPROJ), File.join(tmp, PBXPROJ))
    system('git', 'diff', '--no-index', File.join(ROOT, WORKSPACE), File.join(tmp, WORKSPACE))
  end
end
```

Notes for the implementer:
- Before the first run, check one target's embed phase in the pbxproj: if the "Embed Frameworks" phase name differs (e.g. `Embed Frameworks` vs `Embed Libraries`), `embed_phase` falls back to the first `dstSubfolderSpec = 10` phase; confirm by eye that it is the phase holding `PVStella-Dynamic in Embed Frameworks`.
- The gem's `dst_subfolder_spec` is a String (`'10'`). If your gem returns an Integer, compare with `.to_s`.
- `delete_objects_and_lines` removes the old `PBXFileReference`s too. If a reference also sits in a `PBXGroup` children list, the list-entry regex removes that line as well.

- [ ] **Step 4: Run the test to verify it passes**

Run: `python3 -m unittest Scripts/tests/test_swap_core_to_package.py -v`
Expected: 3 tests PASS. If `test_snes9x_swap` fails on the first `--verify` returning 0, the old-reference lookup is wrong; print `old_refs` and fix before continuing.

- [ ] **Step 5: Register the scripts**

In `Scripts/maint/jobs.toml`, under `[ignore].paths` in the "Developer one-offs that need hand-picked arguments." group, add:

```toml
  "Scripts/dev/swap_core_to_package.rb",
```

and under the group whose scripts "run directly" (next to `Scripts/cores/tests/test_build_slice.py`), add:

```toml
  "Scripts/tests/test_ci_core_manifest.py",
  "Scripts/tests/test_core_package_modules.py",
  "Scripts/tests/test_swap_core_to_package.py",
```

Run: `python3 Scripts/maint/maint.py status | grep -i unregistered`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add Scripts/dev/swap_core_to_package.rb Scripts/tests/test_swap_core_to_package.py Scripts/maint/jobs.toml
git commit -m "feat(dev): script to swap a shipping core to its SwiftPM package"
```

---

### Task 3: Swap snes9x

**Files:**
- Modify: `Provenance.xcodeproj/project.pbxproj`, `Provenance.xcworkspace/contents.xcworkspacedata`, `Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved`

**Interfaces:**
- Consumes: `swap_core_to_package.rb snes9x`, `ci-core-manifest.py --identifiers`, `build/core-baseline/baseline.txt`.

- [ ] **Step 1: Confirm the gate fails today**

Run: `ruby Scripts/dev/swap_core_to_package.rb snes9x --verify`
Expected: exit 1, listing `old file refs: PVSNES.framework, snes9x.framework` and missing products.

- [ ] **Step 2: Dry run, then apply**

```bash
ruby Scripts/dev/swap_core_to_package.rb snes9x | tail -20
ruby Scripts/dev/swap_core_to_package.rb snes9x --apply
ruby Scripts/dev/swap_core_to_package.rb snes9x --verify
python3 Scripts/audits/check_pbxproj_sources.py
```

Expected: `--verify` exits 0; the audit prints no new findings.

- [ ] **Step 3: Resolve packages and check pins**

```bash
xcodebuild -resolvePackageDependencies -workspace Provenance.xcworkspace -scheme "Provenance (AppStore)" -skipPackagePluginValidation -skipMacroValidation | tail -5
git diff --stat Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved
grep -c '"version" : 3' Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved
grep -c '"identity" : "ziparchive"' Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved
git diff Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved | grep -E '^[-+] *"(identity|version)"'
```

Expected: both counts print `1`. The diff shows only pins snes9x's `Package.swift` adds (if any), no version changes to existing pins. Any other bump: `git checkout` the file and pin the offending dependency in the core's `Package.swift` instead.

- [ ] **Step 4: Commit on a branch (do not push yet)**

```bash
git switch -c feature/ship-core-packages
git add Provenance.xcodeproj/project.pbxproj Provenance.xcworkspace/contents.xcworkspacedata Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "build: ship snes9x from its SwiftPM package"
```

The four swaps are four local commits and one CI run (Task 6 Step 5): a `build.yml` archive takes hours, so one push per core would cost four of them. If the batched gate fails, bisect by commit.

---

### Task 4: Swap FCEU

**Files:** same three as Task 3.

- [ ] **Step 1:** `ruby Scripts/dev/swap_core_to_package.rb fceu --verify` → expect exit 1 with `old file refs: PVFCEU.framework`.
- [ ] **Step 2:** `ruby Scripts/dev/swap_core_to_package.rb fceu --apply && ruby Scripts/dev/swap_core_to_package.rb fceu --verify && python3 Scripts/audits/check_pbxproj_sources.py` → `--verify` exits 0.
- [ ] **Step 3:** Run Task 3 Step 3's resolve and pin checks verbatim; expected the same (`1`, `1`, no bumps of existing pins).
- [ ] **Step 4:** Commit locally (no push):

```bash
git add Provenance.xcodeproj/project.pbxproj Provenance.xcworkspace/contents.xcworkspacedata Provenance.xcworkspace/xcshareddata/swiftpm/Package.resolved
git commit -m "build: ship FCEU from its SwiftPM package"
```

---

### Task 5: Swap Genesis-Plus-GX

**Files:** same three as Task 3.

- [ ] **Step 1:** `ruby Scripts/dev/swap_core_to_package.rb genesis --verify` → exit 1 with `old file refs: PVGenesis.framework`.
- [ ] **Step 2:** `ruby Scripts/dev/swap_core_to_package.rb genesis --apply && ruby Scripts/dev/swap_core_to_package.rb genesis --verify && python3 Scripts/audits/check_pbxproj_sources.py` → exit 0.
- [ ] **Step 3:** Task 3 Step 3's resolve and pin checks. Genesis declares `SwiftGenPlugin` (`from: "1.1.3"`) without applying it to any target; it is already pinned in the workspace, so expect no new pin. If the plugin's presence makes resolution fail validation, delete that unused dependency line from `Cores/Genesis-Plus-GX/Package.swift` in this commit.
- [ ] **Step 4:** Commit `build: ship Genesis-Plus-GX from its SwiftPM package` with the same three files (plus `Cores/Genesis-Plus-GX/Package.swift` if Step 3 touched it), locally, no push.

---

### Task 6: Swap Mupen64Plus (core + four plugins)

**Files:** same three as Task 3.

**Interfaces:**
- Consumes: package resources from `38cebb9af3` (`GLideN64.ini`, `GLideN64.custom.ini`, `RiceVideoLinux.ini`, `mupen64plus.ini`, `mupencheat.txt` in `PVMupenGameCore_PVMupen64Plus.bundle`) and module name `PVMupen64Plus` from `d19b00d5bd`.

- [ ] **Step 1:** `ruby Scripts/dev/swap_core_to_package.rb mupen64plus --verify` → exit 1 listing all six old frameworks.
- [ ] **Step 2:** `ruby Scripts/dev/swap_core_to_package.rb mupen64plus --apply && ruby Scripts/dev/swap_core_to_package.rb mupen64plus --verify && python3 Scripts/audits/check_pbxproj_sources.py` → exit 0 (the verify checks all five products are linked and embedded in all four targets).
- [ ] **Step 3:** Task 3 Step 3's resolve and pin checks. Mupen depends on `Defaults` directly (`Package.swift`, "imported directly"); it is already pinned, so expect no bump.
- [ ] **Step 4:** Commit `build: ship Mupen64Plus and its plugins from SwiftPM packages` (same three files), locally.
- [ ] **Step 5: Push once, open the PR, run every gate**

```bash
git pull --rebase origin develop
git push -u origin feature/ship-core-packages
gh pr create --repo Provenance-Emu/Provenance --base develop --title "build: ship native cores from their SwiftPM packages" --body "Plan: docs/superpowers/plans/2026-10-12-shipping-core-package-swap.md"
```

The auto-rebase bot rewrites this branch whenever develop moves, and a bot rebase does not re-run `build.yml`. Before every later push, `git pull --rebase` first. Before downloading IPAs, confirm the run built the commit you think it did:

```bash
gh run list --repo Provenance-Emu/Provenance --workflow "Build and Upload Provenance" --branch feature/ship-core-packages --limit 3 --json databaseId,status,conclusion,headSha
git log --oneline -5 origin/feature/ship-core-packages
```

Wait for the `Provenance (AppStore) (Release)` archives (`iphoneos`, `appletvos`) to be green on a head that contains all four swap commits. A failure log is in artifact `xcodebuild-log-<IPA_NAME>` (`gh run download <run-id> -n xcodebuild-log-Provenance-iOS`); xcbeautify hides script output in the console.

Identifier gate (all four cores at once):

```bash
mkdir -p build/core-after && cd build/core-after && rm -rf ./*
gh run download <run-id> --repo Provenance-Emu/Provenance --pattern '*ipa*'
find . -name '*.ipa' -exec python3 ../../Scripts/ci/ci-core-manifest.py --identifiers {} + | sort > after.txt
cut -f2 ../core-baseline/baseline.txt | sort | uniq -c > /tmp/base-ids
cut -f2 after.txt | sort | uniq -c > /tmp/after-ids
diff /tmp/base-ids /tmp/after-ids && echo "identifiers unchanged"
cd ../..
```

Expected: `identifiers unchanged`. Name the IPA artifacts from `gh run view <run-id>` if the pattern matches nothing.

Per-core contents of the iOS IPA (repeat with the tvOS IPA):

```bash
IPA="$(find build/core-after -name '*iOS*.ipa' | head -1)"
for p in PVSNES9x PVFCEU PVCoreGenesisPlus PVMupenGameCore PVMupen64PlusRspHLE PVRSPCXD4 PVMupen64PlusVideoRice PVMupen64PlusVideoGlideN64; do
  unzip -l "$IPA" | grep -qE "Frameworks/$p-Dynamic.framework/$p-Dynamic\$" && echo "ok $p" || echo "MISSING $p"
done
unzip -l "$IPA" | grep -cE '_(PVSNES|PVFCEU|PVGenesis|PVMupen64Plus)\.bundle/Core\.plist$'
unzip -l "$IPA" | grep -cE 'Frameworks/(PVSNES|snes9x|PVFCEU|PVGenesis|PVMupen64Plus|PVMupen64PlusBridge|PVMupen64PlusRspHLE|PVMupen64PlusVideoRice|PVMupen64PlusVideoGlideN64|PVRSPCXD4)\.framework/'
```

Expected: eight `ok` lines, `4`, `0`.

Mupen helper files must be real files, not copied symlinks (a dangling link still lists in `unzip -l` and the build still passes):

```bash
zipinfo "$IPA" | grep 'PVMupenGameCore_PVMupen64Plus.bundle/' | grep -E '(GLideN64|GLideN64\.custom|RiceVideoLinux|mupen64plus)\.ini$|mupencheat\.txt$'
```

Expected: five lines, each starting with `-` (regular file), none with `l`. A missing or `l` entry means the symlinks under `Cores/Mupen64Plus/Sources/PVMupen/Resources/` were not resolved: check `Scripts/ci/ci-init-submodules.sh` initializes Mupen's plugin submodules, and replace the symlinks with a Run Script copy if Xcode copied links verbatim.

What this gate does not cover: `build.yml` archives only `Provenance (AppStore)`. For `Provenance`, `Provenance-XL` and `Provenance-Lite (AppStore)` the evidence is the script's `--verify` (product linked + embedded, no old references). Ask the user for one local build of the `Provenance` scheme (device or Apple Silicon simulator) before merging.

---

### Task 7: Azahar and Dolphin — record the decision

These are a decision for the user, not a task list, because their binary targets are build artefacts that SwiftPM needs at package-resolution time.

**Files:**
- Create: `docs/superpowers/specs/2026-10-12-azahar-dolphin-package-decision.md`

No probe: a scratch worktree has no submodules, so package resolution would fail on missing target paths before it reached the xcframework question, and Dolphin's missing simulator slice already decides option 1 for now.

- [ ] **Step 1: Write the decision doc**

Use this content:


```markdown
# Azahar and Dolphin: ship from packages or keep the xcodeprojs (2026-10-12)

## Facts
- Both packages use a `.binaryTarget` over `build/xcframework/PVlib<Core>.xcframework`, produced by
  `Scripts/cores/build_slice.py <core> <slice> --xcframework`. Xcode loads package manifests when it
  resolves the workspace, before any target (including the BuildPVlibAzahar / Make XCFrameworks
  aggregates) runs, so the xcframework must exist before `xcodebuild` starts, for every scheme.
- Dolphin's binaryTarget is unconditional; Azahar's is added only when the xcframework exists.
- Dolphin has no simulator slice, and a package product dependency cannot be filtered by simulator vs
  device, so local simulator runs of Provenance/AppStore/XL would stop linking.
- Today's xcodeprojs link the per-slice archive by path and build it in an aggregate target, which
  works on a cold checkout; that was the fix for "There is no XCFramework found".

## Options
1. Keep both on their xcodeprojs (recommended for now). Nothing changes for release.sh, build.yml,
   testflight.yml, `make lite` or a fresh clone opened in Xcode.
2. Move both: run `build_slice.py <core> <slice> --xcframework` for ios and tvos (and both simulator
   slices for Azahar) before every xcodebuild entry point: release.sh, build.yml, testflight.yml,
   `make lite`, and document it for local Xcode use; add Dolphin simulator slices or accept no
   simulator runs; add the `nm -m <fw> | grep 'weak external'` audit (CLAUDE.md, Azahar gotchas) to
   the gate because the unexported-symbols lists move into Package.swift; and add a Run Script to
   every Dolphin-linking app target that copies `Cores/Dolphin/dolphin-ios/Data/Sys` into the app
   bundle (the xcodeproj bundles it today; a package cannot reference it; the dev app's
   `DevSettings.dolphinSysScript` is the model). Dolphin's `Config/` is already a package resource.
3. Move Azahar only (simulator slices exist; binaryTarget is optional), keep Dolphin.

## Decision
<user's choice and date>
```

- [ ] **Step 2: Ask the user to choose; record it in the doc; commit**

```bash
git add docs/superpowers/specs/2026-10-12-azahar-dolphin-package-decision.md
git commit -m "docs(spec): record the Azahar/Dolphin package decision"
git push
```

If the user picks option 2 or 3, that becomes its own plan; this plan ends at the record.

---

### Task 8: Device pass, merge, then cleanup

- [ ] **Step 1: Merge the PR after the user's device checks**

The user runs `docs/RELEASE_SMOKE_TESTS.md` "Dev workspace (not release-gated)" items on the PR's alpha IPA (snes9x, FCEU, Genesis, N64 with GlideN64 and Rice, both RSP plugins, Apple TV). Merge only when the user confirms:

```bash
gh pr merge <pr> --repo Provenance-Emu/Provenance --squash --delete-branch=false
```

- [ ] **Step 2: After one TestFlight build passes on devices, delete the swapped xcodeprojs**

```bash
git switch develop && git pull --rebase
git rm -r Cores/snes9x/PVSNES9x.xcodeproj Cores/FCEU/PVFCEU.xcodeproj Cores/Genesis-Plus-GX/PVGenesis.xcodeproj Cores/Mupen64Plus/PVMupen64Plus.xcodeproj
git grep -n -E 'PVSNES9x\.xcodeproj|PVFCEU\.xcodeproj|PVGenesis\.xcodeproj|PVMupen64Plus\.xcodeproj' -- . ':!docs/superpowers/plans' ':!docs/superpowers/specs'
```

Expected: the grep prints only references that must be updated in this commit: `Scripts/audits/pbxproj_sources_allowlist.txt` entries, `Cores/Mupen64Plus/project.yml`-style generator inputs if present, `CLAUDE.md` lines. Remove or reword each. Leave `Cores/*/Config.xcconfig`/`BuildConfig.xcconfig` only if `Package.swift` or Tuist still reads them (`git grep -n 'Config.xcconfig' Cores/<core> Tuist`); otherwise delete them too. Keep `Cores/Debug` (other cores still use `PVDebug.c`).

- [ ] **Step 3: Update docs**
  - `docs/superpowers/specs/2026-10-11-core-spm-conversion.md`: replace the stale "Where we are" table with: all six cores `.package` in the dev workspace; snes9x, FCEU, Genesis, Mupen64Plus `.package` in `Provenance.xcodeproj`; Azahar/Dolphin per Task 7's decision.
  - `CLAUDE.md` "Core taxonomy": note that the four cores ship from their packages and their xcodeprojs are gone.
  - `docs/RELEASE_SMOKE_TESTS.md`: move the passed dev-workspace items to "Verified" with the build number.

- [ ] **Step 4: Run the checks and commit**

```bash
python3 Scripts/audits/check_pbxproj_sources.py
python3 -m unittest discover -s Scripts/tests -v
python3 Scripts/maint/maint.py status | grep -i unregistered
git add -A Cores/snes9x Cores/FCEU Cores/Genesis-Plus-GX Cores/Mupen64Plus Scripts/audits docs CLAUDE.md
git commit -m "chore(cores): delete xcodeprojs replaced by SwiftPM packages"
git push
```

Expected: audit clean, tests pass, nothing unregistered; the next `build.yml` run on develop is green on iOS and tvOS.

Rollback before Step 2: `git revert` the swap commit(s); the xcodeprojs are still there. After Step 2, revert the cleanup commit first.
