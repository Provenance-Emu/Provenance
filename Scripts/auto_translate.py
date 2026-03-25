#!/usr/bin/env python3
"""
auto_translate.py — Provenance auto-translation script

Reads new/changed keys from an en.lproj/Localizable.strings diff and translates
them to all supported languages using the Claude API (claude-haiku-4-5 for cost).

Usage:
    python3 Scripts/auto_translate.py \
        --base-ref HEAD~1 \
        --head-ref HEAD \
        --strings-file PVUI/Sources/PVSwiftUI/Resources/en.lproj/Localizable.strings \
        --output-dir PVUI/Sources/PVSwiftUI/Resources

Environment:
    ANTHROPIC_API_KEY — required, set in GitHub Actions secrets

Cost control:
    Only translates delta (new/changed keys), never the entire file.
    Estimated: <$0.01 per typical run at Haiku rates.

Translation-skip convention:
    Add a comment `/* translation-skip */` on the line before a key to exclude it:
        /* translation-skip */
        "InternalDebugKey" = "debug value";
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from pathlib import Path

try:
    import anthropic
except ImportError:
    print("Error: anthropic package not installed. Run: pip install anthropic", file=sys.stderr)
    sys.exit(1)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

TARGET_LANGUAGES: dict[str, str] = {
    "zh-Hans": "Simplified Chinese",
    "ja": "Japanese",
    "ko": "Korean",
    "es": "Spanish",
    "pt-BR": "Brazilian Portuguese",
    "de": "German",
    "fr": "French",
    "it": "Italian",
    "nl": "Dutch",
    "ru": "Russian",
    "ar": "Arabic",
}

# Model to use — haiku is cheapest and sufficient for .strings translation
TRANSLATION_MODEL = "claude-haiku-4-5-20251001"

# Proper nouns that must NOT be translated
PRESERVE_NOUNS = [
    "Provenance",
    "RetroArch",
    "RetroAchievements",
    "Cheevos",
    "Realm",
    "CloudKit",
    "OpenEmu",
    "BIOS",
    "ROM",
    "ROMs",
    "AirPlay",
    "MFi",
    "iCloud",
]

# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

_KEY_VALUE_RE = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
_SKIP_RE = re.compile(r"/\*\s*translation-skip\s*\*/")


def _parse_strings_text(text: str) -> dict[str, str]:
    """Parse .strings text into {key: value}, honouring /* translation-skip */ markers."""
    result: dict[str, str] = {}
    skip_next = False
    for line in text.splitlines():
        stripped = line.strip()
        if _SKIP_RE.match(stripped):
            skip_next = True
            continue
        m = _KEY_VALUE_RE.match(stripped)
        if m:
            if not skip_next:
                result[m.group(1)] = m.group(2)
            skip_next = False
        elif stripped:
            skip_next = False
    return result


def get_changed_keys(base_ref: str, head_ref: str, strings_file: str) -> dict[str, str]:
    """Return {key: new_value} for keys that are new or changed between two git refs."""
    def git_show(ref: str, path: str) -> str:
        result = subprocess.run(
            ["git", "show", f"{ref}:{path}"],
            capture_output=True, text=True,
        )
        return result.stdout if result.returncode == 0 else ""

    old_text = git_show(base_ref, strings_file)
    new_text = git_show(head_ref, strings_file)

    old = _parse_strings_text(old_text)
    new = _parse_strings_text(new_text)

    changed: dict[str, str] = {}
    for key, value in new.items():
        if key not in old or old[key] != value:
            changed[key] = value
    return changed


# ---------------------------------------------------------------------------
# Translation
# ---------------------------------------------------------------------------

def build_translation_prompt(keys: dict[str, str], target_language: str) -> str:
    nouns = ", ".join(PRESERVE_NOUNS)
    entries = "\n".join(f'"{k}" = "{v}";' for k, v in keys.items())
    return f"""\
You are a professional iOS app localizer. Translate the following iOS .strings entries from English to {target_language}.

Rules:
1. Return ONLY valid .strings format lines — one per entry, no extra text.
2. Preserve format specifiers exactly as-is: %@, %d, %ld, %1$@, etc.
3. Do NOT translate these proper nouns: {nouns}
4. Keep key names unchanged; only translate the value (right side of =).
5. Use natural, idiomatic {target_language} appropriate for a mobile gaming app.
6. Preserve escaped characters like \\n, \\t, \\\".

English strings to translate:
{entries}

