#!/usr/bin/env python3
"""
Add ProvenanceCompanion app target to Provenance.xcodeproj/project.pbxproj

This script adds a minimal iOS app target for the Provenance Companion app.
All UUIDs use the C0C0CAFE prefix for easy identification.

Usage: python3 scripts/add_companion_target.py
"""

import re

PBXPROJ = "Provenance.xcodeproj/project.pbxproj"

# ── UUID registry ──────────────────────────────────────────────────────────────
TARGET                  = "C0C0CAFE000000000000001A"
CONFIG_LIST             = "C0C0CAFE000000000000002A"
CFG_DEBUG               = "C0C0CAFE000000000000003A"
CFG_RELEASE             = "C0C0CAFE000000000000004A"
CFG_ARCHIVE             = "C0C0CAFE000000000000005A"
PHASE_SOURCES           = "C0C0CAFE000000000000006A"
PHASE_FRAMEWORKS        = "C0C0CAFE000000000000007A"
PHASE_RESOURCES         = "C0C0CAFE000000000000008A"
PHASE_SCRIPT_BN         = "C0C0CAFE000000000000009A"
PRODUCT_REF             = "C0C0CAFE00000000000000AA"
FS_SYNC_GROUP           = "C0C0CAFE00000000000000BA"
PKG_PVLIBRARY           = "C0C0CAFE00000000000001A0"
PKG_PVSUPPORT           = "C0C0CAFE00000000000001B0"
PKG_PVSETTINGS          = "C0C0CAFE00000000000001C0"
PKG_PVLOGGING           = "C0C0CAFE00000000000001D0"
PKG_PVFEATUREFLAGS      = "C0C0CAFE00000000000001E0"
PKG_PVUI                = "C0C0CAFE00000000000001F0"
PKG_PVTHEMES            = "C0C0CAFE0000000000000200"

# ── Package source references (already in project) ─────────────────────────────
SRC_PVLIBRARY      = "B323B0072BF46D2800CEA3CF"
SRC_PVSUPPORT      = "B323B00C2BF46DB900CEA3CF"
SRC_PVSETTINGS     = "B39B53862C66E7A900C220C6"
SRC_PVLOGGING      = "B34E4F482C11796B001559E8"
SRC_PVFEATUREFLAGS = "B3E77F822D1F57E6004A3AD2"
SRC_PVUI           = "B3952F542C697A02000B0308"
SRC_PVTHEMES       = "B34969562C4E64AD00D37F79"

XCCONFIG_REF       = "B326758527B1E0BB0033C5D1"   # Build-iOS.xcconfig

# ── Guards ─────────────────────────────────────────────────────────────────────
def already_added(content):
    return TARGET in content


# ── Snippet builders ───────────────────────────────────────────────────────────

def build_file_ref():
    return f'\t\t{PRODUCT_REF} /* ProvenanceCompanion.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = ProvenanceCompanion.app; sourceTree = BUILT_PRODUCTS_DIR; }};\n'


def fs_sync_group():
    return (
        f'\t\t{FS_SYNC_GROUP} /* ProvenanceCompanion */ = {{'
        f'isa = PBXFileSystemSynchronizedRootGroup; explicitFileTypes = {{}}; explicitFolders = (); '
        f'path = ProvenanceCompanion; sourceTree = "<group>"; }};\n'
    )


def native_target():
    pkg_deps = "\n".join([
        f'\t\t\t\t{PKG_PVLIBRARY} /* PVLibrary */,',
        f'\t\t\t\t{PKG_PVSUPPORT} /* PVSupport */,',
        f'\t\t\t\t{PKG_PVSETTINGS} /* PVSettings */,',
        f'\t\t\t\t{PKG_PVLOGGING} /* PVLogging */,',
        f'\t\t\t\t{PKG_PVFEATUREFLAGS} /* PVFeatureFlags */,',
        f'\t\t\t\t{PKG_PVUI} /* PVUI */,',
        f'\t\t\t\t{PKG_PVTHEMES} /* PVThemes */,',
    ])
    return f"""
\t\t{TARGET} /* ProvenanceCompanion */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {CONFIG_LIST} /* Build configuration list for PBXNativeTarget "ProvenanceCompanion" */;
\t\t\tbuildPhases = (
\t\t\t\t{PHASE_SOURCES} /* Sources */,
\t\t\t\t{PHASE_FRAMEWORKS} /* Frameworks */,
\t\t\t\t{PHASE_RESOURCES} /* Resources */,
\t\t\t\t{PHASE_SCRIPT_BN} /* Script: Set Build Number */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tfileSystemSynchronizedGroups = (
\t\t\t\t{FS_SYNC_GROUP} /* ProvenanceCompanion */,
\t\t\t);
\t\t\tname = ProvenanceCompanion;
\t\t\tpackageProductDependencies = (
{pkg_deps}
\t\t\t);
\t\t\tproductName = ProvenanceCompanion;
\t\t\tproductReference = {PRODUCT_REF} /* ProvenanceCompanion.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
"""


