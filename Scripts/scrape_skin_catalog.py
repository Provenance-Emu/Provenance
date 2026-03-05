#!/usr/bin/env python3
"""
scrape_skin_catalog.py -- Crawl community Delta skin sites and generate catalog.json.

Scrapes skin metadata from multiple community sources that host .deltaskin
files compatible with Delta/Ignited/Provenance emulators, producing a unified
catalog of available skins with download URLs and metadata.

Supported sources:
  - delta-skins.github.io  (HTML data attributes on <img> tags)
  - Polyphian/deltaEmu      (GitHub repo directory listing)
  - LitRitt/emuskins        (GitHub repo directory listing)

Usage:
    python3 Scripts/scrape_skin_catalog.py --output catalog.json
    python3 Scripts/scrape_skin_catalog.py --source delta-skins --output catalog.json
    python3 Scripts/scrape_skin_catalog.py --source all --output catalog.json
    python3 Scripts/scrape_skin_catalog.py --validate catalog.json
    python3 Scripts/scrape_skin_catalog.py --dry-run --source all
"""

import argparse
import hashlib
import html.parser
import json
import os
import sys
import time
import urllib.parse
from datetime import datetime, timezone

# Optional imports -- fall back to stdlib if packages are unavailable
try:
    import requests
except ImportError:
    requests = None

try:
    from bs4 import BeautifulSoup
except ImportError:
    BeautifulSoup = None


# ---------------------------------------------------------------------------
# Stdlib HTML parser fallback (used when beautifulsoup4 is not installed)
# ---------------------------------------------------------------------------

class _ImgDataExtractor(html.parser.HTMLParser):
    """Minimal HTMLParser to extract data-* attributes from <img> tags."""

    def __init__(self):
        super().__init__()
        self.imgs = []

    def handle_starttag(self, tag, attrs):
        if tag == "img":
            d = dict(attrs)
            if "data-download" in d:
                self.imgs.append(d)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

CATALOG_VERSION = 1

# Map system directory/page names to (short_code, gameTypeIdentifier) pairs
SYSTEM_MAP = {
    # delta-skins.github.io page names
    "gba":       ("gba",     "com.rileytestut.delta.game.gba"),
    "gbc":       ("gbc",     "com.rileytestut.delta.game.gbc"),
    "nes":       ("nes",     "com.rileytestut.delta.game.nes"),
    "snes":      ("snes",    "com.rileytestut.delta.game.snes"),
    "n64":       ("n64",     "com.rileytestut.delta.game.n64"),
    "nds":       ("nds",     "com.rileytestut.delta.game.ds"),
    # Long-form names
    "game boy advance":     ("gba",     "com.rileytestut.delta.game.gba"),
    "game boy color":       ("gbc",     "com.rileytestut.delta.game.gbc"),
    "game boy":             ("gbc",     "com.rileytestut.delta.game.gbc"),
    "nintendo entertainment system": ("nes", "com.rileytestut.delta.game.nes"),
    "super nintendo":       ("snes",    "com.rileytestut.delta.game.snes"),
    "nintendo 64":          ("n64",     "com.rileytestut.delta.game.n64"),
    "nintendo ds":          ("nds",     "com.rileytestut.delta.game.ds"),
    # Sega
    "genesis":              ("genesis", "com.rileytestut.delta.game.genesis"),
    "sega genesis":         ("genesis", "com.rileytestut.delta.game.genesis"),
    "mega drive":           ("genesis", "com.rileytestut.delta.game.genesis"),
    # Unofficial / catch-all
    "unofficial":           ("unofficial", None),
}

# HTML pages on delta-skins.github.io that contain skin entries
DELTA_SKINS_PAGES = ["gba", "gbc", "nes", "snes", "n64", "nds", "unofficial"]

DELTA_SKINS_BASE = "https://raw.githubusercontent.com/delta-skins/delta-skins.github.io/master"
DELTA_SKINS_SITE_BASE = "https://delta-skins.github.io"
DELTA_SKINS_REPO_RAW = "https://github.com/delta-skins/delta-skins.github.io/raw/master"

BROANK_REPO = "Polyphian/deltaEmu"
BROANK_SYSTEMS = ["GBA", "GBC", "NDS", "N64", "SNES"]

LITRITT_REPO = "LitRitt/emuskins.litritt.com"

# Rate-limit: minimum seconds between HTTP requests
RATE_LIMIT_SECONDS = 1.0

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

_last_request_time = 0.0


