# Azahar patch stack

Submodule `Cores/Azahar/azahar` tracks `Provenance-Emu/azahar` branch `provenance`
= `azahar-emu/azahar` master + the commits below. Bump with
`git -C Cores/Azahar/azahar fetch origin provenance && git -C Cores/Azahar/azahar checkout origin/provenance`,
then `python3 Cores/Azahar/build_azahar_core.py --clean --all-platforms`.

Upstream base: c9e1e946a0b5d30a58ae14dee83c1f203a49622d (2026-10-06)
Fork head:     ec05dab5f2e7c6352bfb2c6dc73bc87a083776e3

| # | Commit subject | Upstream PR | Status |
|---|---|---|---|
| 1 | common: build apple_utils.mm only on macOS | (open after first green build) | carried |
| 2 | vk_platform: use the frontend driver library on all platforms | (open after first green build) | carried |
| 3 | audio_core: add CoreAudio sink and input (ENABLE_COREAUDIO) | (open after first green build) | carried |
| 4 | cmake: only install the pre-commit hook when .git is a directory | (open after first green build) | carried |

Rule: no file under `Cores/Azahar/azahar` is ever shadowed or edited in place. A needed
change is a commit on `provenance`, listed here, and proposed upstream.
