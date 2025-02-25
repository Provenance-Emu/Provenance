#!/usr/bin/env python

# This script strips the code signing from a dylib file.
# It can be used to remove the code signing from a dylib file that is not signed.
# It can also be used to create a backup of the original file before modifying it.

import os
import sys
import argparse
import subprocess
import shutil
from pathlib import Path

def strip_codesign(dylib_path: str, backup: bool = True) -> bool:
    """
    Strip code signing from a dylib

    Args:
        dylib_path: Path to the dylib file
        backup: Whether to create a backup before modifying

    Returns:
        bool: True if successful, False otherwise
    """
    try:
        dylib_path = os.path.abspath(dylib_path)

        # Verify file exists and is a dylib
        if not os.path.exists(dylib_path):
            print(f"Error: File '{dylib_path}' does not exist")
            return False

        if not dylib_path.endswith('.dylib'):
            print(f"Error: File '{dylib_path}' is not a dylib")
            return False

        # Create backup if requested
        if backup:
            backup_path = f"{dylib_path}.bak"
            print(f"Creating backup at: {backup_path}")
            shutil.copy2(dylib_path, backup_path)

        # Strip code signing using codesign
        print("Stripping code signature...")
        subprocess.run(['codesign', '--remove-signature', dylib_path],
                      check=True,
                      capture_output=True)

        # Verify signature was removed
        result = subprocess.run(['codesign', '--verify', dylib_path],
                              capture_output=True,
                              text=True)

        if "code object is not signed" not in result.stderr:
            print("Warning: Code signature may not have been fully removed")
            return False

        print("Successfully stripped code signature")
        return True

    except subprocess.CalledProcessError as e:
        print(f"Error running codesign: {e}")
        if e.stderr:
            print(f"stderr: {e.stderr.decode()}")
        return False

    except Exception as e:
        print(f"Error: {str(e)}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Strip code signing from a dylib')
    parser.add_argument('dylib', help='Path to the dylib file')
    parser.add_argument('--no-backup', action='store_true',
                       help='Do not create backup before modifying')

    args = parser.parse_args()

    success = strip_codesign(args.dylib, backup=not args.no_backup)
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())
