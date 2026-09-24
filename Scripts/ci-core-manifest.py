#!/usr/bin/env python3
"""Generate a markdown manifest of the emulator cores embedded in built IPAs.

Attached to the alpha release so a missing or suspiciously small core is visible
without unzipping anything: a core that failed to build usually still ships a
framework directory, so size is the tell.

Two kinds of cores end up in `<App>.app/Frameworks`:

* native cores — a `PV<Name>.framework` carrying a `Core.plist`, which is exactly
  what `PVCoreLoader` scans at runtime to discover cores.
* libretro cores — `<name>.libretro.framework`, wrapping a buildbot dylib. These
  are registered in PVRetroArch's own Core.plist rather than carrying their own,
  so they are matched by name against `CoresRetro/RetroArch/Scripts/cores.yml`
  to report which expected cores are missing from the build.

Everything else in Frameworks (PVLibrary, SwiftUI runtimes, …) is support code and
is summarised as a single total rather than listed.

Usage:
    ci-core-manifest.py --out core-manifest.md [--cores-yml PATH] IPA [IPA ...]
"""

from __future__ import annotations

import argparse
import plistlib
import posixpath
import re
import sys
import zipfile
from dataclasses import dataclass, field


#: Keep the release notes readable when a whole platform fails to package.
MAX_MISSING_LISTED = 25


@dataclass
class Framework:
    name: str
    size: int = 0
    core_plist: dict | None = None

    @property
    def is_libretro(self) -> bool:
        return self.name.endswith(".libretro")

    @property
    def is_native_core(self) -> bool:
        return self.core_plist is not None


@dataclass
class IPAReport:
    ipa: str
    app: str = ""
    total_size: int = 0
    frameworks: list[Framework] = field(default_factory=list)
    error: str = ""


def human(size: int) -> str:
    """Render a byte count the way a release reader wants to scan it."""
    for unit, cutoff in (("GB", 1 << 30), ("MB", 1 << 20), ("KB", 1 << 10)):
        if size >= cutoff:
            return f"{size / cutoff:.1f} {unit}"
    return f"{size} B"


def read_ipa(path: str) -> IPAReport:
    report = IPAReport(ipa=posixpath.basename(path))
    try:
        zf = zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as exc:
        report.error = f"could not read IPA: {exc}"
        return report

    with zf:
        frameworks: dict[str, Framework] = {}
        app_prefix = ""
        for info in zf.infolist():
            name = info.filename
            if not app_prefix:
                match = re.match(r"(Payload/[^/]+\.app)/", name)
                if match:
                    app_prefix = match.group(1)
                    report.app = posixpath.basename(app_prefix)
            report.total_size += info.file_size

            match = re.search(r"/Frameworks/([^/]+)\.framework/(.*)$", name)
            if not match:
                continue
            fw_name, rest = match.group(1), match.group(2)
            fw = frameworks.setdefault(fw_name, Framework(name=fw_name))
            fw.size += info.file_size
            # Only a Core.plist at the framework root marks a core; nested copies
            # inside resource bundles would double count.
            if rest == "Core.plist":
                try:
                    fw.core_plist = plistlib.loads(zf.read(name))
                except Exception as exc:  # malformed plist shouldn't kill the run
                    print(f"::warning::{report.ipa}: unreadable Core.plist in "
                          f"{fw_name}.framework: {exc}", file=sys.stderr)

        report.frameworks = sorted(frameworks.values(), key=lambda f: -f.size)
    if not report.frameworks and not report.error:
        report.error = "no frameworks found — is this a valid IPA?"
    return report


def expected_libretro_cores(cores_yml: str, platform: str) -> set[str]:
    """Core names cores.yml says this platform should ship.

    Hand-parsed rather than via PyYAML: the runner has no third-party modules and
    the file is a flat list of `- name:` blocks with boolean flags.
    """
    try:
        text = open(cores_yml).read()
    except OSError:
        return set()

    expected: set[str] = set()
    name = None
    flags: dict[str, bool] = {}

    def flush() -> None:
        if name and flags.get("enabled", True) and flags.get(platform, False):
            expected.add(name)

    for line in text.splitlines():
        entry = re.match(r"\s*-\s+name:\s*(\S+)", line)
        if entry:
            flush()
            name, flags = entry.group(1).strip('"\''), {}
            continue
        flag = re.match(r"\s+(ios|tvos|enabled|appstore):\s*(true|false)", line)
        if flag and name:
            flags[flag.group(1)] = flag.group(2) == "true"
    flush()
    return expected


