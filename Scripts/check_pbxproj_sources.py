#!/usr/bin/env python3
"""Flag source files an Xcode project should compile but doesn't reference.

Most Provenance projects list their sources explicitly (they are not
PBXFileSystemSynchronizedRootGroup folders), so a new .swift/.m file added
next to its siblings compiles in SwiftPM but is missing from the Xcode
archive build. That break only shows up on the post-merge develop build.

For every .xcodeproj in Provenance.xcworkspace, this resolves the on-disk
path of each file the project references, takes the directories holding
files it compiles, and reports tracked source files in those directories
that the project does not reference at all.

Known exclusions live in Scripts/pbxproj_sources_allowlist.txt
(one repo-relative path per line, # comments allowed).

Usage: check_pbxproj_sources.py [--write-allowlist]
Exit status is 1 when an unreferenced file is found.
"""

import os
import re
import subprocess
import sys

SOURCE_EXTENSIONS = {".swift", ".m", ".mm", ".c", ".cc", ".cpp"}
MANIFESTS = {"Package.swift"}
ALLOWLIST = "Scripts/pbxproj_sources_allowlist.txt"
WORKSPACE = "Provenance.xcworkspace/contents.xcworkspacedata"

TOKEN = re.compile(
    r'\s+|//[^\n]*|/\*.*?\*/|"(?:[^"\\]|\\.)*"|[{}()=;,]|[^\s{}()=;,"]+',
    re.S,
)


def tokenize(text):
    for match in TOKEN.finditer(text):
        tok = match.group(0)
        if tok[0].isspace() or tok.startswith("//") or tok.startswith("/*"):
            continue
        yield tok


ESCAPES = {"n": "\n", "t": "\t"}


def unquote(tok):
    if tok.startswith('"'):
        return re.sub(r"\\(.)", lambda m: ESCAPES.get(m.group(1), m.group(1)), tok[1:-1])
    return tok


def parse(tokens, pos=0):
    """Parse an old-style (OpenStep) plist; returns (value, next position)."""
    tok = tokens[pos]
    pos += 1
    if tok == "{":
        result = {}
        while tokens[pos] != "}":
            key = unquote(tokens[pos])
            assert tokens[pos + 1] == "=", f"expected '=' after {key}"
            result[key], pos = parse(tokens, pos + 2)
            assert tokens[pos] == ";", f"expected ';' after {key}"
            pos += 1
        return result, pos + 1
    if tok == "(":
        result = []
        while tokens[pos] != ")":
            value, pos = parse(tokens, pos)
            result.append(value)
            if tokens[pos] == ",":
                pos += 1
        return result, pos + 1
    return unquote(tok), pos


def tracked_files():
    out = subprocess.run(["git", "ls-files", "-z"], capture_output=True, check=True).stdout
    return out.decode("utf-8").split("\0")


def workspace_projects():
    """The .xcodeproj files Provenance.xcworkspace builds, as pbxproj paths."""
    with open(WORKSPACE, encoding="utf-8") as fh:
        locations = re.findall(r'location = "(?:group|container):([^"]+\.xcodeproj)"', fh.read())
    return sorted({f"{location}/project.pbxproj" for location in locations})


def index_sources(paths):
    """Group compilable source files by directory."""
    files_by_dir = {}
    for path in paths:
        if os.path.splitext(path)[1] in SOURCE_EXTENSIONS and os.path.basename(path) not in MANIFESTS:
            files_by_dir.setdefault(os.path.dirname(path), []).append(path)
    return files_by_dir