Respond with ONLY the translated .strings lines, nothing else."""


def translate_keys(
    client: anthropic.Anthropic,
    keys: dict[str, str],
    lang_code: str,
    lang_name: str,
) -> dict[str, str]:
    """Translate a dict of {key: english_value} to {key: translated_value}."""
    if not keys:
        return {}

    prompt = build_translation_prompt(keys, lang_name)
    message = client.messages.create(
        model=TRANSLATION_MODEL,
        max_tokens=4096,
        messages=[{"role": "user", "content": prompt}],
    )
    response_text = message.content[0].text.strip()

    translated: dict[str, str] = {}
    for line in response_text.splitlines():
        m = _KEY_VALUE_RE.match(line.strip())
        if m:
            translated[m.group(1)] = m.group(2)

    # Warn about any keys the model omitted; do NOT fall back to English
    # (overwriting an existing translation with English silently regresses it)
    for key in keys:
        if key not in translated:
            print(f"  Warning: key '{key}' missing from {lang_code} response — skipping to preserve existing translation")

    return translated


# ---------------------------------------------------------------------------
# File merging
# ---------------------------------------------------------------------------

def read_existing_strings(path: Path) -> tuple[list[str], dict[str, int]]:
    """
    Read existing .strings file.
    Returns (lines, {key: line_index}) so we can update in-place.
    """
    if not path.exists():
        return [], {}
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    key_lines: dict[str, int] = {}
    for i, line in enumerate(lines):
        m = _KEY_VALUE_RE.match(line.strip())
        if m:
            key_lines[m.group(1)] = i
    return lines, key_lines


def merge_translations(
    output_dir: Path,
    lang_code: str,
    translated: dict[str, str],
    strings_filename: str = "Localizable.strings",
) -> Path:
    """
    Merge translated keys into the existing language .strings file.
    Creates the lproj directory if it doesn't exist.
    Returns the path written.
    """
    lproj_dir = output_dir / f"{lang_code}.lproj"
    lproj_dir.mkdir(parents=True, exist_ok=True)
    strings_path = lproj_dir / strings_filename

    lines, key_lines = read_existing_strings(strings_path)

    # Update existing keys in-place, collect new keys
    new_keys: dict[str, str] = {}
    for key, value in translated.items():
        escaped_value = value.replace('"', '\\"')
        entry_line = f'"{key}" = "{escaped_value}";\n'
        if key in key_lines:
            lines[key_lines[key]] = entry_line
        else:
            new_keys[key] = value

    # Append new keys at end
    if new_keys:
        if lines and not lines[-1].endswith("\n"):
            lines.append("\n")
        lines.append("\n/* Auto-translated — please review */\n")
        for key, value in new_keys.items():
            escaped_value = value.replace('"', '\\"')
            lines.append(f'"{key}" = "{escaped_value}";\n')

    strings_path.write_text("".join(lines), encoding="utf-8")
    return strings_path


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description="Auto-translate Provenance .strings files")
    parser.add_argument("--base-ref", default="HEAD~1", help="Base git ref (before change)")
    parser.add_argument("--head-ref", default="HEAD", help="Head git ref (after change)")
    parser.add_argument(
        "--strings-file",
        default="PVUI/Sources/PVSwiftUI/Resources/en.lproj/Localizable.strings",
        help="Repo-relative path to en.lproj/Localizable.strings",
    )
    parser.add_argument(
        "--output-dir",
        default="PVUI/Sources/PVSwiftUI/Resources",
        help="Directory containing language .lproj folders",
    )
    parser.add_argument(
        "--languages",
        nargs="*",
        default=list(TARGET_LANGUAGES.keys()),
        help="Language codes to translate (default: all)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be translated without calling the API or writing files",
    )
    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key and not args.dry_run:
        print("Error: ANTHROPIC_API_KEY environment variable not set.", file=sys.stderr)
        return 1

    print(f"Detecting changed keys in {args.strings_file} ({args.base_ref}..{args.head_ref})...")
    changed_keys = get_changed_keys(args.base_ref, args.head_ref, args.strings_file)

    if not changed_keys:
        print("No new or changed keys found — nothing to translate.")
        return 0

    print(f"Found {len(changed_keys)} new/changed key(s):")
    for key, value in changed_keys.items():
        print(f"  {key!r} = {value!r}")

    if args.dry_run:
        print("\n[dry-run] Skipping API calls and file writes.")
        return 0

    client = anthropic.Anthropic(api_key=api_key)
    output_dir = Path(args.output_dir)
    strings_filename = Path(args.strings_file).name

    summary_lines: list[str] = []
    for lang_code in args.languages:
        if lang_code not in TARGET_LANGUAGES:
            print(f"Warning: unknown language code '{lang_code}', skipping", file=sys.stderr)
            continue
        lang_name = TARGET_LANGUAGES[lang_code]
        print(f"Translating to {lang_name} ({lang_code})...")
        try:
            translated = translate_keys(client, changed_keys, lang_code, lang_name)
            written_path = merge_translations(output_dir, lang_code, translated, strings_filename)
            print(f"  Wrote {written_path}")
            summary_lines.append(f"- **{lang_name}** (`{lang_code}`): {len(translated)} key(s) written to `{written_path}`")
        except Exception as exc:  # noqa: BLE001
            print(f"  Error translating {lang_code}: {exc}", file=sys.stderr)
            summary_lines.append(f"- **{lang_name}** (`{lang_code}`): ❌ error — {exc}")

    # Write summary for GitHub Actions step summary
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a", encoding="utf-8") as f:
            f.write("## Auto-Translation Summary\n\n")
            f.write(f"**{len(changed_keys)} key(s) translated**\n\n")
            f.write("### Keys translated\n")
            for key, value in changed_keys.items():
                f.write(f"- `{key}` — _{value}_\n")
            f.write("\n### Languages updated\n")
            f.write("\n".join(summary_lines) + "\n")

    print("\nDone.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