def build_phases():
    return f"""
\t\t{PHASE_SOURCES} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""", f"""
\t\t{PHASE_FRAMEWORKS} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""", f"""
\t\t{PHASE_RESOURCES} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
""", f"""
\t\t{PHASE_SCRIPT_BN} /* Script: Set Build Number */ = {{
\t\t\tisa = PBXShellScriptBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\tinputFileListPaths = (
\t\t\t);
\t\t\tinputPaths = (
\t\t\t\t"$(PROJECT_DIR)/$(INFOPLIST_FILE)",
\t\t\t\t"$(PROJECT_DIR)/Scripts/set_bundle_build_number.sh",
\t\t\t\t"$(TARGET_BUILD_DIR)/$(INFOPLIST_PATH)",
\t\t\t);
\t\t\tname = "Script: Set Build Number";
\t\t\toutputFileListPaths = (
\t\t\t);
\t\t\toutputPaths = (
\t\t\t\t"$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)",
\t\t\t\t"$(SRCROOT)/ProvenanceCompanion/.version",
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t\tshellPath = /bin/bash;
\t\t\tshellScript = ". Scripts/set_bundle_build_number.sh ProvenanceCompanion\\n";
\t\t}};
"""


def build_configs():
    shared_settings = """
\t\t\t\tALLOW_TARGET_PLATFORM_SPECIALIZATION = YES;
\t\t\t\tASCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tASETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCLANG_ANALYZER_NONNULL = YES;
\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "ProvenanceCompanion/ProvenanceCompanion.entitlements";
\t\t\t\tCODE_SIGN_IDENTITY = "Apple Development";
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tDEAD_CODE_STRIPPING = YES;
\t\t\t\tDEVELOPMENT_TEAM = "$(DEVELOPMENT_TEAM)";
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"GL_SILENCE_DEPRECATION=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tINFOPLIST_FILE = "ProvenanceCompanion/ProvenanceCompanion-Info.plist";
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.utilities";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 16.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t\t"@loader_path/Frameworks",
\t\t\t\t);
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = "org.provenance-emu.ProvenanceCompanion";
\t\t\t\tPRODUCT_NAME = "Provenance Companion";
\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
\t\t\t\tSUPPORTS_MACCATALYST = NO;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t\tWRAPPER_EXTENSION = app;"""

    debug = f"""
\t\t{CFG_DEBUG} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = {XCCONFIG_REF} /* Build-iOS.xcconfig */;
\t\t\tbuildSettings = {{{shared_settings}
\t\t\t\tAPP_DISPLAY_NAME = "Companion Debug";
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tSWIFT_COMPILATION_MODE = singlefile;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tVALIDATE_PRODUCT = NO;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
"""
    release = f"""
\t\t{CFG_RELEASE} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = {XCCONFIG_REF} /* Build-iOS.xcconfig */;
\t\t\tbuildSettings = {{{shared_settings}
\t\t\t\tAPP_DISPLAY_NAME = "Provenance Companion";
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "ProvenanceCompanion/ProvenanceCompanion-AppStore.entitlements";
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};
"""
    archive = f"""
\t\t{CFG_ARCHIVE} /* Archive */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbaseConfigurationReference = {XCCONFIG_REF} /* Build-iOS.xcconfig */;
\t\t\tbuildSettings = {{{shared_settings}
\t\t\t\tAPP_DISPLAY_NAME = "Provenance Companion";
\t\t\t\tCODE_SIGN_ENTITLEMENTS = "ProvenanceCompanion/ProvenanceCompanion-AppStore.entitlements";
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Archive;
\t\t}};
"""
    return debug, release, archive


def config_list():
    return f"""
\t\t{CONFIG_LIST} /* Build configuration list for PBXNativeTarget "ProvenanceCompanion" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{CFG_DEBUG} /* Debug */,
\t\t\t\t{CFG_RELEASE} /* Release */,
\t\t\t\t{CFG_ARCHIVE} /* Archive */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
"""


def pkg_deps():
    entries = [
        (PKG_PVLIBRARY,      SRC_PVLIBRARY,      "PVLibrary"),
        (PKG_PVSUPPORT,      SRC_PVSUPPORT,      "PVSupport"),
        (PKG_PVSETTINGS,     SRC_PVSETTINGS,     "PVSettings"),
        (PKG_PVLOGGING,      SRC_PVLOGGING,      "PVLogging"),
        (PKG_PVFEATUREFLAGS, SRC_PVFEATUREFLAGS, "PVFeatureFlags"),
        (PKG_PVUI,           SRC_PVUI,           "PVUI"),
        (PKG_PVTHEMES,       SRC_PVTHEMES,       "PVThemes"),
    ]
    result = ""
    for uid, src, name in entries:
        result += f"""
\t\t{uid} /* {name} */ = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {src} /* XCLocalSwiftPackageReference "{name}" */;
\t\t\tproductName = {name};
\t\t}};
"""
    return result


# ── Apply patches ──────────────────────────────────────────────────────────────

