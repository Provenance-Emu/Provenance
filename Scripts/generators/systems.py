#!/usr/bin/env python3

import plistlib
import sys

def generate_markdown_tables(plist_path):
    # Load the plist file
    with open(plist_path, 'rb') as f:
        plist_data = plistlib.load(f)

    # Sort systems by manufacturer (ascending) and then by release year
    sorted_systems = sorted(plist_data,
                          key=lambda x: (x.get('PVManufacturer', '').lower(),
                                       int(x.get('PVReleaseYear', 0))))

    # Prepare markdown content
    markdown = "# Emulator Systems Overview\n\n"

    # Table 1: System Features with hyperlinks
    markdown += "## System Features\n\n"
    markdown += "| System | Manufacturer | Year | Bits | Portable | Rumble | CDs | BIOS Required |\n"
    markdown += "|:-------|:-------------|:----:|:----:|:--------:|:------:|:---:|:-------------:|\n"

    # Table 2: BIOS Requirements with collapsible sections
    bios_table = "## BIOS Requirements\n\n"
    bios_table += "<summary>Show BIOS Details</summary>\n\n"
    bios_table += "| System | BIOS File | MD5 | Description | Required |\n"
    bios_table += "|:-------|:----------|:---:|:-----------:|:--------:|\n"

    # Process sorted systems
    for system in sorted_systems:
        # System features table
        system_name = system.get('PVSystemName', '')
        manufacturer = system.get('PVManufacturer', '')
        year = system.get('PVReleaseYear', '')
        bits = system.get('PVBit', '')
        portable = '✓' if system.get('PVPortable', False) else '✗'
        rumble = '✓' if system.get('PVSupportsRumble', False) else '✗'
        cds = '✓' if system.get('PVUsesCDs', False) else '✗'
        bios_required = '✓' if system.get('PVRequiresBIOS', False) else '✗'

        # Add hyperlink if BIOS is required
        if bios_required == '✓':
            bios_required = f"[✓](#bios-{system_name.lower().replace(' ', '-')})"

        markdown += f"| {system_name} | {manufacturer} | {year} | {bits} | {portable} | {rumble} | {cds} | {bios_required} |\n"

        # Add anchor for BIOS entries
        bios_table += f"<a name=\"bios-{system_name.lower().replace(' ', '-')}\"></a>\n"

        # BIOS requirements table
        bios_entries = system.get('PVBIOSNames', [])
        for bios in bios_entries:
            bios_file = bios.get('Name', '')
            md5 = bios.get('MD5', '')
            description = bios.get('Description', '')
            required = '✓' if not bios.get('Optional', False) else '✗'

            # Create Google search link for MD5
            md5_link = f"[{md5}](https://www.google.com/search?q={md5})" if md5 else ''

            bios_table += f"| {system_name} | {bios_file} | {md5_link} | {description} | {required} |\n"

    # Combine both tables
    markdown += "\n" + bios_table

    # Add a footer with GitHub emojis
    markdown += "\n---\n"
    markdown += "Generated with ❤️ using [Provenance](https://provenance-emu.com) 🕹️\n"

    # Print to stdout
    print(markdown)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python systems.py <path_to_plist>")
        sys.exit(1)

    plist_path = sys.argv[1]
    generate_markdown_tables(plist_path)