def _rate_limit():
    """Enforce rate limiting between requests."""
    global _last_request_time
    now = time.time()
    elapsed = now - _last_request_time
    if elapsed < RATE_LIMIT_SECONDS:
        time.sleep(RATE_LIMIT_SECONDS - elapsed)
    _last_request_time = time.time()


def _get(url, timeout=30):
    """Perform a GET request with rate limiting. Returns response text or None."""
    _rate_limit()
    log(f"  GET {url}")
    if requests:
        try:
            resp = requests.get(url, timeout=timeout)
            resp.raise_for_status()
            return resp.text
        except requests.RequestException as e:
            log(f"  WARNING: GET failed for {url}: {e}")
            return None
    else:
        # Fallback to urllib
        import urllib.request
        import urllib.error
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Provenance-SkinScraper/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.read().decode("utf-8", errors="replace")
        except (urllib.error.URLError, urllib.error.HTTPError, OSError) as e:
            log(f"  WARNING: GET failed for {url}: {e}")
            return None


def _get_json(url, timeout=30):
    """Perform a GET request and parse JSON. Returns parsed dict/list or None."""
    text = _get(url, timeout=timeout)
    if text is None:
        return None
    try:
        return json.loads(text)
    except json.JSONDecodeError as e:
        log(f"  WARNING: JSON decode failed for {url}: {e}")
        return None


def _head_ok(url, timeout=15):
    """Check if a URL is reachable via HEAD request. Returns True/False."""
    _rate_limit()
    if requests:
        try:
            resp = requests.head(url, timeout=timeout, allow_redirects=True)
            return resp.status_code < 400
        except requests.RequestException:
            return False
    else:
        import urllib.request
        import urllib.error
        try:
            req = urllib.request.Request(url, method="HEAD",
                                         headers={"User-Agent": "Provenance-SkinScraper/1.0"})
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return resp.status < 400
        except (urllib.error.URLError, urllib.error.HTTPError, OSError):
            return False


# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

def log(msg):
    """Print progress to stderr."""
    print(msg, file=sys.stderr)


# ---------------------------------------------------------------------------
# ID generation
# ---------------------------------------------------------------------------

def make_id(source, download_url):
    """Generate a deterministic skin ID from source name + download URL."""
    key = f"{source}:{download_url}"
    h = hashlib.sha256(key.encode("utf-8")).hexdigest()[:12]
    return f"{source}-{h}"


# ---------------------------------------------------------------------------
# System lookup
# ---------------------------------------------------------------------------

def lookup_system(raw_name):
    """Map a raw system/console name to (short_code, gameTypeIdentifier).

    Returns (short_code, identifier) or (raw_name_lowered, None) if unknown.
    """
    key = raw_name.strip().lower()
    if key in SYSTEM_MAP:
        return SYSTEM_MAP[key]
    return (key, None)


# ---------------------------------------------------------------------------
# Source: delta-skins.github.io
# ---------------------------------------------------------------------------

def _parse_delta_skins_html(html_text, page_name):
    """Extract img tag attribute dicts from delta-skins HTML.

    Uses BeautifulSoup when available, falling back to stdlib html.parser.
    Returns a list of dicts (one per skin img tag with data-download).
    """
    if BeautifulSoup is not None:
        soup = BeautifulSoup(html_text, "html.parser")
        imgs = soup.find_all("img", attrs={"data-download": True})
        return [
            {k: img.get(k, "") for k in ["data-download", "data-console", "data-maker",
                                          "data-supports", "data-added", "alt", "src"]}
            for img in imgs
        ]
    else:
        extractor = _ImgDataExtractor()
        extractor.feed(html_text)
        return extractor.imgs


