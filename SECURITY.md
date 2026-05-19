# Security Policy

Thanks for taking the time to look at Provenance's security posture.

## Supported versions

We only accept reports against the current released version on the
[App Store / TestFlight](https://wiki.provenance-emu.com/installation-and-usage/installing-provenance)
or the `develop` branch of this repository. We do not investigate
reports against unofficial sideloads or third-party redistributions.

## Reporting a vulnerability

**Please do not open public GitHub issues for security reports.**

Use one of the following private channels:

- **GitHub Private Vulnerability Reporting** — preferred.
  [Open a private report here](https://github.com/Provenance-Emu/Provenance/security/advisories/new).
- **Email** — `mail@joemattiello.com` with subject prefix `[security]`.

Please include:

- A description of the issue and its potential impact.
- Steps to reproduce, ideally with a minimal sample ROM / configuration
  (do not include copyrighted ROMs — describe the file shape instead).
- The Provenance build (commit hash or App Store/TestFlight version)
  and iOS / tvOS / macOS version you tested against.
- Any proof-of-concept, log output, or crash report you have.

We will acknowledge receipt within **3 business days** and aim to send
a status update within **7 business days**. If we agree the report is
in scope, we will work with you on a coordinated disclosure timeline.

## Scope

Provenance is a multi-platform emulator frontend with a number of
third-party emulator cores (Mednafen, Dolphin, PPSSPP, flycast,
mupen64plus, melonDS, RetroArch and friends) loaded as dynamic
libraries. Reports involving:

- **Provenance application code, build infrastructure, CI pipelines,
  CloudKit sync, and our app extensions** — in scope.
- **Third-party emulator core source** — please report upstream first;
  cross-link the upstream issue when filing with us so we can track
  the fix in our submodule update path.
- **Sandbox-escape via maliciously crafted ROM/save files** — in scope
  if it reaches the host file system or memory beyond the emulator
  process; out of scope if it stays within the emulated guest CPU's
  memory model.

## Out of scope

- Reports against unofficial builds, sideloaded copies, jailbroken
  installs (including LiveContainer / SideStore / AltStore-Plus
  bundles), or third-party app marketplaces.
- Theoretical issues without a proof of concept.
- Findings that require an attacker with physical device access plus
  user passcode.
- Findings whose only impact is in the emulated guest system (an NES
  ROM exploiting an NES core to mis-emulate is not a Provenance
  vulnerability).
- Static analysis or AI-scanner output without a demonstrated
  exploitable code path on iOS / tvOS / macOS Catalyst.

## Acknowledgements

We're happy to credit reporters publicly once a fix has shipped — let
us know your preferred name/handle when you report.
