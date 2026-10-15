# PVPatchEngine

Applies ROM and disc patches by streaming to an output file, so a 1.4 GB GameCube image or an
8.5 GB Wii image patches within a fixed memory budget on a phone. No dependencies; iOS 17,
tvOS 17 and macOS 14 (so `swift test` runs on the Mac).

## Formats

| Format | Notes |
| --- | --- |
| IPS | 3-byte offsets, RLE records, optional 3-byte truncation trailer. May extend the image. |
| IPS32 | 4-byte offsets, `EEOF` terminator. Header `IPS32`, or `PATCH` with a `.ips32` extension. |
| BPS | Source, target and patch CRC32. SourceRead / TargetRead / SourceCopy / TargetCopy. |
| UPS | Source, target and patch CRC32. Applies in either direction; the direction is picked from the source. |
| PPF | Versions 1, 2 and 3 (v2 size and block check, v3 block check, 8-byte offsets, undo data, `FILE_ID.DIZ` trailer). Never grows the image. |
| xdelta3 / VCDIFF | The vendored xdelta3 decoder. Secondary compression: DJW and FGK. LZMA is not built in (see below). |

## API

```swift
PatchEngine.detectFormat(_ patchURL: URL) -> PatchFormat?            // by magic bytes
PatchEngine.inspect(patch: URL) throws -> PatchInfo                  // declared sizes and CRC32s
PatchEngine.apply(patch:source:output:options:progress:) async throws -> PatchResult
```

`apply` writes to `<output>.partial` and renames it onto `output` once the data is on disk. The partial
file is removed on failure and on cancellation, and an existing `output` is left alone unless the patch
succeeds. Cancel by cancelling the calling `Task`; the work stops between 2 MiB chunks and throws
`PatchError.cancelled`. `progress` is called from a background thread with a fraction over the whole
operation (source verification and writing).

`PatchOptions.ignoreSourceChecksum` is honoured by every format that checks its source:

- BPS, UPS: the source CRC32 is not computed. The patched result then usually differs from the target
  the patch describes, so a target CRC32 mismatch is returned in `PatchResult.ignoredTargetMismatch`
  instead of thrown. The patch's own CRC32 is always checked.
- PPF: the size and block checks are skipped.
- xdelta3: the declared source size and the per-window adler32 are not checked.

Errors are `PatchError`: `sourceMismatch(expected:actual:)` (CRC32, or adler32 for xdelta3),
`sourceSizeMismatch`, `targetMismatch`, `truncatedPatch`, `corruptPatch(String)`, `unsupportedFormat`,
`unsupportedSecondaryCompression`, `outputTooLarge`, `cancelled`, `io(Error)`.

Behaviour worth knowing:

- BPS and UPS verify the patch CRC32 first, so a patch cut anywhere but the very start reports
  `corruptPatch` rather than `truncatedPatch`. IPS, PPF and xdelta3 report `truncatedPatch`.
- An xdelta3 patch cut exactly between two windows decodes "successfully": VCDIFF carries no total length.
  A patch cut inside a window is caught.
- `inspect` on an xdelta3 patch reports `targetSize` and `minimumSourceSize` (the furthest source byte any window reads: a
  lower bound, because VCDIFF does not record the source size); `sourceSize` and the CRC32s are nil.
- xdelta3 cannot tell a wrong source from a damaged patch: both fail the window adler32 and are reported
  as `sourceMismatch`.
- UPS requires the source size to equal the input size (forward) or output size (reverse), because a longer
  image can share its first bytes with a shorter one.
- BPS accepts a source longer than the declared size when its first `sourceSize` bytes match (as
  Provenance's patcher did).
- `PatchOptions.maxOutputSize` (default 64 GiB) bounds what a patch may produce; beyond it
  `outputTooLarge` is thrown before the work starts, or when an IPS record would extend the image past it.

## Memory model

Nothing is read whole and nothing is memory mapped. Files are accessed with `pread` / `pwrite` through
fixed buffers: 2 MiB for copies, checksum passes and sequential output, 256 KiB for reading the patch, 4 MiB
for the xdelta3 source-block cache (32 blocks of 128 KiB). Every offset and size is 64-bit; outputs larger than
4 GiB are exercised by the tests on sparse images.

- IPS, IPS32, PPF: the source is copied to the output in chunks, then the records are written in place.
- UPS: one pass over the output, XOR-ing patch bytes onto source bytes read in chunks.
- BPS: one pass over the output. SourceCopy reads the source and TargetCopy reads the output back through
  buffered preads. An overlapping TargetCopy (distance shorter than length) repeats the bytes just written, as
  the format requires, using a replicated pattern buffer instead of a byte loop.
- xdelta3: patch bytes go in, output chunks are written as they appear, source blocks are served on demand.
  The decoder holds one target window at a time (xdelta3's default is 8 MiB); windows larger than 64 MiB are
  rejected. The decoder, not the engine, allocates that window and its delta sections, so xdelta3 peak memory is
  a small multiple of the window size.

Measured by the tests on 4.5 GB sparse images: about 6 MiB above the process's starting resident size for BPS.

## xdelta3 and licences

`Sources/CXdelta3` is the xdelta3 decoder, unmodified, from `jmacd/xdelta` branch `release3_1_apl` at
`7508fd2a823443b1f0173ca361620f21d62a7d37` (the binary reports itself as 3.1.1). The `v3.1.0` tag carries
GPL-2.0 headers, so it is not used. Compared with the tag, `xdelta3.c`, `xdelta3-decode.h`, `xdelta3-cfgs.h` and
`xdelta3-lzma.h` differ only in the licence header. The other vendored headers differ by portability edits
(`xdelta3.h`: Windows guards, a `static_assert` check of the `SIZEOF_*` defines, `extern "C"`, a `PRINTF_ATTRIBUTE`
fallback; `const` on two checksum-update parameters in `xdelta3-internal.h`) and moved comments. The licence
text is `Sources/CXdelta3/LICENSE`. Only the files the decoder needs are vendored. The encoder is compiled
(`xdelta3-fgk.h` does not build without it) but unused. `pv_xd3_shim.c` is a small C facade so Swift never
sees the `xd3_*` types; it also exposes zlib's `crc32`, which is why the package links `libz`.

Secondary compressors: DJW and FGK are enabled. LZMA is disabled: the iOS, tvOS and macOS SDKs ship
`liblzma.tbd` but no `lzma.h`, and the xdelta3 LZMA code needs the header. Patches made with `-S lzma` (the
xdelta3 default when built with LZMA) fail up front with `unsupportedSecondaryCompression`. Supporting them means
vendoring xz-utils headers (public domain) and linking `liblzma`.

The IPS, BPS, UPS and PPF code is adapted from Provenance `PVPatching` (Copyright © 2026 Provenance Emu), rewritten
to stream. The Provenance "ignore checksum" option never reached BPS or UPS; here it does.

## Tests

`swift test` runs about 75 tests, including three that patch a sparse 4.5 GB image (about 17 seconds, 4.5 GB
of scratch disk at a time; skipped when less than 20 GB is free). The xdelta3 fixtures are in
`Tests/PVPatchEngineTests/Fixtures` with the commands that produced them.
