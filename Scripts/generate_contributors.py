#! /usr/bin/env python
# This script generates a list of contributors from the Git history
# and creates a markdown file with their information.

import subprocess
import re
import hashlib
import os
import requests
from collections import defaultdict
from datetime import datetime

# Configuration
GRAVATAR_SIZE = 100
OUTPUT_FILE = "CONTRIBUTORS.md"
IMAGE_DIR = "contributor_images"
GIT_COMMAND = ["git", "log", "--pretty=format:%an|%ae"]
GIT_STATS_COMMAND = ["git", "log", "--numstat", "--pretty=format:%an|%ae"]
GIT_COMMIT_COUNT = ["git", "shortlog", "-sne"]

# Print progress message to the console
def print_progress(message):
    """Print a progress message to the console"""
    print(f"⏳ {message}...")

# Generate Gravatar URL from email
def get_gravatar_url(email, size=GRAVATAR_SIZE):
    """Generate Gravatar URL from email"""
    email_hash = hashlib.md5(email.strip().lower().encode('utf-8')).hexdigest()
    return f"https://www.gravatar.com/avatar/{email_hash}?s={size}&d=identicon"

# Get unique contributors from Git history
def fetch_contributors():
    """Get unique contributors from Git history"""
    print_progress("Fetching contributors from Git history")
    result = subprocess.run(GIT_COMMAND, capture_output=True, text=True)
    contributors = defaultdict(dict)

    # Split the result into lines and process each line
    for line in result.stdout.splitlines():
        name, email = line.split('|')
        if email not in contributors:
            contributors[email] = {
                'name': name,
                'email': email,
                'image': get_gravatar_url(email)
            }

    print("✅ Fetched contributors successfully")
    return list(contributors.values())

# Download contributor image
def download_image(url, email):
    """Download contributor image"""
    os.makedirs(IMAGE_DIR, exist_ok=True)
    response = requests.get(url)
    if response.status_code == 200:
        ext = 'jpg' if 'jpg' in response.headers.get('Content-Type', '') else 'png'
        path = os.path.join(IMAGE_DIR, f"{hashlib.md5(email.encode('utf-8')).hexdigest()}.{ext}")
        with open(path, 'wb') as f:
            f.write(response.content)
        return path
    return None

# Get contributor statistics from Git history
def fetch_contributor_stats():
    """Get contributor statistics from Git history"""
    print_progress("Fetching contributor statistics")
    result = subprocess.run(GIT_STATS_COMMAND, capture_output=True, text=True)
    stats = defaultdict(lambda: {
        'lines_added': 0,
        'lines_removed': 0,
        'files_changed': defaultdict(int),
        'commit_count': 0
    })

    current_author = None
    # Split the result into lines and process each line
    for line in result.stdout.splitlines():
        if '|' in line:
            # New commit, get author
            name, email = line.split('|')
            current_author = email
            stats[current_author]['commit_count'] += 1
        else:
            # File stats
            parts = line.split()
            if len(parts) == 3:
                added, removed, filename = parts
                stats[current_author]['lines_added'] += int(added) if added != '-' else 0
                stats[current_author]['lines_removed'] += int(removed) if removed != '-' else 0
                stats[current_author]['files_changed'][filename] += 1

    # Find largest file for each contributor
    for email, data in stats.items():
        if data['files_changed']:
            largest_file = max(data['files_changed'].items(), key=lambda x: x[1])[0]
            data['largest_file'] = largest_file
        else:
            data['largest_file'] = 'N/A'

    print("✅ Fetched contributor statistics successfully")
    return stats

# Get the best Gravatar URL from a list of emails (prefer real photos over placeholders)
def get_best_gravatar_url(emails):
    """Find the best Gravatar URL from a list of emails (prefer real photos over placeholders)"""
    for email in emails:
        url = get_gravatar_url(email)
        response = requests.head(url)
        if response.status_code == 200 and 'identicon' not in response.url:
            return url
    # Fallback to the first email's Gravatar
    return get_gravatar_url(emails[0])

