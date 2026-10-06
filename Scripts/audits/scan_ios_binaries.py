#!/usr/bin/env python

# This script scans iOS frameworks and dylibs for binary information
# It can be used to check if a binary is code signed, if it's a fat binary,
# and if it's signed with a valid certificate.
# It can also be used to check if a binary is missing.

import os
import subprocess
import argparse
from macholib.MachO import MachO

def get_binary_info(binary_path):
    """Extract information from a Mach-O binary"""
    info = {
        'path': binary_path,
        'is_fat': False,
        'platforms': set(),
        'code_sign': False,
        'encryption_info': False,
        'errors': [],
        'warnings': []
    }

    try:
        m = MachO(binary_path)
        info['is_fat'] = m.fat

        # Check for code signature and encryption
        output = subprocess.check_output(['otool', '-l', binary_path]).decode()
        info['code_sign'] = 'LC_CODE_SIGNATURE' in output
        info['encryption_info'] = 'LC_ENCRYPTION_INFO' in output

        # Get platforms
        for header in m.headers:
            if hasattr(header, 'header'):
                platform = header.header.filetype
                info['platforms'].add(platform)

        # Validate binary information
        if not info['platforms']:
            info['errors'].append("No platform information found")

        # Different validation for dylibs vs frameworks
        is_dylib = binary_path.endswith('.dylib')
        if is_dylib:
            if info['code_sign']:
                info['warnings'].append("Dylib should not be code signed")
            if not info['encryption_info']:
                info['errors'].append("Dylib missing encryption info")
        else:
            # Framework validation
            if not info['code_sign']:
                info['warnings'].append("Framework is not code signed")

        if len(info['platforms']) > 2:
            info['warnings'].append(f"Unusual number of platforms: {len(info['platforms'])}")

    except Exception as e:
        info['errors'].append(f"Error processing binary: {str(e)}")

    return info

def scan_frameworks(folder_path):
    """Scan a folder for frameworks and dylibs"""
    results = []
    missing_binaries = []

    for root, dirs, files in os.walk(folder_path):
        # Process frameworks
        if root.endswith('.framework'):
            framework_name = os.path.basename(root).replace('.framework', '')
            binary_path = os.path.join(root, framework_name)
            if os.path.exists(binary_path):
                results.append(get_binary_info(binary_path))
            else:
                missing_binaries.append(f"Missing framework binary: {binary_path}")

        # Process dylibs
        for file in files:
            if file.endswith('.dylib'):
                dylib_path = os.path.join(root, file)
                if os.path.exists(dylib_path):
                    results.append(get_binary_info(dylib_path))
                else:
                    missing_binaries.append(f"Missing dylib: {dylib_path}")

    return results, missing_binaries

def print_results(results, missing_binaries, verbose=False):
    """Print the scan results and any issues found"""
    issues_found = False
    dylibs_with_issues = {
        'code_signed': [],
        'missing_encryption': [],
        'other_issues': []
    }

    # Print missing binaries
    if missing_binaries:
        print("\n=== Missing Binaries ===")
        for missing in missing_binaries:
            print(missing)
        issues_found = True

    # Print binary information and collect issues
    binaries_with_issues = []
    for result in results:
        has_issues = bool(result['errors'] or result['warnings'])
        is_dylib = result['path'].endswith('.dylib')

        if verbose or has_issues:
            print(f"\nBinary: {result['path']}")
            print(f"  Fat Binary: {result['is_fat']}")
            print(f"  Platforms: {', '.join(map(str, result['platforms']))}")
            print(f"  Code Signed: {result['code_sign']}")
            print(f"  Encryption Info: {result['encryption_info']}")

        if has_issues:
            issues_found = True
            if not verbose:  # Only print path if not already printed
                print(f"\nBinary: {result['path']}")

            if result['errors']:
                print("  Errors:")
                for error in result['errors']:
                    print(f"    - {error}")
                    if is_dylib and "missing encryption info" in error.lower():
                        dylibs_with_issues['missing_encryption'].append(result['path'])

            if result['warnings']:
                print("  Warnings:")
                for warning in result['warnings']:
                    print(f"    - {warning}")
                    if is_dylib and "should not be code signed" in warning.lower():
                        dylibs_with_issues['code_signed'].append(result['path'])

            binaries_with_issues.append(result['path'])

            # Track dylibs with other types of issues
            if is_dylib and not any(
                ["missing encryption info" in e.lower() for e in result['errors']] +
                ["should not be code signed" in w.lower() for w in result['warnings']]
            ):
                dylibs_with_issues['other_issues'].append(result['path'])

    # Print summary
    print(f"\n=== Summary ===")
    print(f"Total binaries scanned: {len(results)}")
    print(f"Binaries with issues: {len(binaries_with_issues)}")
    print(f"Missing binaries: {len(missing_binaries)}")

    # Print dylib-specific summary if there are any issues
    if any(dylibs_with_issues.values()):
        print("\n=== Dylib Issues Summary ===")
        if dylibs_with_issues['code_signed']:
            print("\nCode Signed Dylibs (Should be unsigned):")
            for dylib in dylibs_with_issues['code_signed']:
                print(f"  - {os.path.basename(dylib)}")

        if dylibs_with_issues['missing_encryption']:
            print("\nDylibs Missing Encryption Info:")
            for dylib in dylibs_with_issues['missing_encryption']:
                print(f"  - {os.path.basename(dylib)}")

        if dylibs_with_issues['other_issues']:
            print("\nDylibs with Other Issues:")
            for dylib in dylibs_with_issues['other_issues']:
                print(f"  - {os.path.basename(dylib)}")

    if not issues_found and verbose:
        print("\nNo issues found in any binaries.")

    return issues_found

def main():
    parser = argparse.ArgumentParser(description='Scan iOS frameworks and dylibs for binary information')
    parser.add_argument('path', help='Path to the folder containing frameworks and dylibs')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('--strict', action='store_true', help='Exit with error if any issues are found')

    args = parser.parse_args()

    if not os.path.exists(args.path):
        print(f"Error: Path '{args.path}' does not exist")
        return 1

    if args.verbose:
        print(f"Scanning folder: {args.path}")

    results, missing_binaries = scan_frameworks(args.path)
    issues_found = print_results(results, missing_binaries, args.verbose)

    if args.strict and issues_found:
        return 1

    return 0

if __name__ == "__main__":
    exit(main())
