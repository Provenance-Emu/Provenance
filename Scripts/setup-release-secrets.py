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
            import webbrowser
            webbrowser.open("https://appstoreconnect.apple.com/access/integrations/api", new=2)

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
        import webbrowser
        webbrowser.open("https://github.com/settings/personal-access-tokens/new", new=2)

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


# ------------------------------------------------------------ credential check

def verify_asc_credentials() -> None:
    """Authenticate against App Store Connect BEFORE anything expensive runs.

    `xcodebuild -exportArchive` only authenticates at UPLOAD — i.e. after a full
    archive build. A bad issuer ID or a revoked key therefore costs 30+ minutes
    before surfacing as "No Accounts with App Store Connect Access". notarytool
    accepts the same ASC API credentials and round-trips in seconds, so use it as
    a cheap proxy for "will the upload authenticate?".

    Reads the same env vars release.sh does, so it must be invoked the same way:
        op run --env-file=.env -- python3 Scripts/setup-release-secrets.py --verify
    """
    step("Verifying App Store Connect credentials")

    key_id = os.environ.get("ASC_API_KEY_ID", "").strip()
    issuer = os.environ.get("ASC_API_ISSUER_ID", "").strip()
    key_path = os.environ.get("ASC_API_KEY_PATH", "").strip()
    key_content = os.environ.get("ASC_API_KEY_CONTENT", "")

    missing = [n for n, v in (("ASC_API_KEY_ID", key_id),
                              ("ASC_API_ISSUER_ID", issuer)) if not v]
    if missing:
        raise SetupError(
            "Missing " + ", ".join(missing) + " in the environment.\n"
            "    Run this under `op run --env-file=.env --` so the references resolve,\n"
            "    or re-run this script without --verify to (re)create them."
        )
    if v_looks_like_ref(key_id) or v_looks_like_ref(issuer):
        raise SetupError(
            "Credentials are still unresolved op:// reference strings.\n"
            "    Invoke under: op run --env-file=.env -- …"
        )
    if not UUID_RE.match(issuer):
        warn("ASC_API_ISSUER_ID is not a UUID — App Store Connect will reject it.")

    ok(f"Key ID {key_id}")

    tmp_key: Path | None = None
    try:
        if not key_path or not Path(key_path).exists():
            if not key_content.strip():
                raise SetupError("Neither ASC_API_KEY_PATH nor ASC_API_KEY_CONTENT is usable.")
            fd, tmp = tempfile.mkstemp(suffix=".p8")
            os.fchmod(fd, 0o600)
            with os.fdopen(fd, "w") as handle:
                handle.write(key_content)
            tmp_key = Path(tmp)
            key_path = str(tmp_key)

        proc = run(["xcrun", "notarytool", "history",
                    "--key", key_path, "--key-id", key_id, "--issuer", issuer],
                   check=False)
        combined = f"{proc.stdout}\n{proc.stderr}"
        if proc.returncode == 0:
            ok("App Store Connect accepted these credentials")
            return

        lowered = combined.lower()
        if "unauthorized" in lowered or "authentication" in lowered or "401" in lowered:
            raise SetupError(
                "App Store Connect REJECTED these credentials.\n"
                f"    Key ID: {key_id}\n"
                "    Most likely causes, in order:\n"
                "      1. Issuer ID is wrong — copy it again from App Store Connect →\n"
                "         Users and Access → Integrations → App Store Connect API.\n"
                "      2. The key has been revoked. Confirm it is still listed as Active.\n"
                "      3. The .p8 does not belong to this Key ID.\n"
                "      4. The key lacks a role that can upload builds (App Manager or Admin).\n"
                "    Fix with: python3 Scripts/setup-release-secrets.py --asc"
            )
        raise SetupError(
            "Could not verify credentials (notarytool exited "
            f"{proc.returncode}):\n    {combined.strip()[:400]}"
        )
    finally:
        if tmp_key is not None:
            try:
                tmp_key.unlink()
            except OSError:
                pass


def v_looks_like_ref(value: str) -> bool:
    return value.startswith("op://")


# ------------------------------------------------------------- full preflight

def _check_disk_space(min_gb: int = 25) -> tuple[bool, str]:
    """Archives plus DerivedData for a ~3 GB app need real headroom.

    Running out mid-archive wastes the whole build and leaves a partial
    DerivedData that often has to be deleted by hand.
    """
    st = os.statvfs(str(Path.home()))
    free_gb = (st.f_bavail * st.f_frsize) / (1024 ** 3)
    if free_gb < min_gb:
        return False, (f"Only {free_gb:.1f} GB free; archives need ~{min_gb} GB. "
                       "Clear DerivedData or free space first.")
    return True, f"{free_gb:.0f} GB free"


def _check_xcode() -> tuple[bool, str]:
    proc = run(["xcode-select", "-p"], check=False)
    if proc.returncode != 0:
        return False, "xcode-select is not configured (xcode-select --install?)"
    path = proc.stdout.strip()
    ver = run(["xcodebuild", "-version"], check=False)
    if ver.returncode != 0:
        return False, f"xcodebuild unusable at {path}: {(ver.stderr or '').strip()[:120]}"
    first = (ver.stdout or "").splitlines()[0] if ver.stdout else "?"
    return True, f"{first} ({path})"