# Combine contributors with the same name but different emails
def combine_contributors(contributors, stats):
    """Combine contributors with the same name but different emails"""
    combined = defaultdict(lambda: {
        'name': '',
        'emails': set(),
        'image': '',
        'lines_added': 0,
        'lines_removed': 0,
        'commit_count': 0,
        'files_changed': defaultdict(int),
        'largest_file': 'N/A'
    })

    for contributor in contributors:
        name = contributor['name']
        email = contributor['email']

        # Special case: Combine Joe Mattiello and Joseph Mattiello
        if name.lower() in ('joe mattiello', 'joseph mattiello'):
            name = 'Joseph Mattiello'

        combined[name]['name'] = name
        combined[name]['emails'].add(email)

        # Combine stats
        if email in stats:
            combined[name]['lines_added'] += stats[email]['lines_added']
            combined[name]['lines_removed'] += stats[email]['lines_removed']
            combined[name]['commit_count'] += stats[email]['commit_count']
            for file, count in stats[email]['files_changed'].items():
                combined[name]['files_changed'][file] += count

    # Find largest file and best Gravatar for each combined contributor
    for name, data in combined.items():
        if data['files_changed']:
            largest_file = max(data['files_changed'].items(), key=lambda x: x[1])[0]
            data['largest_file'] = largest_file
        # Find the best Gravatar image
        data['image'] = get_best_gravatar_url(sorted(data['emails']))

    # Convert to list of dicts
    return [
        {
            'name': name,
            'emails': sorted(data['emails']),
            'image': data['image'],
            'lines_added': data['lines_added'],
            'lines_removed': data['lines_removed'],
            'commit_count': data['commit_count'],
            'largest_file': data['largest_file']
        }
        for name, data in combined.items()
    ]

# Sort contributors by the sum of lines edited (added + removed)
def sort_contributors(contributors):
    """Sort contributors by the sum of lines edited (added + removed)"""
    return sorted(contributors, key=lambda x: x['lines_added'] + x['lines_removed'], reverse=True)

# Generate markdown content with stats using GitHub extended markdown
def generate_markdown(contributors):
    """Generate markdown content with stats using GitHub extended markdown"""
    print_progress("Generating markdown content")
    markdown = "# Contributors\n\n"
    markdown += "> Automatically generated from Git history\n\n"
    markdown += "## Summary\n\n"
    markdown += f"- **Total Contributors**: {len(contributors)}\n"
    markdown += f"- **Total Commits**: {sum(c['commit_count'] for c in contributors)}\n"
    markdown += f"- **Total Lines Added**: {sum(c['lines_added'] for c in contributors)}\n"
    markdown += f"- **Total Lines Removed**: {sum(c['lines_removed'] for c in contributors)}\n\n"

    markdown += "## Contributor Details\n\n"
    markdown += "<summary>Showing All Contributors</summary>\n\n"

    for contributor in contributors:
        # Contributor section
        markdown += f"### {contributor['name']}\n\n"
        markdown += f"![{contributor['name']}]({contributor['image']})\n\n"
        markdown += f"- **Emails Used**: {', '.join(contributor['emails'])}\n"
        markdown += f"- **Commits**: `{contributor['commit_count']}`\n"
        markdown += f"- **Lines Added**: `{contributor['lines_added']}`\n"
        markdown += f"- **Lines Removed**: `{contributor['lines_removed']}`\n"
        markdown += f"- **Most Active File**: `{contributor['largest_file']}`\n"
        markdown += f"- **Activity**: `{'▰' * min(10, contributor['commit_count'])}{'▱' * max(0, 10 - contributor['commit_count'])}`\n\n"
        markdown += "---\n\n"

    markdown += "\n"

    # Add a footer with emojis
    markdown += "---\n"
    markdown += "Generated with ❤️ using [Git](https://git-scm.com/) and [Gravatar](https://gravatar.com/) 🚀\n"

    print("✅ Markdown content generated successfully")
    return markdown

# Main function to generate the contributors file
def main():
    print("🚀 Starting contributors page generation...\n")

    # Get contributors
    contributors = fetch_contributors()

    # Get stats
    stats = fetch_contributor_stats()

    # Combine contributors with the same name
    combined_contributors = combine_contributors(contributors, stats)

    # Sort contributors by lines edited
    sorted_contributors = sort_contributors(combined_contributors)

    # Generate markdown
    markdown = generate_markdown(sorted_contributors)

    # Write to file
    print_progress(f"Writing output to {OUTPUT_FILE}")
    with open(OUTPUT_FILE, 'w') as f:
        f.write(markdown)

    # Print success message
    print(f"\n🎉 Successfully generated {OUTPUT_FILE} with {len(sorted_contributors)} contributors")

if __name__ == "__main__":
    main()
