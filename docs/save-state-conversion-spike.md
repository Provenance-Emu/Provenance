# Save State Porting / Conversion — Feasibility Spike

**Issue:** #3078 — Part of epic #2951
**Status:** Research complete — No actionable conversion mechanism for libretro cores

---

## Executive Summary

Save state format conversion (porting an old save to a new core version) is **not feasible
for the majority of Provenance's core library** (libretro-based cores). The libretro API
treats serialized data as an opaque binary blob with no standardized version metadata.

The one bright spot is **Mednafen-based native cores**, which embed a version number in
their save state header and implement per-subsystem migration logic internally. However,
this migration is done entirely inside the core — the app cannot intercept or influence it.

---

## Survey: Core-by-Core

### LibRetro Cores (PicoDrive, Beetle-PSX, SNES9x, Mupen64Plus, etc.)

**API:** `retro_serialize()` / `retro_unserialize()` / `retro_serialize_size()`

```c
// libretro.h — The complete serialization API:
RETRO_API size_t retro_serialize_size(void);
RETRO_API bool   retro_serialize(void *data, size_t size);
RETRO_API bool   retro_unserialize(const void *data, size_t size);
```

**Finding:** No version information whatsoever. The serialize functions write and read an
opaque binary blob whose internal layout is entirely private to the core. There is no:
- Version field
- Magic number exposed to the app layer
- Compatibility query API

**App-level intercept?** Not possible without modifying the core source.

**Conversion feasibility:** **Not feasible generically.** Any conversion would require:
1. Deep knowledge of each core's internal binary format
2. Per-core, per-version diff analysis to map old field offsets to new offsets
3. Hand-written migration code for every breaking core update

This is prohibitively expensive and error-prone.

### Mednafen Native Cores (PCE-CD, WonderSwan, Lynx, etc.)

**Format:** Binary file with a 32-byte header followed by named sections.

**Header layout** (from `state.cpp`, Mednafen 1.32.1):
```
Bytes  0– 7: "MDFNSVST" (8-byte magic — old saves may use 16-byte "MEDNAFENSVESTATE")
Bytes  8–15: epoch timestamp (uint64 LE)
Bytes 16–19: MEDNAFEN_VERSION_NUMERIC (uint32 LE) ← VERSION FIELD
Bytes 20–23: total_len | 0x80000000 endian flag (bit 31 set = big-endian data)
Bytes 24–27: preview width  (uint32 LE)
Bytes 28–31: preview height (uint32 LE)
...sections follow...
```

**Example version check in Mednafen's Saturn core (`ss.cpp`):**
```cpp
// EventsPacker::Restore() — active migration for states before 1.02.6
if(state_version < 0x00102600 && et >= 0x40000000)
    et = SS_EVENT_DISABLED_TS;

// NOTE: The following block exists in source but is commented out as of Mednafen 1.32.1.
// SS_EVENT_SCU_INT was removed from the event queue; the migration became a no-op.
/*
if(state_version < 0x00102800 && i == SS_EVENT_SCU_INT)
{
    eo = i;
    et = SS_EVENT_DISABLED_TS;
}
*/
```

**Finding:** Mednafen internally handles forward compatibility. When loading an old save
state, the `StateAction` callback receives the `stateversion` from the file header and
can apply migration logic. Minimum supported version is `0x900`; older states are rejected.

**App-level intercept?** The version number is readable at bytes 16–19 of the file, but
the migration logic lives entirely inside the core. The app cannot convert a state from
version X to version Y — that's the core's job, and Mednafen already does it.

**Conversion feasibility:** **Already handled by the core.** Mednafen-based cores either:
- Accept the old state and migrate internal fields automatically, or
- Reject states below the minimum supported version (`< 0x900`)

If a Mednafen state fails to load, it's because the state is below the minimum version
floor — no app-level conversion can help here.

### Other Native Cores

Native cores not based on Mednafen (e.g., any older ObjC/C++ implementations) would need
individual investigation. None were found to expose version metadata.

---

## App-Side State Wrapping: Could We Add Our Own Metadata?

One approach would be to **wrap** the core's serialized data in an app-level envelope
that adds a header with version info:

```
[Provenance envelope header]
  - magic: "PVSS" (4 bytes)
  - envelope_version: uint16 (2 bytes)
  - core_identifier: string (variable)
  - core_version: string (variable)
  - serialization_timestamp: uint64 (8 bytes)
[Core state blob]
  - raw output of retro_serialize() / core state method
```

**Pros:**
- Enables version mismatch detection at the app layer
- Future: if a core provides a state conversion tool/hook, the app can call it

**Cons:**
- **Breaking change**: Existing save states lack the envelope, requiring a migration
- **Core-agnostic**: The envelope adds metadata but cannot convert the state blob itself
- **Complexity**: All save/load paths must be updated to read/write the envelope
- **Net value is low**: We already store `createdWithCoreVersion` in Realm — the envelope
  adds nothing that isn't already tracked in the database

**Verdict:** Not worth implementing as a conversion mechanism. The envelope metadata is
already captured in Realm/SwiftData (`PVSaveState.createdWithCoreVersion`). Adding a
file-level envelope would be a large, breaking change for minimal gain.

---

## Conclusion

| Approach | Feasibility | Notes |
|---|---|---|
| LibRetro generic conversion | Not feasible | Opaque binary blobs; no API hooks |
| LibRetro per-core conversion | Theoretically possible | Requires deep per-core reverse engineering; prohibitively expensive |
| Mednafen conversion | Already done by core | Core handles migration internally; app cannot help further |
| App-level envelope wrapping | Feasible but low value | Metadata already in Realm; no conversion capability |
| Upstream API extension | Long-term option | File RFC to add `retro_get_state_version()` to libretro spec |

---

## Recommendations

1. **No conversion implementation** — The spike confirms this is not actionable for libretro
   cores. Engineering effort is better spent on detection (✅ done in #3081) and UX (✅ done).

2. **Mednafen cores** — Already handle versioning. No app changes needed.

3. **Long-term: libretro API extension** — File a feature request with the libretro project
   to add a standardized state version/compatibility query API (e.g.,
   `retro_get_state_version()` and `retro_can_load_state_version(uint32_t version)`).
   This would enable proper compatibility checks without opaque blob heuristics.

4. **User guidance** — The best mitigation for libretro cores is:
   - Warn users before loading a version-mismatched save state (✅ done in #3081)
   - Advise users to create new save states after core updates
   - Document this limitation in the wiki (see #3079)

---

## References

- `PVCoreBridgeRetro/Sources/retro/libretro-common/libretro.h` — libretro API
- `PVCoreBridgeRetro/Sources/PVLibRetro/PVLibRetroCore+Saves.m` — app-level save/load
- `Cores/Mednafen/Sources/mednafen/mednafen/src/state.cpp` — versioned Mednafen loader
- `Cores/Mednafen/Sources/mednafen/mednafen/src/git.h` — `StateAction` callback signature
- `Cores/Mednafen/Sources/mednafen/mednafen/src/ss/ss.cpp` — version-specific migration