def scrape_delta_skins(dry_run=False):
    """Scrape delta-skins.github.io HTML pages for skin entries.

    Each page (gba.html, gbc.html, ...) contains <img> tags with data
    attributes: data-console, data-maker, data-supports, data-download,
    data-added.

    Uses BeautifulSoup when available; falls back to stdlib html.parser.
    """
    source_name = "delta-skins.github.io"
    log(f"\n=== Scraping {source_name} ===")
    if BeautifulSoup is None:
        log("  NOTE: beautifulsoup4 not found, using stdlib html.parser fallback")
    skins = []

    for page_name in DELTA_SKINS_PAGES:
        url = f"{DELTA_SKINS_BASE}/{page_name}.html"
        log(f"\nPage: {page_name}.html")

        if dry_run:
            log(f"  [DRY RUN] Would fetch {url}")
            continue

        html_text = _get(url)
        if html_text is None:
            log(f"  Skipping {page_name}.html (fetch failed)")
            continue

        img_dicts = _parse_delta_skins_html(html_text, page_name)
        log(f"  Found {len(img_dicts)} skin entries")

        for img in img_dicts:
            download_url = img.get("data-download", "").strip()
            if not download_url:
                continue

            console = (img.get("data-console") or page_name).strip()
            maker = (img.get("data-maker") or "").strip()
            supports = (img.get("data-supports") or "").strip()
            alt_text = (img.get("alt") or "").strip()
            src = (img.get("src") or "").strip()

            # Derive name from alt text, or from filename
            if alt_text:
                name = alt_text
            else:
                # Extract from download URL filename
                path = urllib.parse.urlparse(download_url).path
                name = urllib.parse.unquote(os.path.splitext(os.path.basename(path))[0])

            short_code, game_type_id = lookup_system(console)
            systems = [short_code] if short_code != "unofficial" else []

            # Build thumbnail URL using the github.io CDN (better caching than raw.githubusercontent)
            thumbnail_url = None
            if src:
                # src is relative like "gba/someimage.png"
                thumbnail_url = f"{DELTA_SKINS_SITE_BASE}/{src}"

            # Parse device support into tags
            device_support = []
            tags = []
            if supports:
                device_support = [s.strip() for s in supports.split("+")]
                if "landscape" in supports.lower():
                    tags.append("landscape")

            skin_entry = {
                "id": make_id(source_name, download_url),
                "name": name,
                "author": maker or None,
                "systems": systems,
                "gameTypeIdentifier": game_type_id,
                "version": None,
                "downloadURL": download_url,
                "thumbnailURL": thumbnail_url,
                "screenshotURLs": [],
                "tags": tags,
                "deviceSupport": device_support,
                "downloadCount": None,
                "rating": None,
                "lastUpdated": None,
                "fileSize": None,
                "source": source_name,
            }
            skins.append(skin_entry)

    log(f"\n  Total from {source_name}: {len(skins)} skins")
    return skins


# ---------------------------------------------------------------------------
# Source: Polyphian/deltaEmu (Broank skins)
# ---------------------------------------------------------------------------

def _github_api_contents(repo, path=""):
    """Fetch directory listing from GitHub API."""
    url = f"https://api.github.com/repos/{repo}/contents/{path}"
    return _get_json(url)


def scrape_broank(dry_run=False):
    """Scrape the Polyphian/deltaEmu repo for .deltaskin files.

    Structure: skins/{SYSTEM}/{filename}.deltaskin
    Also checks subdirectories like skins/{SYSTEM}/N/ and skins/{SYSTEM}/DI/
    """
    source_name = "broank-deltaemu"
    log(f"\n=== Scraping {source_name} ({BROANK_REPO}) ===")
    skins = []

    for system_dir in BROANK_SYSTEMS:
        log(f"\nSystem: {system_dir}")

        if dry_run:
            log(f"  [DRY RUN] Would list skins/{system_dir}/ from {BROANK_REPO}")
            continue

        entries = _github_api_contents(BROANK_REPO, f"skins/{system_dir}")
        if entries is None:
            log(f"  Skipping {system_dir} (API request failed)")
            continue

        # Collect .deltaskin files from this directory and subdirectories
        deltaskin_files = []
        subdirs = []

        for entry in entries:
            if entry.get("type") == "file" and entry.get("name", "").endswith(".deltaskin"):
                deltaskin_files.append(entry)
            elif entry.get("type") == "dir" and entry.get("name") not in (".DS_Store", "previews"):
                subdirs.append(entry.get("path", ""))

        # Check subdirectories for more .deltaskin files
        for subdir_path in subdirs:
            sub_entries = _github_api_contents(BROANK_REPO, subdir_path)
            if sub_entries is None:
                continue
            for entry in sub_entries:
                if entry.get("type") == "file" and entry.get("name", "").endswith(".deltaskin"):
                    deltaskin_files.append(entry)

        log(f"  Found {len(deltaskin_files)} .deltaskin files")

        short_code, game_type_id = lookup_system(system_dir)

        for entry in deltaskin_files:
            filename = entry.get("name", "")
            file_path = entry.get("path", "")
            file_size = entry.get("size")
            download_url = entry.get("download_url", "")

            if not download_url:
                # Construct download URL
                download_url = f"https://github.com/{BROANK_REPO}/raw/main/{file_path}"

            name = os.path.splitext(filename)[0]

            skin_entry = {
                "id": make_id(source_name, download_url),
                "name": name,
                "author": "Broank",
                "systems": [short_code],
                "gameTypeIdentifier": game_type_id,
                "version": None,
                "downloadURL": download_url,
                "thumbnailURL": None,
                "screenshotURLs": [],
                "tags": [],
                "deviceSupport": [],
                "downloadCount": None,
                "rating": None,
                "lastUpdated": None,
                "fileSize": file_size,
                "source": source_name,
            }
            skins.append(skin_entry)

    log(f"\n  Total from {source_name}: {len(skins)} skins")
    return skins