def canonical(name: str) -> str:
    """Compare core names across the two spellings in play.

    cores.yml writes `mednafen_psx_hw` while the bundled framework is
    `mednafen.psx.hw.libretro`, and a few names carry dashes, so separators
    cannot be compared literally. Distinct cores stay distinct: `mednafen_psx`
    and `mednafen_psx_hw` still differ once separators are dropped.
    """
    return re.sub(r"[._-]", "", name.lower())


def platform_for(ipa_name: str) -> str:
    return "tvos" if "tvos" in ipa_name.lower() else "ios"


def render(reports: list[IPAReport], cores_yml: str) -> str:
    out: list[str] = ["# Embedded core manifest", ""]
    out.append("Cores found inside each built IPA, with their installed size. "
               "A core that failed to build usually still ships a framework, so a "
               "size far below its siblings is the signal to look for.")
    out.append("")

    for report in reports:
        out.append(f"## {report.ipa}")
        out.append("")
        if report.error:
            out.append(f"> **Could not inspect this IPA:** {report.error}")
            out.append("")
            continue

        native = [f for f in report.frameworks if f.is_native_core]
        libretro = [f for f in report.frameworks if f.is_libretro]
        support = [f for f in report.frameworks
                   if not f.is_native_core and not f.is_libretro]

        out.append(f"| | |\n|---|---|")
        out.append(f"| **App** | `{report.app or 'unknown'}` |")
        out.append(f"| **Uncompressed size** | {human(report.total_size)} |")
        out.append(f"| **Native cores** | {len(native)} |")
        out.append(f"| **libretro cores** | {len(libretro)} |")
        out.append(f"| **Support frameworks** | {len(support)}"
                   f" ({human(sum(f.size for f in support))}) |")
        out.append("")

        if native:
            out.append("### Native cores")
            out.append("")
            out.append("| Core | Size | Systems | Version |")
            out.append("|---|---:|---|---|")
            for fw in sorted(native, key=lambda f: f.name.lower()):
                plist = fw.core_plist or {}
                systems = ", ".join(
                    s.replace("com.provenance.", "")
                    for s in plist.get("PVSupportedSystems", []) or []
                ) or "—"
                disabled = " _(disabled)_" if plist.get("PVDisabled") else ""
                name = plist.get("PVProjectName") or fw.name
                version = plist.get("PVProjectVersion") or "—"
                out.append(f"| {name}{disabled} | {human(fw.size)} | {systems} | {version} |")
            out.append("")

        if libretro:
            out.append("### libretro cores")
            out.append("")
            out.append("| Core | Size |")
            out.append("|---|---:|")
            for fw in sorted(libretro, key=lambda f: f.name.lower()):
                out.append(f"| {fw.name.removesuffix('.libretro')} | {human(fw.size)} |")
            out.append("")

            platform = platform_for(report.ipa)
            expected = expected_libretro_cores(cores_yml, platform)
            if expected:
                present = {canonical(fw.name.removesuffix(".libretro"))
                           for fw in libretro}
                missing = sorted(name for name in expected
                                 if canonical(name) not in present)
                out.append(f"**Expected for {platform} per `cores.yml`** (sideload "
                           f"variant, App Store builds ship fewer)**:** {len(expected)}"
                           f" — **present:** {len(expected) - len(missing)}")
                out.append("")
                if missing:
                    shown = ", ".join(f"`{m}`" for m in missing[:MAX_MISSING_LISTED])
                    if len(missing) > MAX_MISSING_LISTED:
                        shown += f" … and {len(missing) - MAX_MISSING_LISTED} more"
                    out.append(f"> **Missing from this build ({len(missing)}):** {shown}")
                    out.append("")

    return "\n".join(out).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipas", nargs="+")
    parser.add_argument("--out", required=True)
    parser.add_argument("--cores-yml",
                        default="CoresRetro/RetroArch/Scripts/cores.yml")
    args = parser.parse_args()

    reports = [read_ipa(p) for p in args.ipas]
    with open(args.out, "w") as handle:
        handle.write(render(reports, args.cores_yml))
    print(f"Wrote {args.out} for {len(reports)} IPA(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