def _discover_team_ids() -> tuple[list[str], str]:
    """Effective DEVELOPMENT_TEAM(s), from xcconfig if present else the pbxproj.

    CodeSigning.xcconfig is OPTIONAL: the project already carries a
    DEVELOPMENT_TEAM for its normal contributors, and the xcconfig only exists to
    override it. Demanding the file was wrong — what matters is that *some* team
    resolves, and that the keychain holds a matching distribution certificate.
    """
    root = Path(__file__).resolve().parent.parent
    cfg = root / "CodeSigning.xcconfig"
    if cfg.exists():
        for line in cfg.read_text().splitlines():
            line = line.strip()
            if line.startswith("DEVELOPMENT_TEAM"):
                value = line.split("=", 1)[-1].strip()
                if value:
                    return [value], "CodeSigning.xcconfig"

    teams: list[str] = []
    for proj in root.glob("*.xcodeproj/project.pbxproj"):
        for match in re.finditer(r"DEVELOPMENT_TEAM = ([A-Z0-9]{8,12});", proj.read_text()):
            team = match.group(1)
            if team not in teams:
                teams.append(team)
    return teams, "project.pbxproj"


def _check_signing_config() -> tuple[bool, str]:
    teams, source = _discover_team_ids()
    if not teams:
        return False, ("no DEVELOPMENT_TEAM found in CodeSigning.xcconfig or the "
                       "project — copy CodeSigning.xcconfig.sample and fill it in")
    return True, f"team {', '.join(teams)} (from {source})"


def _check_signing_identities() -> tuple[bool, str]:
    """An expired/absent distribution cert fails at EXPORT, after the archive.

    Also cross-checks that an identity exists for the team the project actually
    builds with — having *a* distribution cert for a different team is a failure
    that otherwise only surfaces at export time.
    """
    proc = run(["security", "find-identity", "-v", "-p", "codesigning"], check=False)
    if proc.returncode != 0:
        return False, "could not query the keychain for signing identities"

    lines = [ln for ln in (proc.stdout or "").splitlines()
             if "Apple Distribution" in ln or "iPhone Distribution" in ln]
    if not lines:
        return False, ("no Apple Distribution certificate in the keychain — "
                       "export will fail after the archive completes")

    keychain_teams = set(re.findall(r"\(([A-Z0-9]{8,12})\)", "\n".join(lines)))
    project_teams, _ = _discover_team_ids()

    if project_teams and keychain_teams:
        matched = [t for t in project_teams if t in keychain_teams]
        if not matched:
            return False, (
                f"{len(lines)} distribution identity(ies) present, but none for the "
                f"project's team ({', '.join(project_teams)}). "
                f"Keychain has: {', '.join(sorted(keychain_teams))}"
            )
        return True, f"{len(lines)} identity(ies), matching team {matched[0]}"
    return True, f"{len(lines)} distribution identity(ies)"


def _check_submodules() -> tuple[bool, str]:
    """`-` prefix means uninitialised; those break the build late and confusingly."""
    proc = run(["git", "submodule", "status"], check=False)
    if proc.returncode != 0:
        return True, "skipped (not a git checkout?)"
    uninit = [ln.split()[1] for ln in (proc.stdout or "").splitlines()
              if ln.startswith("-")]
    if uninit:
        preview = ", ".join(uninit[:3]) + ("…" if len(uninit) > 3 else "")
        return False, (f"{len(uninit)} uninitialised submodule(s): {preview}\n"
                       "        git submodule update --init --recursive")
    return True, "all submodules initialised"


def full_preflight() -> None:
    """Every cheap check that would otherwise fail late in a 30+ minute build."""
    step("Release preflight")

    checks = [
        ("Xcode", _check_xcode),
        ("Disk space", _check_disk_space),
        ("Signing identities", _check_signing_identities),
        ("Signing config", _check_signing_config),
        ("Submodules", _check_submodules),
    ]

    failures: list[str] = []
    for label, fn in checks:
        try:
            passed, detail = fn()
        except Exception as exc:  # a broken check must not mask the others
            passed, detail = False, f"check raised {type(exc).__name__}: {exc}"
        if passed:
            ok(f"{label}: {detail}")
        else:
            print(f"  \033[31m✗\033[0m {label}: {detail}")
            failures.append(label)

    # Credentials last: it is the slowest of the cheap checks (a network round trip).
    try:
        verify_asc_credentials()
    except SetupError as exc:
        print(f"  \033[31m✗\033[0m Credentials:\n    {exc}")
        failures.append("App Store Connect credentials")

    if failures:
        raise SetupError(
            f"{len(failures)} preflight check(s) failed: " + ", ".join(failures) + "\n"
            "    Fixing these now avoids discovering them after a full archive build."
        )
    step("Preflight passed — safe to build")


# ---------------------------------------------------------------------- main

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Store Provenance release secrets in 1Password and wire them up.")
    parser.add_argument("--asc", action="store_true",
                        help="App Store Connect credentials only")
    parser.add_argument("--pat", action="store_true",
                        help="GitHub REBASE_PAT only")
    parser.add_argument("--preflight", action="store_true",
                        help="Run every pre-build check (tools, disk, signing, "
                             "submodules, credentials) then exit")
    parser.add_argument("--verify", action="store_true",
                        help="Only check that ASC credentials authenticate (fast; "
                             "run under `op run --env-file=.env --`)")
    args = parser.parse_args()

    if args.preflight:
        try:
            full_preflight()
        except SetupError as exc:
            print(f"\n\033[31m✗ {exc}\033[0m", file=sys.stderr)
            return 1
        return 0

    if args.verify:
        try:
            verify_asc_credentials()
        except SetupError as exc:
            print(f"\n\033[31m✗ {exc}\033[0m", file=sys.stderr)
            return 1
        return 0

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
