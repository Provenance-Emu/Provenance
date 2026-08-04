# App Store screenshots

PNGs here are **gitignored** — they are large derived artifacts (hundreds of MB per
release), for the same reason the custom core dylibs are not in git.

They live as release assets in the media store instead:

```bash
Scripts/media-assets.sh fetch      # before `fastlane deliver`, or on a fresh clone
Scripts/media-assets.sh upload     # after regenerating a set
Scripts/media-assets.sh list       # what exists locally vs in the store
```

Layout follows `deliver`'s conventions:

- `en-US/`, `de-DE/`, … — iPhone and iPad screenshots (deliver infers the device
  from image dimensions)
- `appleTV/en-US/` — Apple TV screenshots (3840×2160 or 1920×1080)

Sizes used for 3.4: iPhone 6.9" 1320×2868 (portrait) / 2868×1320 (landscape),
iPad 13" 2064×2752 / 2752×2064, Apple TV 3840×2160.
