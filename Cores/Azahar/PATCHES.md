# Azahar patch stack

Submodule `Cores/Azahar/azahar` tracks `Provenance-Emu/azahar` branch `provenance`
= an `azahar-emu/azahar` release tag + the commits below. Port a new tag by merging it
into `provenance` (merge the tag, not upstream master), then
`git -C Cores/Azahar/azahar fetch origin provenance && git -C Cores/Azahar/azahar checkout origin/provenance`,
`git -C Cores/Azahar/azahar submodule update --init --recursive`, and
`make prepare-azahar AZAHAR_SLICE=ios` (add `REMOTE=1` to build on the Studio).

Upstream base: 2127.0-rc3 = 11eceda5e0e682a1f44e396bf954a1b9137097ca (2026-11-12)
Fork head:     8a4cfb64bc11e7d79854f7a673fd8bd30dbc04fa

| # | Commit subject | Upstream PR | Status |
|---|---|---|---|
| 1 | common: build apple_utils.mm only on macOS | (open after first green build) | carried |
| 2 | vk_platform: use the frontend driver library on all platforms | (open after first green build) | carried |
| 3 | audio_core: add CoreAudio sink and input (ENABLE_COREAUDIO) | (open after first green build) | carried |
| 4 | cmake: only install the pre-commit hook when .git is a directory | upstream dd6a4c95b | upstreamed in 2127.0-rc3 |

Rule: no file under `Cores/Azahar/azahar` is ever shadowed or edited in place. A needed
change is a commit on `provenance`, listed here, and proposed upstream.
