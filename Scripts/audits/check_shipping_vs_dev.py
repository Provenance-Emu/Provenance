#!/usr/bin/env python3
"""Keep the shipping Xcode project and the Tuist dev workspace on the same core packages.

Until Tuist generates the shipping project (design doc 2026-10-13, phase 6), two
files describe which core packages an app links:

* `Tuist/ProjectDescriptionHelpers/CoreProduct.swift` — the dev workspace's rows
  (`.package(path:product:)`), one per audited core plus the non-core products.
* `Provenance.xcodeproj/project.pbxproj` — the shipping project's
  `XCLocalSwiftPackageReference` paths and `XCSwiftPackageProductDependency`
  product names.

They drift silently: a core converted to a package on one side but not the
other, a product renamed in one place, a row deleted from the dev table while
the shipping app still links it. This check fails when:

1. a dev `.package` row under `Cores/` is not referenced by the shipping project
   (path and product), unless it is a documented shipping exception;
2. a shipping `Cores/<X>` package reference has no dev row, unless the core is a
   documented deprecated/legacy core the dev workspace deliberately omits.

Usage: check_shipping_vs_dev.py [--repo ROOT] [--core-product FILE] [--pbxproj FILE]
Exit 1 on drift. Runs on Linux (plain text parsing, no Xcode).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
CORE_PRODUCT = REPO_ROOT / "Tuist/ProjectDescriptionHelpers/CoreProduct.swift"
PBXPROJ = REPO_ROOT / "Provenance.xcodeproj/project.pbxproj"

# Dev rows the shipping project consumes some other way. Keep each with a reason
# and remove the entry when the shipping project switches to the package.
SHIPPING_EXCEPTIONS: dict[str, str] = {
    "Cores/Azahar": "shipping links PVAzahar.xcodeproj + BuildPVlibAzahar (2026-10-12 decision)",
    "Cores/Dolphin": "shipping links PVDolphin.xcodeproj + Make XCFrameworks (2026-10-12 decision)",
}

# Shipping-only core packages the dev workspace omits on purpose. Deprecated cores
# ship for 3.3.x save-state compatibility (CLAUDE.md core taxonomy); 4DO is an
# UNSURE audit row (docs/superpowers/specs/2026-10-10-core-audit.md).
DEV_EXCEPTIONS: dict[str, str] = {
    "Cores/4DO": "UNSURE audit row; native-only 3DO with cheevos",
    "Cores/Atari800": "deprecated core (PVCore.deprecatedCores)",
    "Cores/Bliss": "deprecated core (PVCore.deprecatedCores)",
    "Cores/CrabEMU": "deprecated core (PVCore.deprecatedCores)",
    "Cores/Gambatte": "deprecated core (PVCore.deprecatedCores)",
    "Cores/VisualBoyAdvance-M": "deprecated core (PVCore.deprecatedCores)",
}

PACKAGE_ROW = re.compile(r'\.package\(\s*path:\s*"([^"]+)"\s*,\s*product:\s*"([^"]+)"\s*\)')
LOCAL_REF = re.compile(r'isa = XCLocalSwiftPackageReference;.*?relativePath = ("?)([^";]+)\1;', re.S)
PRODUCT_DEP = re.compile(r'isa = XCSwiftPackageProductDependency;.*?productName = ("?)([^";]+)\1;', re.S)


def dev_rows(text: str) -> set[tuple[str, str]]:
    """(path, product) for every `.package(path:product:)` in CoreProduct.swift."""
    return {(p.rstrip("/"), prod) for p, prod in PACKAGE_ROW.findall(text)}


def shipping_refs(text: str) -> tuple[set[str], set[str]]:
    """(local package paths, product names) declared in a pbxproj."""
    paths = {m.group(2).rstrip("/") for m in LOCAL_REF.finditer(text)}
    products = {m.group(2) for m in PRODUCT_DEP.finditer(text)}
    return paths, products


def check(core_product_text: str, pbxproj_text: str) -> list[str]:
    """Drift lines, empty when the two files agree."""
    rows = dev_rows(core_product_text)
    paths, products = shipping_refs(pbxproj_text)
    problems: list[str] = []

    for path, product in sorted(rows):
        if not path.startswith("Cores/") or path in SHIPPING_EXCEPTIONS:
            continue
        if path not in paths:
            problems.append(f"dev row {path} ({product}) has no XCLocalSwiftPackageReference in the shipping project")
        elif product not in products:
            problems.append(f"shipping project references {path} but not its dev product {product}")

    dev_paths = {p for p, _ in rows}
    for path in sorted(paths):
        if path.startswith("Cores/") and path not in dev_paths and path not in DEV_EXCEPTIONS:
            problems.append(f"shipping package {path} has no CoreProduct row (add one, or list it in DEV_EXCEPTIONS with a reason)")

    for path in sorted(SHIPPING_EXCEPTIONS):
        if path in paths:
            problems.append(f"{path} is in SHIPPING_EXCEPTIONS but the shipping project now references the package; drop the exception")
    for path in sorted(DEV_EXCEPTIONS):
        if path in dev_paths:
            problems.append(f"{path} is in DEV_EXCEPTIONS but CoreProduct.swift now has a row; drop the exception")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--core-product", type=Path, default=CORE_PRODUCT)
    ap.add_argument("--pbxproj", type=Path, default=PBXPROJ)
    args = ap.parse_args()
    try:
        problems = check(args.core_product.read_text(), args.pbxproj.read_text())
    except OSError as error:
        print(f"check_shipping_vs_dev: {error}", file=sys.stderr)
        return 2
    rows = len(dev_rows(args.core_product.read_text()))
    if problems:
        print(f"shipping ↔ dev drift ({len(problems)}):")
        for p in problems:
            print(f"  - {p}")
        return 1
    print(f"shipping ↔ dev: {rows} dev package rows agree with {args.pbxproj.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
