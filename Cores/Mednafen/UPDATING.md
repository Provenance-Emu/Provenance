# Updating Mednafen

Mednafen is compiled from the `Sources/mednafen/mednafen-src` submodule
([Provenance-Emu/mednafen-git](https://github.com/Provenance-Emu/mednafen-git)). Its
`master` branch mirrors upstream releases (one commit per release, from
`libretro-mirrors/mednafen-git`). `Provenance-master` is `master` plus our patches, one
commit each. [PROVENANCE_MODIFICATIONS.md](PROVENANCE_MODIFICATIONS.md) lists them.

## Moving to a new upstream release

1. Sync the fork's `master` with `libretro-mirrors/mednafen-git` so the new release
   commit is on it. You can use GitHub's "Sync fork" button, or fetch the mirror and
   push.
2. Rebase the patches onto it:

   ```bash
   cd Cores/Mednafen/Sources/mednafen/mednafen-src
   git fetch origin
   git checkout Provenance-master
   git rebase origin/master          # resolve conflicts patch by patch
   git push --force-with-lease origin Provenance-master
   ```

   If upstream already fixed something a patch works around, drop that commit
   during the rebase and update PROVENANCE_MODIFICATIONS.md.
3. Bump the pointer in this repo: `git add Cores/Mednafen/Sources/mednafen/mednafen-src`.
4. Update `Package.swift` to match upstream's file changes. Compare each module's
   `Makefile.am.inc` (for example `src/psx/Makefile.am.inc`) against the `Sources.*`
   lists, and add or remove files as needed.
5. Regenerate `Sources/mednafen/config/config.h` if `configure.ac` gained new checks or
   defines. Run `./configure` in a scratch copy of the tree and carry over only what
   changed.
6. Build `PVCoreMednafen-Dynamic` for iOS and tvOS, then load an existing save state
   for each system. Mednafen bumps its state format rarely, but a release can do it.

## Changing a Provenance patch

Commit the change on `Provenance-master` inside the submodule, push it, and then
commit the submodule pointer bump in this repo. Without the push, CI can't check out
the new submodule commit.
