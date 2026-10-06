#!/usr/bin/env python3
"""
audit_controls.py — produce a system × button × controller-class matrix from every
GameController-binding bridge file in the workspace.

Scope:
  • Native cores:        Cores/*/Sources/**/*Bridge*.{m,mm} (and the per-core
                         Cores/*/PV*Core/ layouts listed in NATIVE_BRIDGE_GLOBS)
  • Thin libretro:       not scanned. It is Swift
                         (PVCoreBridgeRetro/Sources/PVLibRetro/PVThinLibretroCore+Controls.swift)
                         and has no per-controller GC binding of the kind scanned here.

The script greps each file for `case PV<System>Button<Name>:` blocks under one of
three controller-class regions:
    [controller extendedGamepad]   →  "extended"
    [controller gamepad]           →  "basic"
    [controller microGamepad]      →  "micro"

Each case captures a short token describing the mapped GameController source
(e.g. `buttonA`, `rightTrigger`, `leftThumbstick.up`, `dpad.right`). Cases inside
`#if TARGET_OS_TV` get a `(tvOS)` suffix; `#if !TARGET_OS_TV` → `(iOS)`.

A button defined in the `PV<System>Button` enum but with no `case` in a given
controller class is reported as `MISSING` so missing Start/Mode/Select gaps light up.

**Libretro-ID switch support**: bridges that switch on `RETRO_DEVICE_ID_JOYPAD_*`
constants (e.g. `Cores/PicoDrive/Sources/PVPicoDriveBridge/PVPicoDriveBridge.m`)
are translated back to `PV<Sys>Button<Name>` rows by parsing any
`static const int <Name>LibretroMap[]` table in the same file. PicoDrive needs
this because its `_pad[]` is indexed by libretro ID and the `PVSega32XButton`
enum ordinals do not match the libretro IDs — see `Sega32XLibretroMap` in that
file. A bridge that uses libretro-ID switches without a map table cannot be
attributed and will be silently skipped.

Output: docs/controller-mapping-audit.md (markdown report).

Usage:  python3 Scripts/audits/audit_controls.py
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]

# --- Sources to scan -------------------------------------------------------

NATIVE_BRIDGE_GLOBS = [
    "Cores/*/Sources/*/PV*Bridge*.m",
    "Cores/*/Sources/*/PV*Bridge*.mm",
    "Cores/*/PV*Core/Core/*Bridge*.m",
    "Cores/*/PV*Core/Core/*Bridge*.mm",
    "Cores/*/PV*Core/*Bridge*.m",
    "Cores/*/PV*Core/*Bridge*.mm",
    "Cores/*/PV*Core/Source/*Bridge*.mm",
    "Cores/*/PV*Core/Source/*Bridge*.m",
]

# Heading of the report section listing the scanned bridges.
SECTION_LABEL = "Native PV core bridges"

# --- Button enum discovery -------------------------------------------------

# Detects:  case PVN64ButtonA, case PVSega32XButtonStart …
BUTTON_ENUM_RE = re.compile(r"\bcase PV(?P<sys>[A-Za-z0-9_]+?)Button(?P<btn>[A-Za-z0-9_]+)\b")


def _all_buttons_in_file(text: str) -> dict[str, set[str]]:
    """Returns {system: {button_names}} discovered as cases in `text`."""
    out: dict[str, set[str]] = defaultdict(set)
    for m in BUTTON_ENUM_RE.finditer(text):
        sys_name = m.group("sys")
        btn = m.group("btn")
        if btn.lower() == "count":
            continue  # the trailing sentinel
        out[sys_name].add(btn)
    return out


# --- Controller-class block detection --------------------------------------

# `if ([controller extendedGamepad])`, `else if ([controller gamepad])`, `else if ([controller microGamepad])`
CTRL_BLOCK_RE = re.compile(
    r"\[\s*controller\s+(?P<klass>extendedGamepad|gamepad|microGamepad)\s*\]"
)
CTRL_KLASS_LABEL = {
    "extendedGamepad": "extended",
    "gamepad":         "basic",
    "microGamepad":    "micro",
}


def _slice_blocks(text: str) -> list[tuple[str, int, int]]:
    """
    Splits a file into (controller_class, start_index, end_index) regions by
    walking from each `[controller X]` token and balancing braces. The first
    `{` after the token is the start; we walk to its matching `}`.
    """
    blocks: list[tuple[str, int, int]] = []
    for m in CTRL_BLOCK_RE.finditer(text):
        klass = CTRL_KLASS_LABEL[m.group("klass")]
        i = text.find("{", m.end())
        if i < 0:
            continue
        depth = 0
        j = i
        while j < len(text):
            c = text[j]
            if c == "{":
                depth += 1
            elif c == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        if depth == 0:
            blocks.append((klass, i, j))

    return blocks


# --- GC mapping extraction -------------------------------------------------

# Strip [[…] isPressed] / [[…] value] / `> 0.x` etc. — we want the source token.
GC_TOKENS = [
    # leftThumbstick.up / .down / .left / .right
    (re.compile(r"\[\s*\[\s*(?:gamepad|controller)\s+(?:leftThumbstick|rightThumbstick)\s*\]\s+(up|down|left|right)\s*\]"),
        lambda m: f"{m.string[m.start():m.end()].split(']')[0].split()[-1]}.{m.group(1)}"),
    # dpad.up etc.
    (re.compile(r"\[\s*\[\s*dpad\s+(up|down|left|right)\s*\]"),
        lambda m: f"dpad.{m.group(1)}"),
    # buttonA / rightTrigger / leftShoulder / buttonMenu …
    # Excludes thumbsticks (handled above) so we don't double-emit `leftThumbstick`.
    (re.compile(r"\[\s*\[\s*gamepad\s+(?!leftThumbstick\b|rightThumbstick\b)(\w+)\s*\]"),
        lambda m: m.group(1)),
]

CASE_RE = re.compile(
    # Matches two forms in case labels:
    #   `case PVFooButtonX:`               — direct enum case (most native cores)
    #   `case RETRO_DEVICE_ID_JOYPAD_X:`   — libretro-ID switch (PicoDrive 32X);
    #                                        translated via per-file LibretroMap[]
    r"case\s+(?:"
    r"PV(?P<sys>[A-Za-z0-9_]+?)Button(?P<btn>[A-Za-z0-9_]+)"
    r"|"
    r"RETRO_DEVICE_ID_JOYPAD_(?P<lid>[A-Z0-9_]+)"
    r")\s*:",
)

# Parses tables of the form:
#   static const int Sega32XLibretroMap[] = {
#       [PVSega32XButtonUp] = RETRO_DEVICE_ID_JOYPAD_UP,
#       ...
#   };
# Used to translate libretro-ID `case` labels back to a `(system, button)` pair
# so PicoDrive (and any future libretro-backed bridge that adopts the same
# pattern) shows up in the audit alongside the enum-case-driven cores.
LIBRETRO_MAP_DECL_RE = re.compile(
    r"static\s+const\s+int\s+(?P<map_name>\w+LibretroMap)\s*\[\s*\]\s*=\s*\{(?P<body>.*?)\}",
    re.DOTALL,
)
LIBRETRO_MAP_ENTRY_RE = re.compile(
    r"\[\s*PV(?P<sys>[A-Za-z0-9_]+?)Button(?P<btn>[A-Za-z0-9_]+)\s*\]"
    r"\s*=\s*RETRO_DEVICE_ID_JOYPAD_(?P<lid>[A-Z0-9_]+)"
)


def _extract_libretro_maps(text: str) -> dict[str, tuple[str, str]]:
    """Returns {libretro_id_suffix: (system, button)} merged across every
    `XxxLibretroMap[]` declared in `text`. The libretro_id suffix is the part
    after `RETRO_DEVICE_ID_JOYPAD_` (e.g. ``UP``, ``B``, ``SELECT``). If the
    same libretro ID is mapped twice the last entry wins, but in practice
    these maps are bijective."""
    out: dict[str, tuple[str, str]] = {}
    for decl in LIBRETRO_MAP_DECL_RE.finditer(text):
        for entry in LIBRETRO_MAP_ENTRY_RE.finditer(decl.group("body")):
            out[entry.group("lid")] = (entry.group("sys"), entry.group("btn"))
    return out


def _next_case_or_default(text: str, after: int) -> int:
    """Returns the index of the next `case ...:` or `default:` starting from `after`."""
    n_case = CASE_RE.search(text, after)
    n_def = re.search(r"\bdefault\s*:", text[after:])
    a = n_case.start() if n_case else len(text)
    b = (after + n_def.start()) if n_def else len(text)
    return min(a, b)


_IF_TV_RE     = re.compile(r"#if\s+TARGET_OS_TV\b")
_IF_NOT_TV_RE = re.compile(r"#if\s*!\s*TARGET_OS_TV\b")
_ELSE_RE      = re.compile(r"#else\b")
_ENDIF_RE     = re.compile(r"#endif\b")


def _platform_branches(case_body: str) -> list[tuple[str, str]]:
    """
    Returns [(platform, body), …] for a case. Splits on `#if TARGET_OS_TV` / `#else`
    so a case with both branches yields two entries (one tvOS, one iOS).
    """
    has_tv = _IF_TV_RE.search(case_body)
    has_nt = _IF_NOT_TV_RE.search(case_body)

    if not has_tv and not has_nt:
        return [("both", case_body)]

    branches: list[tuple[str, str]] = []
    if has_tv:
        endif = _ENDIF_RE.search(case_body, has_tv.end())
        end_idx = endif.start() if endif else len(case_body)
        else_m  = _ELSE_RE.search(case_body, has_tv.end(), end_idx)
        if else_m:
            branches.append(("tvOS", case_body[has_tv.end():else_m.start()]))
            branches.append(("iOS",  case_body[else_m.end():end_idx]))
        else:
            branches.append(("tvOS", case_body[has_tv.end():end_idx]))
    elif has_nt:
        endif = _ENDIF_RE.search(case_body, has_nt.end())
        end_idx = endif.start() if endif else len(case_body)
        else_m  = _ELSE_RE.search(case_body, has_nt.end(), end_idx)
        if else_m:
            branches.append(("iOS",  case_body[has_nt.end():else_m.start()]))
            branches.append(("tvOS", case_body[else_m.end():end_idx]))
        else:
            branches.append(("iOS",  case_body[has_nt.end():end_idx]))

    return branches


def _extract_mapping(case_body: str) -> str:
    """
    Pull a short label for what GameController source the case maps to.
    If multiple are present (e.g. R2 ?: Menu) join them with ' || '.
    """
    hits: list[str] = []
    for rx, fmt in GC_TOKENS:
        for m in rx.finditer(case_body):
            try:
                hits.append(fmt(m))
            except Exception:
                hits.append(m.group(0))
    # Dedup while preserving order.
    seen, out = set(), []
    for h in hits:
        if h not in seen:
            out.append(h); seen.add(h)
    return " || ".join(out) if out else "?"


# --- Per-file scan ---------------------------------------------------------

@dataclass
class CaseEntry:
    button: str
    klass: str         # extended / basic / micro
    platform: str      # iOS / tvOS / both
    mapping: str
    file: str
    line: int


@dataclass
class SystemReport:
    system: str
    declared_buttons: set[str] = field(default_factory=set)
    entries: list[CaseEntry] = field(default_factory=list)


def scan_file(path: Path) -> dict[str, SystemReport]:
    text = path.read_text(errors="replace")
    declared = _all_buttons_in_file(text)
    libretro_map = _extract_libretro_maps(text)

    # A bridge that only switches on libretro IDs (PicoDrive) won't have any
    # `case PV<Sys>Button<Btn>:` for `_all_buttons_in_file` to discover, so
    # seed the declared set from the libretro map declarations themselves —
    # otherwise the system never appears in the report at all.
    for _lid, (sys_name, btn) in libretro_map.items():
        if btn.lower() == "count":
            continue
        declared[sys_name].add(btn)

    out: dict[str, SystemReport] = defaultdict(lambda: SystemReport(system=""))
    for sys_name, btns in declared.items():
        out[sys_name].system = sys_name
        out[sys_name].declared_buttons.update(btns)

    for klass, start, end in _slice_blocks(text):
        body = text[start:end]
        for m in CASE_RE.finditer(body):
            if m.group("btn"):
                # `case PV<Sys>Button<Btn>:` form — system and button are right there.
                sys_name = m.group("sys")
                btn = m.group("btn")
            else:
                # `case RETRO_DEVICE_ID_JOYPAD_<X>:` form — translate via
                # the file's LibretroMap[]. If the file has no map we
                # cannot attribute this case, so skip it.
                lid = m.group("lid")
                if lid not in libretro_map:
                    continue
                sys_name, btn = libretro_map[lid]
            if btn.lower() == "count":
                continue
            case_start = m.end()
            local_end = _next_case_or_default(body, case_start)
            case_body = body[case_start:local_end]
            line_no = text.count("\n", 0, start + m.start()) + 1
            for platform, branch_body in _platform_branches(case_body):
                mapping = _extract_mapping(branch_body)
                out[sys_name].entries.append(CaseEntry(
                    button=btn,
                    klass=klass,
                    platform=platform,
                    mapping=mapping,
                    file=str(path.relative_to(REPO_ROOT)),
                    line=line_no,
                ))
            out[sys_name].system = sys_name

    return out


# --- Report ----------------------------------------------------------------

KLASS_ORDER = ["extended", "basic", "micro"]
PLAT_ORDER  = ["both", "iOS", "tvOS"]


def merge(reports: list[dict[str, SystemReport]]) -> dict[str, SystemReport]:
    out: dict[str, SystemReport] = {}
    for r in reports:
        for sys_name, sysr in r.items():
            if sys_name not in out:
                out[sys_name] = SystemReport(system=sys_name)
            out[sys_name].declared_buttons.update(sysr.declared_buttons)
            out[sys_name].entries.extend(sysr.entries)
    return out


def render(native: dict[str, SystemReport]) -> str:
    lines: list[str] = []
    lines.append("# Controller-mapping audit\n")
    lines.append(
        "Generated by `Scripts/audits/audit_controls.py`. For each system the matrix "
        "shows what GameController button (or stick axis) drives each emulator "
        "input, per controller class and platform. **MISSING** = the button "
        "exists in the system's enum but has no `case` in that controller-class "
        "block, so a player on that hardware cannot reach it.\n"
    )
    lines.append(f"\n## {SECTION_LABEL}\n")
    # Skip systems with no actual controller-class entries — these are
    # files that don't bind GameController inputs directly.
    active = {s: r for s, r in native.items() if r.entries}
    if not active:
        lines.append(
            "_No scanned file binds GameController inputs directly; GameController "
            "binding lives in the Controller VC layer "
            "(`PVUI/Sources/PVUIBase/Controller/Systems/*ControllerViewController.swift`)._\n"
        )
        return "\n".join(lines) + "\n"

    for sys_name in sorted(active.keys()):
        sysr = active[sys_name]
        lines.append(f"\n### {sys_name}\n")
        files = sorted({e.file for e in sysr.entries})
        for f in files:
            lines.append(f"- `{f}`")
        lines.append("")

        # Build a {button -> {(klass, platform): mapping}} pivot.
        pivot: dict[str, dict[tuple[str, str], str]] = defaultdict(dict)
        for e in sysr.entries:
            key = (e.klass, e.platform)
            pivot[e.button][key] = e.mapping

        # Decide which (klass, platform) columns appear in this system.
        # If a klass only has 'both' entries, drop its iOS/tvOS columns so the
        # table doesn't show misleading MISSING for platforms covered by 'both'.
        present_keys: list[tuple[str, str]] = []
        for k in KLASS_ORDER:
            klass_plats = {p for v in pivot.values() for (kk, p) in v if kk == k}
            if not klass_plats:
                continue
            if klass_plats == {"both"}:
                present_keys.append((k, "both"))
            else:
                for p in PLAT_ORDER:
                    if p in klass_plats:
                        present_keys.append((k, p))

        if not present_keys:
            lines.append("_no controller-class mappings found_\n")
            continue

        header = "| Button |" + "".join(f" {k}/{p} |" for k, p in present_keys)
        sep    = "|" + "|".join(["---"] * (1 + len(present_keys))) + "|"
        lines.append(header)
        lines.append(sep)

        buttons = sorted(sysr.declared_buttons or set(pivot.keys()))
        for btn in buttons:
            btn_keys = pivot.get(btn, {})
            row = [btn]
            for key in present_keys:
                klass, plat = key
                cell = btn_keys.get(key)
                if cell is not None:
                    row.append(cell)
                    continue
                # No exact hit — fall back through:
                # (1) per-platform column when 'both' is absent → show 'both' value
                # (2) 'both' column when per-platform branches cover this klass → render '—'
                # (3) actually missing → MISSING
                if plat != "both" and (klass, "both") in btn_keys:
                    row.append(btn_keys[(klass, "both")])
                elif plat == "both" and any(k == klass and p != "both" for (k, p) in btn_keys):
                    row.append("—")
                else:
                    row.append("**MISSING**")
            lines.append("| " + " | ".join(row) + " |")
        lines.append("")

    return "\n".join(lines) + "\n"


# --- main ------------------------------------------------------------------

def main() -> int:
    native_files: list[Path] = []
    for pat in NATIVE_BRIDGE_GLOBS:
        native_files.extend(sorted(REPO_ROOT.glob(pat)))

    if not native_files:
        print("audit_controls.py: no bridge files matched any glob — check globs.", file=sys.stderr)
        return 1

    native = merge([scan_file(p) for p in native_files])

    out_path = REPO_ROOT / "docs" / "controller-mapping-audit.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render(native))

    print(f"audit_controls: scanned {len(native_files)} files, {len(native)} systems → {out_path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
