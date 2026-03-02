---
applyTo: "**/*.swift"
---

## Swift Code Standards

1. **Async/await** — prefer `async/await` over Combine or callback-based APIs
2. **Concurrency safety** — use `@Sendable`, `actor`, and proper isolation; only use `@unchecked Sendable` when thread-safety is manually guaranteed (e.g., dispatch queue confinement) and the compiler cannot verify it
3. **Optional handling** — use `guard let` / `if let`; avoid force-unwrap (`!`) in production paths
4. **Line length** — max 200 characters (enforced by `.swiftlint.yml`)
5. **Indentation** — 4 spaces; no indent for `case` in `switch`
6. **`force_cast` / `force_try`** — allowed as warnings; do not remove existing uses
7. **Realm objects** — thread-confined; pass `ObjectId` or call `.freeze()` before crossing thread boundaries
8. **Module imports** — import only the `PV*` modules you need; see module dependency tiers in `.github/copilot-instructions.md`

## Validation

After editing Swift files, lint with:
```bash
swiftlint lint --path <file> --config .swiftlint.yml
```

For Tier 0–2 modules, also verify the module still builds:
```bash
cd PV<Module> && swift build
```