# ---------------------------------------------------------------------------
# Source: LitRitt/emuskins.litritt.com
# ---------------------------------------------------------------------------

# Map LitRitt skin family names to likely system codes
LITRITT_SKIN_SYSTEM_HINTS = {
    "GBA-SP":       "gba",
    "Litboy-Color": "gbc",
    "iDS":          "nds",
    "Lit-CC":       "gbc",
    "Ignited":      None,   # multi-system, detect from variant name
}


def scrape_litritt(dry_run=False):
    """Scrape the LitRitt/emuskins.litritt.com repo for .deltaskin files.

    Structure: Skins/LitRitt/{SkinFamily}/{Variant}/skin.deltaskin
    Also checks Skins/Hosted/ for community-hosted skins.
    """
    source_name = "litritt-emuskins"
    log(f"\n=== Scraping {source_name} ({LITRITT_REPO}) ===")
    skins = []

    if dry_run:
        log("  [DRY RUN] Would list Skins/LitRitt/ and Skins/Hosted/ from repo")
        return skins

    # --- Scrape Skins/LitRitt/ ---
    log("\nLitRitt skins:")
    families = _github_api_contents(LITRITT_REPO, "Skins/LitRitt")
    if families is None:
        log("  Could not list Skins/LitRitt/")
    else:
        for family_entry in families:
            if family_entry.get("type") != "dir":
                continue

            family_name = family_entry.get("name", "")
            family_path = family_entry.get("path", "")
            log(f"  Family: {family_name}")

            # List variants within the family
            variants = _github_api_contents(LITRITT_REPO, family_path)
            if variants is None:
                continue

            for variant_entry in variants:
                if variant_entry.get("type") != "dir":
                    continue

                variant_name = variant_entry.get("name", "")
                variant_path = variant_entry.get("path", "")

                # Check for skin.deltaskin in variant dir
                variant_contents = _github_api_contents(LITRITT_REPO, variant_path)
                if variant_contents is None:
                    continue

                for file_entry in variant_contents:
                    if file_entry.get("name", "").endswith(".deltaskin"):
                        download_url = file_entry.get("download_url", "")
                        if not download_url:
                            file_p = file_entry.get("path", "")
                            download_url = f"https://github.com/{LITRITT_REPO}/raw/main/{file_p}"

                        file_size = file_entry.get("size")

                        # Determine system
                        hint = LITRITT_SKIN_SYSTEM_HINTS.get(family_name)
                        if hint:
                            short_code, game_type_id = lookup_system(hint)
                        else:
                            # Try to guess from variant name
                            short_code, game_type_id = lookup_system(variant_name)

                        display_name = f"{family_name} {variant_name}"

                        skin_entry = {
                            "id": make_id(source_name, download_url),
                            "name": display_name,
                            "author": "LitRitt",
                            "systems": [short_code] if game_type_id else [],
                            "gameTypeIdentifier": game_type_id,
                            "version": None,
                            "downloadURL": download_url,
                            "thumbnailURL": None,
                            "screenshotURLs": [],
                            "tags": [],
                            "deviceSupport": [],
                            "downloadCount": None,
                            "rating": None,
                            "lastUpdated": None,
                            "fileSize": file_size,
                            "source": source_name,
                        }
                        skins.append(skin_entry)

    # --- Scrape Skins/Hosted/ ---
    log("\nHosted skins:")
    hosted = _github_api_contents(LITRITT_REPO, "Skins/Hosted")
    if hosted is None:
        log("  Could not list Skins/Hosted/")
    else:
        for hosted_entry in hosted:
            if hosted_entry.get("type") != "dir":
                continue

            system_name = hosted_entry.get("name", "")
            system_path = hosted_entry.get("path", "")
            log(f"  Hosted system: {system_name}")

            # List authors/skins within hosted system
            _scrape_litritt_hosted_dir(system_name, system_path, source_name, skins)

    log(f"\n  Total from {source_name}: {len(skins)} skins")
    return skins


