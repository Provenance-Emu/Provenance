#!/usr/bin/env python3
"""Unit tests for check_shipping_vs_dev (shipping pbxproj vs Tuist CoreProduct rows)."""

import importlib.util
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parents[1] / "audits" / "check_shipping_vs_dev.py"
_spec = importlib.util.spec_from_file_location("check_shipping_vs_dev", _SCRIPT)
_mod = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(_mod)
check = _mod.check

CORE_PRODUCT = '''
    static let stella = CoreProduct(id: "stella", link: .package(path: "Cores/Stella", product: "PVStella-Dynamic"))
    static let mupen = CoreProduct(
        id: "mupen64plus",
        link: .package(path: "Cores/Mupen64Plus", product: "PVMupenGameCore-Dynamic"),
        embeds: [
            .package(path: "Cores/Mupen64Plus", product: "PVRSPCXD4-Dynamic")
        ]
    )
    static let azahar = CoreProduct(id: "azahar", link: .package(path: "Cores/Azahar", product: "PVAzahar-Dynamic"))
    static let cheevos = CoreProduct(id: "pvcheevos", link: .package(path: "PVCheevos", product: "PVCheevos"))
'''

PBXPROJ = '''
		A1 /* XCLocalSwiftPackageReference "Cores/Stella" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = Cores/Stella;
		};
		A2 /* XCLocalSwiftPackageReference "Cores/Mupen64Plus" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = Cores/Mupen64Plus;
		};
		A3 = { isa = XCLocalSwiftPackageReference; relativePath = "Cores/VisualBoyAdvance-M"; };
		B1 /* PVStella-Dynamic */ = {
			isa = XCSwiftPackageProductDependency;
			productName = "PVStella-Dynamic";
		};
		B2 = { isa = XCSwiftPackageProductDependency; productName = "PVMupenGameCore-Dynamic"; };
		B3 = { isa = XCSwiftPackageProductDependency; productName = "PVRSPCXD4-Dynamic"; };
		B4 = { isa = XCSwiftPackageProductDependency; productName = "PVVisualBoyAdvance-Dynamic"; };
'''


class CheckShippingVsDevTests(unittest.TestCase):
    def test_agreeing_files_pass(self):
        self.assertEqual(check(CORE_PRODUCT, PBXPROJ), [])

    def test_dev_row_missing_from_shipping(self):
        rows = CORE_PRODUCT + '\n    static let x = CoreProduct(id: "x", link: .package(path: "Cores/NewCore", product: "PVNew-Dynamic"))\n'
        problems = check(rows, PBXPROJ)
        self.assertEqual(len(problems), 1)
        self.assertIn("Cores/NewCore", problems[0])

    def test_product_renamed_on_one_side(self):
        pbx = PBXPROJ.replace('productName = "PVRSPCXD4-Dynamic"', 'productName = "PVRSPCXD4"')
        problems = check(CORE_PRODUCT, pbx)
        self.assertEqual(len(problems), 1)
        self.assertIn("PVRSPCXD4-Dynamic", problems[0])

    def test_shipping_package_without_dev_row(self):
        pbx = PBXPROJ + '\n		A9 = { isa = XCLocalSwiftPackageReference; relativePath = Cores/Orphan; };\n'
        problems = check(CORE_PRODUCT, pbx)
        self.assertEqual(len(problems), 1)
        self.assertIn("Cores/Orphan", problems[0])

    def test_removed_dev_row_is_drift(self):
        rows = CORE_PRODUCT.replace('link: .package(path: "Cores/Stella", product: "PVStella-Dynamic")', 'link: .prebuilt(path: "x")')
        problems = check(rows, PBXPROJ)
        self.assertEqual(len(problems), 1)
        self.assertIn("Cores/Stella", problems[0])

    def test_stale_exception_is_reported(self):
        pbx = PBXPROJ + '\n		A8 = { isa = XCLocalSwiftPackageReference; relativePath = Cores/Azahar; };\n		B8 = { isa = XCSwiftPackageProductDependency; productName = "PVAzahar-Dynamic"; };\n'
        problems = check(CORE_PRODUCT, pbx)
        self.assertEqual(len(problems), 1)
        self.assertIn("SHIPPING_EXCEPTIONS", problems[0])

    def test_non_core_rows_are_ignored(self):
        rows = CORE_PRODUCT + '\n    static let y = CoreProduct(id: "y", link: .package(path: "PVSomething", product: "PVSomething"))\n'
        self.assertEqual(check(rows, PBXPROJ), [])


if __name__ == "__main__":
    unittest.main()
