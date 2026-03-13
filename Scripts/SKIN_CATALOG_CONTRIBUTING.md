# Skin Catalog Contribution Guide

This guide explains how to add new skins to the Provenance skin catalog so they appear in the **Skin Browser** (Settings → Skins → Browse Catalog).

---

## Table of Contents

1. [Overview](#overview)
2. [Catalog JSON Schema](#catalog-json-schema)
3. [Option A: Auto-generate via Scraper](#option-a-auto-generate-via-scraper)
4. [Option B: Add a Skin Manually](#option-b-add-a-skin-manually)
5. [Deploying Changes](#deploying-changes)
6. [PR Guidelines](#pr-guidelines)
7. [Supported Systems](#supported-systems)

---

## Overview

The skin catalog is a JSON file that lists community-created `.deltaskin` and `.manicskin` files compatible with the Provenance emulator. It is stored in two locations:

| File | Purpose |
|------|---------|
| `Scripts/catalog_seed.json` | Source of truth — edited by contributors |
| `PVUI/Sources/PVUIBase/Resources/catalog_seed.json` | Bundled copy — loaded by the app at runtime |

Both files must be kept in sync (see [Deploying Changes](#deploying-changes)).

The scraper (`Scripts/scrape_skin_catalog.py`) crawls several community skin repositories and regenerates `catalog_seed.json` automatically. You can also add entries by hand.

---

## Catalog JSON Schema

The top-level catalog object:

```json
{
  "version": 1,
  "lastUpdated": "2026-01-01T00:00:00Z",
  "skins": [ ... ]
}
```

Each entry in `"skins"` is an object with the following fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | **Yes** | 16-character hex identifier. Generate with `sha256("source:downloadURL")[:16]`. Must be unique across the catalog. |
| `name` | string | **Yes** | Display name shown in the Skin Browser (e.g. `"Dark Mode GBA"`). |
| `author` | string or null | No | Skin creator's name or handle. |
| `systems` | string array | **Yes** | Short system codes (e.g. `["gba"]`). See [Supported Systems](#supported-systems). |
| `gameTypeIdentifier` | string or null | No | Delta-compatible game type identifier (e.g. `"com.rileytestut.delta.game.gba"`). |
| `version` | string or null | No | Skin version string, if available. |
| `downloadURL` | string | **Yes** | Direct download URL for the `.deltaskin` or `.manicskin` file. Must be publicly accessible. |
| `thumbnailURL` | string or null | No | URL to a preview image (JPEG or PNG). Displayed in the skin browser grid. |
| `screenshotURLs` | string array | No | Additional in-use screenshot URLs. |
| `tags` | string array | No | Optional tags such as `"landscape"`, `"dark"`, `"minimal"`. |
| `deviceSupport` | string array | No | Device hints, e.g. `["iphone-x", "iphone-legacy"]`. |
| `downloadCount` | number or null | No | Download count, if known from source. |
| `rating` | number or null | No | Rating from 0.0–5.0, if known from source. |
| `lastUpdated` | string or null | No | ISO 8601 date when the skin file was last updated. |
| `fileSize` | number or null | No | File size in bytes, if known. |
| `source` | string | **Yes** | Short source identifier (e.g. `"delta-skins.github.io"`, `"manual"`). |

### Minimal valid entry

```json
{
  "id": "a1b2c3d4e5f60718",
  "name": "My Awesome GBA Skin",
  "author": "yourname",
  "systems": ["gba"],
  "gameTypeIdentifier": "com.rileytestut.delta.game.gba",
  "version": null,
  "downloadURL": "https://github.com/yourname/skins/raw/main/MyAwesomeGBA.deltaskin",
  "thumbnailURL": null,
  "screenshotURLs": [],
  "tags": [],
  "deviceSupport": [],
  "downloadCount": null,
  "rating": null,
  "lastUpdated": null,
  "fileSize": null,
  "source": "manual"
}
```

---

## Option A: Auto-generate via Scraper

The easiest way to refresh the catalog with all known community skins is to run the bundled scraper script.

### Prerequisites

```bash
pip install -r Scripts/requirements-scraper.txt
```

The script also works without extra packages using stdlib fallbacks (slower HTML parsing for the `delta-skins` source):

```bash
python3 Scripts/scrape_skin_catalog.py --help
```

### Run the scraper

```bash
# Scrape all sources and write to Scripts/catalog_seed.json
python3 Scripts/scrape_skin_catalog.py \
    --source all \
    --output Scripts/catalog_seed.json

# Copy to the bundled app resources
cp Scripts/catalog_seed.json \
    PVUI/Sources/PVUIBase/Resources/catalog_seed.json
```

Providing a GitHub token avoids the 60 req/hr anonymous API rate limit when scraping GitHub-hosted sources:

```bash
export GITHUB_TOKEN="ghp_your_token_here"
python3 Scripts/scrape_skin_catalog.py --source all --output Scripts/catalog_seed.json
```

### Dry-run (no network requests)

```bash
python3 Scripts/scrape_skin_catalog.py --dry-run --source all
```

### Validate an existing catalog

```bash
# Validate schema and check for broken download URLs
python3 Scripts/scrape_skin_catalog.py --validate Scripts/catalog_seed.json
```

### Scrape a specific source only

```bash
# Supported: delta-skins, broank, litritt
python3 Scripts/scrape_skin_catalog.py --source delta-skins --output Scripts/catalog_seed.json
```

### Adding a new scraper source

To add support for a new community skin host, add a new scraper function to `Scripts/scrape_skin_catalog.py` and register it in the `SOURCE_SCRAPERS` dictionary at the bottom of the file.

---

## Option B: Add a Skin Manually

Use this approach to add a single skin from any publicly accessible URL.

### Step 1: Generate a unique ID

**Python (recommended):**

```python
import hashlib
source = "manual"
download_url = "https://example.com/MySkin.deltaskin"
skin_id = hashlib.sha256(f"{source}:{download_url}".encode()).hexdigest()[:16]
print(skin_id)
```

**Shell:**

```bash
printf 'manual:https://example.com/MySkin.deltaskin' | shasum -a 256 | cut -c1-16
```

### Step 2: Edit catalog_seed.json

Open `Scripts/catalog_seed.json` and add a new entry to the `"skins"` array. Required fields are `id`, `name`, `systems`, `downloadURL`, and `source`.

Make sure to place a comma between entries. Keep the array sorted by system code, then by name, for readability.

### Step 3: Validate JSON

```bash
python3 -m json.tool Scripts/catalog_seed.json > /dev/null && echo "Valid JSON"
```

### Step 4: Sync to app resources

```bash
cp Scripts/catalog_seed.json \
    PVUI/Sources/PVUIBase/Resources/catalog_seed.json
```

---

## Deploying Changes

After updating either file (via scraper or manual edit), always sync both:

```bash
cp Scripts/catalog_seed.json \
    PVUI/Sources/PVUIBase/Resources/catalog_seed.json
```

Commit **both files** together in your PR.

---

## PR Guidelines

1. **Target the `develop` branch.**
2. **Commit both files:** `Scripts/catalog_seed.json` and `PVUI/Sources/PVUIBase/Resources/catalog_seed.json`.
3. **PR title format:**
   - Single skin: `feat(skins): add "Skin Name" to catalog`
   - Bulk refresh: `chore(skins): refresh skin catalog from scraper`
4. **Verify the download URL** is publicly accessible before submitting — paste the URL into a browser and confirm the file downloads.
5. **Include a thumbnail URL** when possible so users can preview the skin in the browser grid.
6. **One skin per PR** for manual additions. Bulk scraper refreshes are fine in a single PR.
7. **Check for duplicates:** search `Scripts/catalog_seed.json` for the skin's `downloadURL` before adding.

---

## Supported Systems

The following system short codes are recognised by the catalog and the Provenance skin browser:

| Short Code | System | `gameTypeIdentifier` |
|-----------|--------|----------------------|
| `gba` | Game Boy Advance | `com.rileytestut.delta.game.gba` |
| `gbc` | Game Boy Color / Game Boy | `com.rileytestut.delta.game.gbc` |
| `nes` | Nintendo Entertainment System | `com.rileytestut.delta.game.nes` |
| `snes` | Super Nintendo | `com.rileytestut.delta.game.snes` |
| `n64` | Nintendo 64 | `com.rileytestut.delta.game.n64` |
| `nds` | Nintendo DS | `com.rileytestut.delta.game.ds` |
| `genesis` | Sega Genesis / Mega Drive | `com.rileytestut.delta.game.genesis` |
| `unofficial` | Multi-system / other | *(none)* |

To add support for a new system, update the `SYSTEM_MAP` dictionary in `Scripts/scrape_skin_catalog.py`.

---

## Questions?

Open a GitHub issue in the [Provenance-Emu/Provenance](https://github.com/Provenance-Emu/Provenance/issues) repository.
