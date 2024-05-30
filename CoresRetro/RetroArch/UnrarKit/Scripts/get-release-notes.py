#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

# Usage: get-release-notes.py <version number>
#
# Prints the release notes for a given version of the library, ignoring any
# beta marking on the tag. For beta releases, retrieves the beta notes and
# prepends them
#
# Retrieves release notes from CHANGELOG.mc
# Retrieves beta notes from beta-notes.md
#

import os.path
import re
import subprocess
import sys

CHANGELOG_FILEPATH = 'CHANGELOG.md'
BETANOTES_FILEPATH = 'beta-notes.md'


def print_release_notes(version):
    version_num, beta_tag, beta_num = get_version_parts(version)
    change_notes = get_changelog_notes(version_num)
    
    if beta_tag is None:
        print(change_notes)
        return True 
    
    beta_notes = get_beta_notes(beta_num, change_notes)
    
    if not beta_notes is None:
        print(beta_notes)
        return True

    return False

def get_version_parts(version):
    '''
    Splits out the main part of the version number from any beta tags, and the beta number
    
    >>> get_version_parts('1.0')
    ('1.0', None, None)
    
    >>> get_version_parts('1.0.1')
    ('1.0.1', None, None)
    
    >>> get_version_parts('1.0-beta')
    ('1.0', 'beta', 1)
    
    >>> get_version_parts('1.0.1-beta')
    ('1.0.1', 'beta', 1)
    
    >>> get_version_parts('1.0-beta1')
    ('1.0', 'beta', 1)
    
    >>> get_version_parts('1.0.2-beta1')
    ('1.0.2', 'beta', 1)
    
    '''
    
    matches = re.match(r'(?P<version_num>[\d\.]+)\-?(?P<beta>\D+)?(?P<beta_num>\d+)?', version)
    version_num = matches.group('version_num')
    beta_tag = matches.group('beta')
    beta_num = matches.group('beta_num')
    
    beta_num = (int(beta_num or 1)) if beta_tag else None
    
    return (version_num, beta_tag, beta_num)

def get_version_notes(version_num, changes):
    r'''
    Returns the portion of the given changelog that corresponds to the changes for the given
    version number. version_num is expected to be stripped of any beta info
    
    This won't work for the last version number in a file, but that's fine
    
    >>> get_version_notes('1.2', '# UnrarKit CHANGELOG\n\n## 1.2\n\nList of changes\n\n## 1.1\n\nMore changes\n\n## 1.0')
    'List of changes'

    >>> get_version_notes('1.1', '# UnrarKit CHANGELOG\n\n## 1.2\n\nList of changes\n\n## 1.1\n\nMore changes\n\n## 1.0')
    'More changes'
    '''
    
    notes_regex = r'##\s+{}\s+(.+?)\s+(?:##\s+[\d\.]+).*'.format(version_num.replace('.', '\.'))
    matches = re.search(notes_regex, changes, re.DOTALL)
    
    return matches[1].strip()

def get_changelog_notes(version_num):
    with open(CHANGELOG_FILEPATH, 'r') as changelog:
        changes = changelog.read()
    
    return get_version_notes(version_num, changes)

def have_beta_notes_been_updated(version):
    '''
    Returns True if the beta notes have been updated since the last tag, or if the version
    isn't a beta, or if it's the first beta
    '''
    
    version_num, beta_tag, beta_num = get_version_parts(version)
    if not beta_tag or beta_num == 1:
        return True

    all_tags = subprocess.check_output(['git', 'tag', '--sort=-taggerdate'], universal_newlines=True)
    last_tag = all_tags.split('\n')[0]
    
    diff_output = subprocess.check_output(['git', 'diff', '--name-only', last_tag, 'HEAD',
                                           '--', BETANOTES_FILEPATH])
                                           
    # Will be 'beta-notes.md' if it has changed, blank otherwise
    return bool(diff_output)

def get_beta_notes(beta_num, change_notes):
    '''
    Returns the release's change notes, taking the beta notes into account. If it's
    the first beta release, then it doesn't bother. Also checks if the release notes
    have been updated since the last beta
    '''

    if beta_num == 1:
        return change_notes

    with open(BETANOTES_FILEPATH, 'r') as beta_notes_file:
        beta_notes = beta_notes_file.read()
    
    return '''Updates in this beta:

{}

-------
Changes for main release:
{}
'''.format(beta_notes, change_notes)
    

if __name__ == '__main__':
    import doctest
    doctest.testmod()

    CHECK_BETA_NOTES_FLAG = '--beta-notes-check'

    if len(sys.argv) < 2:
        print('\nNo argument given. Pass the version number, optionally with {}\n'.format(
            CHECK_BETA_NOTES_FLAG), file=sys.stderr)
        sys.exit(1)

    version = sys.argv[1]
    
    if not version:
        print("Empty version number passed", file=sys.stderr)
        sys.exit(1)

    if len(sys.argv) >= 3 and sys.argv[2] == CHECK_BETA_NOTES_FLAG:
        if not have_beta_notes_been_updated(version):
            print("Beta notes haven't been updated since since last release", file=sys.stderr)
            sys.exit(1)
        
        sys.exit(0)

    if not os.path.exists(CHANGELOG_FILEPATH):
        CHANGELOG_FILEPATH = os.path.join('..', CHANGELOG_FILEPATH)
        BETANOTES_FILEPATH = os.path.join('..', BETANOTES_FILEPATH)

    exit_code = 0 if print_release_notes(version) else 1
    sys.exit(exit_code)