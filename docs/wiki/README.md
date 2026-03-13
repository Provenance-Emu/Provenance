# Wiki Content for Provenance-EMU/wiki

These markdown files are intended to be added to the [Provenance-EMU/wiki](https://github.com/Provenance-EMU/wiki) repository.

## save-state-version-mismatches.md

Copy to: `save-states/version-mismatch.md` in the wiki repo.

> **Note:** The destination path `save-states/version-mismatch.md` matches the
> `WikiConstants.Paths.saveStateVersionMismatch` constant used by the app for
> in-app linking. Keep these in sync if you move the page.

### Add to SUMMARY.md (in the wiki repo)

Under the "Save States" section:

```markdown
* [Version Mismatch](save-states/version-mismatch.md)
```

Or as a child of the Save States overview:

```markdown
* [Save States](save-states/README.md)
  * [Version Mismatch](save-states/version-mismatch.md)
```

### In-App Link

The app links to this page from the version mismatch alert. Use:

- Raw URL: `https://raw.githubusercontent.com/Provenance-EMU/wiki/master/save-states/version-mismatch.md`
- Web URL: `https://wiki.provenance-emu.com/save-states/version-mismatch`

These URLs are generated automatically by `WikiConstants`:
```swift
WikiConstants.rawURL(for: WikiConstants.Paths.saveStateVersionMismatch)
WikiConstants.webURL(for: WikiConstants.Paths.saveStateVersionMismatch)
```
