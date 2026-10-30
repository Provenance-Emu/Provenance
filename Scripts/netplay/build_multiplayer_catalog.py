#!/usr/bin/env python3
"""Extract player-count facts; never infer netplay support or match games by title.

Download the official catalog first:
  curl -fL 'https://www.gametdb.com/wiitdb.zip?LANG=EN&GAMECUBE=1' -o /tmp/wiitdb.zip
  python3 Scripts/netplay/build_multiplayer_catalog.py /tmp/wiitdb.zip
"""
import argparse
from collections import Counter
from datetime import date
import hashlib
import json
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

SOURCE = 'https://www.gametdb.com/wiitdb.zip?LANG=EN&GAMECUBE=1'
DEST = Path(__file__).resolve().parents[2] / 'PVNetplay/Sources/PVNetplay/Resources'


def extract(raw):
    result = {}
    for game in ET.fromstring(raw).findall('game'):
        serial = game.findtext('id', '').strip().upper()
        controls = game.find('input')
        if len(serial) != 6 or not serial.isalnum() or controls is None or game.findtext('type') == 'CUSTOM':
            continue
        if serial[0] == 'G':
            system = 'com.provenance.gamecube'
        elif serial[0] in 'RS':
            system = 'com.provenance.wii'
        else:
            continue
        # A GBA/DS peripheral may be part of the advertised multiplayer mode.
        # A shared-controller integration cannot claim to emulate that mode.
        if any(control.get('type') in ('gba', 'nds') for control in controls.findall('control')):
            continue
        wifi = game.find('wi-fi')
        try:
            local_players = int(controls.get('players', ''))
            network_players = int(wifi.get('players', '0')) if wifi is not None else 0
        except ValueError:
            continue
        if not 1 <= local_players <= 4:
            continue
        modes = []
        if local_players >= 2:
            modes.append({'kind': 'sharedConsole', 'maxPlayers': local_players})
        if network_players >= 2:
            modes.append({'kind': 'nativeNetwork', 'maxPlayers': min(network_players, 64)})
        result[system + ':' + serial] = {
            'modes': modes,
            # One local player does not disprove linked/LAN multiplayer.
            'singlePlayerOnly': False,
            'source': 'gameTDB',
            'reference': 'https://www.gametdb.com/Wii/' + serial,
        }
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive', type=Path)
    args = parser.parse_args()
    with zipfile.ZipFile(args.archive) as archive:
        if archive.getinfo('wiitdb.xml').file_size > 64 * 1024 * 1024:
            parser.error('Unexpectedly large XML catalog')
        raw = archive.read('wiitdb.xml')
    records = extract(raw)
    # Detect partial downloads rather than silently dropping an entire console.
    counts = Counter(key.split(':')[0] for key in records)
    if min(counts['com.provenance.gamecube'], counts['com.provenance.wii']) < 100:
        parser.error('Incomplete catalog: download with GAMECUBE=1')
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / 'MultiplayerCatalog.json').write_text(json.dumps(records, sort_keys=True, separators=(',', ':')) + '\n')
    (DEST / 'MultiplayerCatalog-SOURCE.txt').write_text(
        f'Player-count facts from GameTDB: {SOURCE}\nRetrieved {date.today()}. XML SHA256: {hashlib.sha256(raw).hexdigest()}\n'
        'Only standard G-prefix GameCube and R/S-prefix Wii retail IDs. Custom titles and GBA/DS peripheral records are omitted.\n'
        'Local input players and native network players remain distinct. One-local-player records without another known mode remain unverified.\n'
        'No title matching, descriptions or artwork are included. These are multiplayer facts, not tested emulator compatibility.\n'
        'Rebuild with Scripts/netplay/build_multiplayer_catalog.py and an official wiitdb.zip download.\n')
    print(dict(counts))


if __name__ == '__main__':
    main()