def check_project(pbxproj, files_by_dir):
    """Return tracked sources beside the project's compiled files that it never references."""
    with open(pbxproj, encoding="utf-8") as fh:
        data, _ = parse(list(tokenize(fh.read())))
    objects = data["objects"]
    project_dir = os.path.dirname(os.path.dirname(pbxproj))

    parent = {}
    for oid, obj in objects.items():
        for child in obj.get("children", []):
            parent[child] = oid

    resolved = {}

    def resolve(oid):
        if oid in resolved:
            return resolved[oid]
        obj = objects[oid]
        tree = obj.get("sourceTree", "<group>")
        path = obj.get("path", "")
        if tree == "SOURCE_ROOT":
            result = os.path.normpath(os.path.join(project_dir, path))
        elif tree == "<absolute>":
            result = None
        elif tree == "<group>":
            owner = parent.get(oid)
            if owner is None:
                base = os.path.normpath(os.path.join(project_dir, obj.get("projectDirPath", "")))
            else:
                base = resolve(owner)
            result = None if base is None else os.path.normpath(os.path.join(base, path))
        else:
            result = None  # BUILT_PRODUCTS_DIR, SDKROOT, ...
        resolved[oid] = result
        return result

    main_group = objects[data["rootObject"]].get("mainGroup")
    if main_group:
        parent.pop(main_group, None)

    referenced = set()
    covered_dirs = []  # folder references and synchronized groups
    for oid, obj in objects.items():
        isa = obj.get("isa")
        if isa == "PBXFileReference":
            path = resolve(oid)
            if path is None:
                continue
            if obj.get("lastKnownFileType", "").startswith("folder"):
                covered_dirs.append(path)
            referenced.add(path)
        elif isa == "PBXFileSystemSynchronizedRootGroup":
            path = resolve(oid)
            if path is not None:
                covered_dirs.append(path)

    compiled_dirs = set()
    for obj in objects.values():
        if obj.get("isa") != "PBXSourcesBuildPhase":
            continue
        for build_file in obj.get("files", []):
            ref = objects.get(build_file, {}).get("fileRef")
            if ref in objects and objects[ref].get("isa") == "PBXFileReference":
                path = resolve(ref)
                if path is not None:
                    compiled_dirs.add(os.path.dirname(path))

    def covered(path):
        return any(path == d or path.startswith(d + "/") for d in covered_dirs)

    missing = []
    for directory in sorted(compiled_dirs):
        for path in files_by_dir.get(directory, []):
            if path not in referenced and not covered(path):
                missing.append(path)
    return missing


def main():
    write_allowlist = "--write-allowlist" in sys.argv[1:]
    root = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], capture_output=True, check=True, text=True
    ).stdout.strip()
    os.chdir(root)

    files = tracked_files()
    files_by_dir = index_sources(files)

    tracked = set(files)
    projects = [path for path in workspace_projects() if path in tracked]

    allowed = set()
    if os.path.exists(ALLOWLIST) and not write_allowlist:
        with open(ALLOWLIST, encoding="utf-8") as fh:
            allowed = {line.strip() for line in fh if line.strip() and not line.startswith("#")}

    findings = {}
    for pbxproj in sorted(projects):
        missing = [path for path in check_project(pbxproj, files_by_dir) if path not in allowed]
        if missing:
            findings[pbxproj] = missing

    if write_allowlist:
        with open(ALLOWLIST, "w", encoding="utf-8") as fh:
            fh.write(
                "# Source files missing from the Xcode project that sits beside them.\n"
                "# Some are deliberate (alternate copies, #included units); others may be\n"
                "# code that never ships. Checked by Scripts/check_pbxproj_sources.py;\n"
                "# remove a line once the file is added to its project or deleted.\n"
            )
            written = set()
            for pbxproj, missing in findings.items():
                new = [path for path in missing if path not in written]
                if new:
                    fh.write(f"\n# {pbxproj}\n")
                    fh.writelines(f"{path}\n" for path in new)
                    written.update(new)
        print(f"Wrote {len(written)} entries to {ALLOWLIST}")
        return 0

    if not findings:
        print(f"All {len(projects)} Xcode projects reference every source file beside their sources.")
        return 0

    for pbxproj, missing in findings.items():
        for path in missing:
            print(f"::error file={path}::{path} is not in {pbxproj}; add it to the project "
                  f"(PBXBuildFile, PBXFileReference, group, Sources phase) or to {ALLOWLIST}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