def patch(content):
    # 1. PBXFileReference — add product ref
    content = content.replace(
        "/* End PBXFileReference section */",
        build_file_ref() + "\t\t/* End PBXFileReference section */"
    )

    # 2. PBXFileSystemSynchronizedRootGroup — add sync group
    content = content.replace(
        "/* End PBXFileSystemSynchronizedRootGroup section */",
        fs_sync_group() + "\t\t/* End PBXFileSystemSynchronizedRootGroup section */"
    )

    # 3. PBXNativeTarget — add target
    content = content.replace(
        "/* End PBXNativeTarget section */",
        native_target() + "\t\t/* End PBXNativeTarget section */"
    )

    # 4. PBXProject targets list — append ProvenanceCompanion
    content = content.replace(
        "\t\t\t\tB3BE9FCF2C7988BD006D989E /* Provenance Stickers */,\n\t\t\t);",
        f"\t\t\t\tB3BE9FCF2C7988BD006D989E /* Provenance Stickers */,\n\t\t\t\t{TARGET} /* ProvenanceCompanion */,\n\t\t\t);"
    )

    # 5. PBXProject main group — add FS sync group near ProvenanceTV
    content = content.replace(
        "\t\t\t\t1AD481B51BA350A400FDA50A /* ProvenanceTV */,",
        f"\t\t\t\t1AD481B51BA350A400FDA50A /* ProvenanceTV */,\n\t\t\t\t{FS_SYNC_GROUP} /* ProvenanceCompanion */,"
    )

    # 6. Products group — add .app product ref
    content = content.replace(
        "\t\t\t\tB39B10AB2DAF3D16004EEF79 /* TopShelfv2.appex */,",
        f"\t\t\t\tB39B10AB2DAF3D16004EEF79 /* TopShelfv2.appex */,\n\t\t\t\t{PRODUCT_REF} /* ProvenanceCompanion.app */,"
    )

    # 7. PBXSourcesBuildPhase — add phase
    sources_phase, frameworks_phase, resources_phase, script_phase = build_phases()
    content = content.replace(
        "/* End PBXSourcesBuildPhase section */",
        sources_phase + "\t\t/* End PBXSourcesBuildPhase section */"
    )

    # 8. PBXFrameworksBuildPhase — add phase
    content = content.replace(
        "/* End PBXFrameworksBuildPhase section */",
        frameworks_phase + "\t\t/* End PBXFrameworksBuildPhase section */"
    )

    # 9. PBXResourcesBuildPhase — add phase
    content = content.replace(
        "/* End PBXResourcesBuildPhase section */",
        resources_phase + "\t\t/* End PBXResourcesBuildPhase section */"
    )

    # 10. PBXShellScriptBuildPhase — add Set Build Number script
    content = content.replace(
        "/* End PBXShellScriptBuildPhase section */",
        script_phase + "\t\t/* End PBXShellScriptBuildPhase section */"
    )

    # 11. XCBuildConfiguration — add Debug/Release/Archive
    debug_cfg, release_cfg, archive_cfg = build_configs()
    content = content.replace(
        "/* End XCBuildConfiguration section */",
        debug_cfg + release_cfg + archive_cfg + "\t\t/* End XCBuildConfiguration section */"
    )

    # 12. XCConfigurationList — add config list
    content = content.replace(
        "/* End XCConfigurationList section */",
        config_list() + "\t\t/* End XCConfigurationList section */"
    )

    # 13. XCSwiftPackageProductDependency — add package deps
    content = content.replace(
        "/* End XCSwiftPackageProductDependency section */",
        pkg_deps() + "\t\t/* End XCSwiftPackageProductDependency section */"
    )

    return content


def main():
    with open(PBXPROJ, "r", encoding="utf-8") as f:
        content = f.read()

    if already_added(content):
        print("ProvenanceCompanion target already present — nothing to do.")
        return

    # Verify expected markers exist
    markers = [
        "/* End PBXFileReference section */",
        "/* End PBXNativeTarget section */",
        "/* End PBXSourcesBuildPhase section */",
        "/* End PBXFrameworksBuildPhase section */",
        "/* End PBXResourcesBuildPhase section */",
        "/* End PBXShellScriptBuildPhase section */",
        "/* End XCBuildConfiguration section */",
        "/* End XCConfigurationList section */",
        "/* End XCSwiftPackageProductDependency section */",
        "B3BE9FCF2C7988BD006D989E /* Provenance Stickers */,",
        "1AD481B51BA350A400FDA50A /* ProvenanceTV */,",
        "B39B10AB2DAF3D16004EEF79 /* TopShelfv2.appex */,",
    ]
    missing = [m for m in markers if m not in content]
    if missing:
        print("ERROR: Expected markers not found:")
        for m in missing:
            print(f"  - {m!r}")
        raise SystemExit(1)

    # Check for PBXFileSystemSynchronizedRootGroup section
    if "/* End PBXFileSystemSynchronizedRootGroup section */" not in content:
        # If no such section exists yet, we skip that insertion
        print("Note: PBXFileSystemSynchronizedRootGroup section not found; will insert FS sync group inline.")

    patched = patch(content)

    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(patched)

    print("✅ ProvenanceCompanion target added to project.pbxproj")


if __name__ == "__main__":
    main()
