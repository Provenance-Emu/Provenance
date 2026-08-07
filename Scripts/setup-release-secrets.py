#!/usr/bin/env python3
"""Interactive setup for Provenance release secrets, stored in 1Password.

Handles two things:

  1. App Store Connect API credentials (issuer ID, key ID, .p8) used by
     Scripts/release.sh for TestFlight uploads.
  2. REBASE_PAT — the GitHub Actions secret that lets auto-rebase re-trigger PR
     checks (see .github/workflows/auto-rebase-on-develop.yml).

Design rules, because these are credentials:

  * No secret is ever printed, logged, or echoed to the terminal.
  * No secret is passed as a command-line argument. `argv` is world-readable via
    `ps`, so 1Password items are created from a JSON template written to a
    mode-0600 temp file (the method `op item create --help` recommends for
    sensitive values), and the GitHub secret is piped to `gh` over stdin.
  * The generated .env contains only `op://` references, never values, so it is
    harmless if it leaks. `.env` is already gitignored.
  * Verification resolves each reference and checks it is non-empty WITHOUT
    printing it.

Usage:
    python3 Scripts/setup-release-secrets.py            # both flows
    python3 Scripts/setup-release-secrets.py --asc      # App Store Connect only
    python3 Scripts/setup-release-secrets.py --pat      # REBASE_PAT only
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from getpass import getpass
from pathlib import Path

REPO = "Provenance-Emu/Provenance"
VAULT = "Private"
ASC_ITEM_TITLE = "Provenance ASC API"
PAT_ITEM_TITLE = "GitHub REBASE_PAT (Provenance)"
KEYS_DIR = Path.home() / ".appstoreconnect" / "private_keys"
ENV_PATH = Path(__file__).resolve().parent.parent / ".env"

UUID_RE = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
                     r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")


# ---------------------------------------------------------------- utilities

class SetupError(Exception):
    """Fatal, with a message already suitable for the user."""


def info(msg: str) -> None:
    print(f"  {msg}")


def step(msg: str) -> None:
    print(f"\n\033[1m{msg}\033[0m")


def ok(msg: str) -> None:
    print(f"  \033[32m✓\033[0m {msg}")


def warn(msg: str) -> None:
    print(f"  \033[33m!\033[0m {msg}")


def run(cmd: list[str], *, stdin_data: str | None = None,
        capture: bool = True, check: bool = True) -> subprocess.CompletedProcess:
    """Run a command. Never interpolates secrets into a shell string."""
    try:
        proc = subprocess.run(
            cmd,
            input=stdin_data,
            capture_output=capture,
            text=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise SetupError(f"{cmd[0]} not found on PATH: {exc}") from exc
    if check and proc.returncode != 0:
        detail = (proc.stderr or proc.stdout or "").strip()
        raise SetupError(f"`{' '.join(cmd[:3])}…` failed (exit {proc.returncode}):\n    {detail}")
    return proc


def confirm(prompt: str, default: bool = False) -> bool:
    suffix = "[Y/n]" if default else "[y/N]"
    try:
        answer = input(f"  {prompt} {suffix} ").strip().lower()
    except EOFError:
        return default
    if not answer:
        return default
    return answer in ("y", "yes")


def prompt_secret(label: str) -> str:
    """Read a secret without echoing it. Retries on empty input."""
    for _ in range(3):
        value = getpass(f"  {label} (input hidden): ").strip()
        if value:
            return value
        warn("Empty value; try again.")
    raise SetupError(f"No value provided for {label}.")


# ---------------------------------------------------------------- preflight

def preflight(need_gh: bool) -> None:
    step("Checking prerequisites")

    if not shutil.which("op"):
        raise SetupError(
            "1Password CLI (`op`) not found.\n"
            "    Install it with: brew install 1password-cli"
        )
    ok(f"op {run(['op', '--version']).stdout.strip()}")

    # `op whoami` is the only reliable signed-in check; it exits non-zero otherwise.
    who = run(["op", "whoami"], check=False)
    if who.returncode != 0:
        raise SetupError(
            "1Password CLI is not signed in.\n"
            "    Run this first (it uses biometrics, so it must be you):\n"
            "        eval $(op signin)\n"
            "    Then re-run this script."
        )
    ok("op signed in")

    if need_gh:
        if not shutil.which("gh"):
            raise SetupError("GitHub CLI (`gh`) not found. Install with: brew install gh")
        auth = run(["gh", "auth", "status"], check=False)
        if auth.returncode != 0:
            raise SetupError("gh is not authenticated. Run: gh auth login")
        ok("gh authenticated")


def list_item_ids(title: str) -> list[str]:
    """Every item id in the vault whose title matches exactly.

    Uses `op item list` rather than `op item get <title>`: the latter EXITS
    NON-ZERO when several items share a title, which is indistinguishable from
    "not found" and previously caused this script to create a duplicate on every
    run instead of noticing the existing item.
    """
    proc = run(["op", "item", "list", "--vault", VAULT, "--format", "json"],
               check=False)
    if proc.returncode != 0:
        return []
    try:
        items = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    return [i["id"] for i in items if i.get("title") == title]


def ensure_single_item(title: str) -> str | None:
    """Reduce `title` to at most one item. Returns the surviving id, or None.

    Duplicates make every op:// reference to that title ambiguous and unusable,
    so they must be resolved before references can be built.
    """
    ids = list_item_ids(title)
    if len(ids) <= 1:
        return ids[0] if ids else None

    warn(f"Found {len(ids)} items titled “{title}” in {VAULT}.")
    info("Duplicates make op:// references to this title ambiguous and unusable.")
    for item_id in ids:
        print(f"      {item_id}")
    if not confirm(f"Delete all {len(ids)} and start clean?", default=True):
        raise SetupError(
            "Cannot continue while duplicates exist — references cannot be resolved.\n"
            "    Remove the extras in the 1Password app, then re-run."
        )
    for item_id in ids:
        run(["op", "item", "delete", item_id, "--vault", VAULT], check=False)
    remaining = list_item_ids(title)
    if remaining:
        raise SetupError(f"{len(remaining)} item(s) titled “{title}” still remain; "
                         "delete them in the 1Password app and re-run.")
    ok(f"Removed {len(ids)} duplicate item(s)")
    return None


def create_item_from_template(payload: dict) -> None:
    """Create an item from a JSON template written to a 0600 temp file.

    Avoids putting secrets in argv (visible to `ps`). The file is removed in a
    finally block even if `op` fails.
    """
    fd, path = tempfile.mkstemp(suffix=".json")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as handle:
            json.dump(payload, handle)
        run(["op", "item", "create", "--vault", VAULT, "--template", path])
    finally:
        try:
            os.remove(path)
        except OSError as exc:
            warn(f"Could not remove temporary template file {path}: {exc}")


def reference_resolves(ref: str) -> bool:
    """True if `op read <ref>` yields a non-empty value. Never prints it."""
    proc = run(["op", "read", ref], check=False)
    return proc.returncode == 0 and bool(proc.stdout.strip())


def discover_refs(title: str, labels: list[str]) -> dict[str, str]:
    """Build op:// references by INSPECTING the stored item, not by assuming.

    1Password may place custom fields inside a section, in which case the
    reference is op://vault/item/section/field rather than op://vault/item/field.
    Guessing that wrong yields references that don't resolve, so read the real
    structure back and try each plausible path until one resolves. Field VALUES
    are never read or printed here — only ids, labels and section names.
    """
    ids = list_item_ids(title)
    if not ids:
        raise SetupError(f"No item titled “{title}” found in {VAULT}.")
    if len(ids) > 1:
        raise SetupError(f"{len(ids)} items are titled “{title}”; references would be "
                         "ambiguous. Re-run to clean them up.")
    proc = run(["op", "item", "get", ids[0], "--vault", VAULT, "--format", "json"],
               check=False)
    if proc.returncode != 0:
        raise SetupError(f"Could not read back “{title}” from 1Password to build "
                         f"references:\n    {(proc.stderr or '').strip()}")
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise SetupError(f"1Password returned unparseable JSON for “{title}”: {exc}") from exc

    by_label: dict[str, dict] = {}
    for field in data.get("fields", []):
        for key in (field.get("label"), field.get("id")):
            if key and key not in by_label:
                by_label[key] = field

    refs: dict[str, str] = {}
    missing: list[str] = []
    for label in labels:
        field = by_label.get(label)
        if field is None:
            missing.append(label)
            continue

        # Reference by item UUID, not title. Titles are ambiguous (duplicates) and
        # `op item delete` ARCHIVES rather than purges, so a title can still resolve
        # to a deleted item — `op run` then fails with "has been deleted or archived"
        # even though the script's own title-based verification just succeeded.
        # UUIDs are immune to both.
        item_uuid = data.get("id") or ids[0]
        candidates: list[str] = []
        section = field.get("section") or {}
        section_name = section.get("label") or section.get("id")
        for name in (field.get("label"), field.get("id")):
            if not name:
                continue
            if section_name:
                candidates.append(f"op://{VAULT}/{item_uuid}/{section_name}/{name}")
            candidates.append(f"op://{VAULT}/{item_uuid}/{name}")

        chosen = next((c for c in candidates if reference_resolves(c)), None)
        if chosen is None:
            missing.append(label)
        else:
            refs[label] = chosen

    if missing:
        shape = ", ".join(
            f"{f.get('label') or f.get('id')}"
            f"{' [section: ' + ((f.get('section') or {}).get('label') or (f.get('section') or {}).get('id')) + ']' if f.get('section') else ''}"
            for f in data.get("fields", [])
        )
        raise SetupError(
            "Could not build working references for: " + ", ".join(missing) + "\n"
            f"    Fields actually present on “{title}”: {shape or '(none)'}\n"
            "    Delete the item in 1Password and re-run, or fix the labels to match."
        )
    return refs


# ---------------------------------------------------------- App Store Connect

def choose_key() -> Path:
    keys = sorted(KEYS_DIR.glob("AuthKey_*.p8"), key=lambda p: p.stat().st_mtime,
                  reverse=True)
    if not keys:
        raise SetupError(
            f"No AuthKey_*.p8 found in {KEYS_DIR}.\n"
            "    Download your key from App Store Connect → Users and Access →\n"
            "    Integrations → App Store Connect API, then move it there."
        )

    if len(keys) == 1:
        info(f"Using the only key found: {keys[0].name}")
        return keys[0]

    info("Multiple App Store Connect keys found (newest first):")
    for idx, key in enumerate(keys, start=1):
        mtime = key.stat().st_mtime
        import datetime
        when = datetime.datetime.fromtimestamp(mtime).strftime("%Y-%m-%d")
        marker = "  ← newest" if idx == 1 else ""
        print(f"      {idx}) {key.name}  (added {when}){marker}")
    warn("A revoked key fails only at UPLOAD, after a full archive build — "
         "confirm the one you pick is still active in App Store Connect.")
    while True:
        raw = input(f"  Select key [1-{len(keys)}, default 1]: ").strip()
        if not raw:
            return keys[0]
        if raw.isdigit() and 1 <= int(raw) <= len(keys):
            return keys[int(raw) - 1]
        warn("Invalid selection.")


def key_id_from(path: Path) -> str:
    """AuthKey_ABC123.p8 → ABC123"""
    name = path.stem
    return name[len("AuthKey_"):] if name.startswith("AuthKey_") else name


def setup_asc() -> None:
    step("App Store Connect API credentials")

    key_path = choose_key()
    key_id = key_id_from(key_path)
    ok(f"Key ID: {key_id}")

    existing_id = ensure_single_item(ASC_ITEM_TITLE)
    if existing_id:
        warn(f"1Password item “{ASC_ITEM_TITLE}” already exists in {VAULT}.")
        if not confirm("Replace it?", default=False):
            info("Keeping the existing item; skipping to .env generation.")
        else:
            run(["op", "item", "delete", existing_id, "--vault", VAULT])
            ok("Deleted the old item")
            existing_id = None

    if not existing_id:
        info("The Issuer ID is a UUID from App Store Connect →")
        info("Users and Access → Integrations → App Store Connect API.")
        if confirm("Open that page in your browser?", default=False):
            run(["open", "https://appstoreconnect.apple.com/access/integrations/api"],
                check=False)

        issuer = prompt_secret("Issuer ID")
        if not UUID_RE.match(issuer):
            warn("That doesn't look like a UUID (8-4-4-4-12 hex).")
            if not confirm("Use it anyway?", default=False):
                raise SetupError("Aborted at Issuer ID entry.")

        try:
            key_content = key_path.read_text()
        except OSError as exc:
            raise SetupError(f"Could not read {key_path}: {exc}") from exc

        if "PRIVATE KEY" not in key_content:
            warn(f"{key_path.name} does not look like a PEM private key.")
            if not confirm("Continue anyway?", default=False):
                raise SetupError("Aborted: key file failed a sanity check.")

        # Secure Note with custom concealed fields. "API Credential" is a UI
        # category, not a CLI template (`op item template list` has no such entry).
        payload = {
            "title": ASC_ITEM_TITLE,
            "category": "SECURE_NOTE",
            "fields": [
                {"id": "notesPlain", "type": "STRING", "purpose": "NOTES",
                 "label": "notesPlain",
                 "value": "Created by Scripts/setup-release-secrets.py. "
                          "Used by Scripts/release.sh via `op run --env-file=.env`."},
                {"id": "key_id", "type": "STRING", "label": "key_id",
                 "value": key_id},
                {"id": "issuer_id", "type": "CONCEALED", "label": "issuer_id",
                 "value": issuer},
                {"id": "key_content", "type": "CONCEALED", "label": "key_content",
                 "value": key_content},
            ],
        }
        create_item_from_template(payload)
        del issuer, key_content  # drop references promptly
        ok(f"Stored “{ASC_ITEM_TITLE}” in 1Password ({VAULT})")

    write_env(key_id, key_path)


def write_env(key_id: str, key_path: Path) -> None:
    step("Writing .env (references only — no secret values)")

    discovered = discover_refs(ASC_ITEM_TITLE, ["key_id", "issuer_id", "key_content"])
    refs = {
        "ASC_API_KEY_ID": discovered["key_id"],
        "ASC_API_ISSUER_ID": discovered["issuer_id"],
        "ASC_API_KEY_CONTENT": discovered["key_content"],
    }

    if ENV_PATH.exists():
        warn(f"{ENV_PATH.name} already exists.")
        if not confirm("Overwrite it?", default=False):
            info("Left the existing .env alone. Required references:")
            for name, ref in refs.items():
                print(f"      {name}={ref}")
            return

    body = [
        "# Generated by Scripts/setup-release-secrets.py",
        "# Contains 1Password REFERENCES, not secrets — safe if it leaks.",
        f"# References use the 1Password item UUID for “{ASC_ITEM_TITLE}”.",
        "# UUIDs are used deliberately: titles can be duplicated, and a deleted item",
        "# is archived rather than purged, so a title can resolve to a dead item.",
        "# Resolve them at run time:",
        "#     op run --env-file=.env -- ./Scripts/release.sh",
        "",
    ]
    body += [f"{name}={ref}" for name, ref in refs.items()]
    body += [
        "",
        "# Local fallback for tools that want a file path rather than contents.",
        f"ASC_API_KEY_PATH={key_path}",
        "",
    ]
    ENV_PATH.write_text("\n".join(body))
    os.chmod(ENV_PATH, 0o600)
    ok(f"Wrote {ENV_PATH} (mode 600)")

    step("Verifying references resolve")
    failed = [name for name, ref in refs.items() if not reference_resolves(ref)]
    if failed:
        raise SetupError(
            "These references did not resolve: " + ", ".join(failed) + "\n"
            "    Check the item's field labels in 1Password match the names above."
        )
    ok(f"All {len(refs)} references resolve (values not shown)")


# ------------------------------------------------------------------ PAT flow

def setup_pat() -> None:
    step("GitHub REBASE_PAT")

    info("Why: auto-rebase pushes with GITHUB_TOKEN, and GitHub does not fire")
    info("pull_request events for token-authored pushes — so rebased PRs keep")
    info("stale check results and read as green. A PAT restores real CI.")
    print()
    info("Create a fine-grained PAT with:")
    info("  Repository access → Only select repositories → Provenance-Emu/Provenance")
    info("  Permissions → Contents: Read and write, Pull requests: Read")

    if confirm("Open the token creation page?", default=False):
        run(["open", "https://github.com/settings/personal-access-tokens/new"],
            check=False)

    existing_id = ensure_single_item(PAT_ITEM_TITLE)
    if existing_id:
        warn(f"1Password item “{PAT_ITEM_TITLE}” already exists.")
        if confirm("Reuse the stored token (skip re-entry)?", default=True):
            push_pat_to_github()
            return
        run(["op", "item", "delete", existing_id, "--vault", VAULT])
        ok("Deleted the old item")

    token = prompt_secret("Paste the PAT")
    if not token.startswith(("github_pat_", "ghp_")):
        warn("That doesn't look like a GitHub PAT (expected github_pat_… or ghp_…).")
        if not confirm("Use it anyway?", default=False):
            raise SetupError("Aborted at PAT entry.")

    payload = {
        "title": PAT_ITEM_TITLE,
        "category": "SECURE_NOTE",
        "fields": [
            {"id": "notesPlain", "type": "STRING", "purpose": "NOTES",
             "label": "notesPlain",
             "value": "GitHub Actions secret REBASE_PAT for Provenance-Emu/Provenance. "
                      "Set by Scripts/setup-release-secrets.py."},
            {"id": "credential", "type": "CONCEALED", "label": "credential",
             "value": token},
        ],
    }
    create_item_from_template(payload)
    del token
    ok(f"Stored “{PAT_ITEM_TITLE}” in 1Password")

    push_pat_to_github()


def push_pat_to_github() -> None:
    step("Setting the REBASE_PAT repository secret")

    ref = discover_refs(PAT_ITEM_TITLE, ["credential"])["credential"]
    read = run(["op", "read", ref], check=False)
    if read.returncode != 0 or not read.stdout.strip():
        raise SetupError(f"Could not resolve {ref} from 1Password.")

    # Piped over stdin: `--body` would place the token in argv, where `ps` sees it.
    run(["gh", "secret", "set", "REBASE_PAT", "--repo", REPO],
        stdin_data=read.stdout.strip())
    ok(f"REBASE_PAT set on {REPO}")

    listing = run(["gh", "secret", "list", "--repo", REPO], check=False)
    if "REBASE_PAT" in (listing.stdout or ""):
        ok("Verified present in the repository secret list")
    else:
        warn("Secret was set but did not appear in the listing; check manually.")


# ---------------------------------------------------------------------- main

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Store Provenance release secrets in 1Password and wire them up.")
    parser.add_argument("--asc", action="store_true",
                        help="App Store Connect credentials only")
    parser.add_argument("--pat", action="store_true",
                        help="GitHub REBASE_PAT only")
    args = parser.parse_args()

    do_asc = args.asc or not (args.asc or args.pat)
    do_pat = args.pat or not (args.asc or args.pat)

    try:
        preflight(need_gh=do_pat)
        if do_asc:
            setup_asc()
        if do_pat:
            setup_pat()
    except SetupError as exc:
        print(f"\n\033[31m✗ {exc}\033[0m", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("\n  Cancelled. Nothing partial was written to GitHub.", file=sys.stderr)
        return 130

    step("Done")
    if do_asc:
        info("Cut a TestFlight build with:")
        info("    op run --env-file=.env -- ./Scripts/release.sh")
    if do_pat:
        info("Auto-rebase will now re-arm PR checks on its next run.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