def _scrape_litritt_hosted_dir(system_name, system_path, source_name, skins):
    """Recursively find .deltaskin files under a hosted system directory."""
    entries = _github_api_contents(LITRITT_REPO, system_path)
    if entries is None:
        return

    for entry in entries:
        if entry.get("type") == "file" and entry.get("name", "").endswith(".deltaskin"):
            download_url = entry.get("download_url", "")
            if not download_url:
                file_p = entry.get("path", "")
                download_url = f"https://github.com/{LITRITT_REPO}/raw/main/{file_p}"

            file_size = entry.get("size")
            name = os.path.splitext(entry.get("name", ""))[0]

            short_code, game_type_id = lookup_system(system_name)

            skin_entry = {
                "id": make_id(source_name, download_url),
                "name": name,
                "author": None,
                "systems": [short_code] if game_type_id else [],
                "gameTypeIdentifier": game_type_id,
                "version": None,
                "downloadURL": download_url,
                "thumbnailURL": None,
                "screenshotURLs": [],
                "tags": [],
                "deviceSupport": [],
                "downloadCount": None,
                "rating": None,
                "lastUpdated": None,
                "fileSize": file_size,
                "source": source_name,
            }
            skins.append(skin_entry)

        elif entry.get("type") == "dir":
            _scrape_litritt_hosted_dir(
                system_name, entry.get("path", ""), source_name, skins
            )


# ---------------------------------------------------------------------------
# Deduplication & validation
# ---------------------------------------------------------------------------

def dedup_skins(skins):
    """Deduplicate skins by download URL, keeping the first occurrence."""
    seen_urls = set()
    unique = []
    dupes = 0
    for skin in skins:
        url = skin.get("downloadURL", "")
        if url in seen_urls:
            dupes += 1
            continue
        seen_urls.add(url)
        unique.append(skin)
    if dupes:
        log(f"\nRemoved {dupes} duplicate entries (by download URL)")
    return unique


def validate_urls(skins, max_checks=None):
    """Validate download URLs via HEAD requests.

    Returns (valid_skins, broken_count).
    Broken skins are kept but logged as warnings.
    """
    log("\n=== Validating download URLs ===")
    broken = 0
    checked = 0

    for skin in skins:
        url = skin.get("downloadURL", "")
        if not url:
            continue

        if max_checks is not None and checked >= max_checks:
            log(f"  Reached max checks ({max_checks}), stopping validation")
            break

        checked += 1
        if not _head_ok(url):
            log(f"  BROKEN: {skin['name']} -> {url}")
            broken += 1

    log(f"\n  Checked {checked} URLs, {broken} broken")
    return skins, broken


# ---------------------------------------------------------------------------
# Catalog I/O
# ---------------------------------------------------------------------------

def build_catalog(skins):
    """Build the final catalog dict."""
    return {
        "version": CATALOG_VERSION,
        "lastUpdated": datetime.now(timezone.utc).isoformat(),
        "skins": skins,
    }


def write_catalog(catalog, output_path=None):
    """Write catalog JSON to file or stdout."""
    json_str = json.dumps(catalog, indent=2, ensure_ascii=False)

    if output_path:
        output_dir = os.path.dirname(output_path)
        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(json_str)
            f.write("\n")
        log(f"\nWrote catalog to {output_path}")
        log(f"  {len(catalog['skins'])} skins, {os.path.getsize(output_path)} bytes")
    else:
        print(json_str)


def load_catalog(path):
    """Load an existing catalog.json file."""
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Validate command
# ---------------------------------------------------------------------------

def cmd_validate(catalog_path):
    """Validate an existing catalog.json for broken links."""
    log(f"Loading catalog from {catalog_path}")
    catalog = load_catalog(catalog_path)

    skins = catalog.get("skins", [])
    log(f"Catalog version: {catalog.get('version')}")
    log(f"Last updated: {catalog.get('lastUpdated')}")
    log(f"Total skins: {len(skins)}")

    # Check schema fields
    required_fields = [
        "id", "name", "systems", "downloadURL", "source",
    ]
    schema_errors = 0
    for i, skin in enumerate(skins):
        for field in required_fields:
            if field not in skin:
                log(f"  SCHEMA ERROR: skin[{i}] missing field '{field}'")
                schema_errors += 1

    if schema_errors:
        log(f"\n  {schema_errors} schema errors found")

    # Validate URLs
    broken = 0
    checked = 0
    for skin in skins:
        url = skin.get("downloadURL", "")
        if not url:
            continue

        checked += 1
        if not _head_ok(url):
            log(f"  BROKEN: {skin.get('name', '?')} -> {url}")
            broken += 1

    log(f"\n  Checked {checked} download URLs")
    log(f"  Broken: {broken}")
    log(f"  Valid: {checked - broken}")

    if broken > 0:
        sys.exit(1)
    else:
        log("\nAll URLs are valid.")


# ---------------------------------------------------------------------------
# Source dispatch
# ---------------------------------------------------------------------------

SOURCE_SCRAPERS = {
    "delta-skins": scrape_delta_skins,
    "broank":      scrape_broank,
    "litritt":     scrape_litritt,
}

VALID_SOURCES = list(SOURCE_SCRAPERS.keys()) + ["all"]


def run_scrapers(source, dry_run=False, skip_validation=False):
    """Run selected scrapers and return the combined catalog."""
    all_skins = []

    if source == "all":
        scrapers = list(SOURCE_SCRAPERS.values())
    else:
        if source not in SOURCE_SCRAPERS:
            log(f"ERROR: Unknown source '{source}'. Valid: {', '.join(VALID_SOURCES)}")
            sys.exit(1)
        scrapers = [SOURCE_SCRAPERS[source]]

    for scraper in scrapers:
        skins = scraper(dry_run=dry_run)
        all_skins.extend(skins)

    if dry_run:
        log(f"\n[DRY RUN] Would have scraped sources. No requests made.")
        return build_catalog([])

    # Dedup
    all_skins = dedup_skins(all_skins)

    # Validate URLs unless skipped
    if not skip_validation:
        all_skins, broken = validate_urls(all_skins)

    log(f"\n=== Final catalog: {len(all_skins)} skins ===")
    return build_catalog(all_skins)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Scrape community Delta skin sites and generate catalog.json",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 Scripts/scrape_skin_catalog.py --output catalog.json
  python3 Scripts/scrape_skin_catalog.py --source delta-skins --output catalog.json
  python3 Scripts/scrape_skin_catalog.py --source all --output catalog.json
  python3 Scripts/scrape_skin_catalog.py --validate catalog.json
  python3 Scripts/scrape_skin_catalog.py --validate-urls --output catalog.json
  python3 Scripts/scrape_skin_catalog.py --dry-run --source all

Quickstart (no extra packages needed):
  python3 Scripts/scrape_skin_catalog.py --output Scripts/catalog_seed.json
  cp Scripts/catalog_seed.json PVUI/Sources/PVUIBase/Resources/catalog_seed.json
        """,
    )

    parser.add_argument(
        "--output", "-o",
        help="Output file path (default: stdout)",
    )
    parser.add_argument(
        "--source", "-s",
        default="all",
        choices=VALID_SOURCES,
        help="Which source to scrape (default: all)",
    )
    parser.add_argument(
        "--validate",
        metavar="CATALOG",
        help="Validate an existing catalog.json for broken links",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be scraped without making requests",
    )
    parser.add_argument(
        "--skip-validation",
        action="store_true",
        default=True,
        help="Skip URL validation step (default: True; use --validate-urls to enable)",
    )
    parser.add_argument(
        "--validate-urls",
        action="store_true",
        help="Enable download URL HEAD-check validation (slow; checks every skin URL)",
    )

    args = parser.parse_args()

    # --validate-urls overrides --skip-validation
    if args.validate_urls:
        args.skip_validation = False

    # Validate mode
    if args.validate:
        cmd_validate(args.validate)
        return

    # Check dependencies
    if not args.dry_run:
        if requests is None:
            log("WARNING: 'requests' package not found, using urllib fallback")
        if BeautifulSoup is None and args.source in ("delta-skins", "all"):
            log("  NOTE: beautifulsoup4 not found; using stdlib html.parser fallback for delta-skins")

    # Run scrapers
    catalog = run_scrapers(
        source=args.source,
        dry_run=args.dry_run,
        skip_validation=args.skip_validation,
    )

    # Write output
    if not args.dry_run:
        write_catalog(catalog, args.output)
    else:
        log("\n[DRY RUN] No output written.")


if __name__ == "__main__":
    main()
