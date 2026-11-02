# Provenance Plus policy implementation checks

Scope: policy UI, CloudKit content scoping and optional support prompts. Isolated
from audited `efe15726154b3a907b148d1c035ff7e289a6e72a`; original working edits retained.

- [x] Cloud settings, Audio Engine, Disable Auto Lock and Require Password controls accessible without Plus.
- [x] Password/authentication behavior unchanged; only the control's premium wrapper removed.
- [x] Free CloudKit CTA chooses metadata/save scope before enabling sync; pending ownership cannot alter scope.
- [x] Runtime iOS scope reconciliation preserves the stored desired scope and master sync flag; pending/unpaid ownership restricts ROM automation while saves continue. Renewal restores the desired scope. Entitlement integration calls this helper separately.
- [x] CloudKit metadata-only bulk and push paths skip automatic ROM payload downloads; direct ROM uploads also respect content scope. Manual game recovery remains accessible.
- [x] Battery-save/non-database sync remains independent of the ROM-content filter. tvOS's existing free options remain accessible.
- [x] Support prompt moves from game launch to successful running-session quit completion, skips custom quit completion flows and occupied/inactive presenters.
- [x] Immediate Maybe Later and permanent Don't ask again. Pending/known ownership suppresses prompts.
- [x] Existing 10/25/15-session thresholds and four-day floor retained; no new recurring cadence.
- [x] Native `swift test --package-path PVSettings --skip-update`: 278 tests in 39 suites passed.
- [x] Eight scope/schedule regression tests pass in an isolated Foundation-only Swift package using the production implementation (dependency protocol shims only).
- [x] Swift parser checks and whitespace diff check; lint run on changed Swift files (existing CloudKit large-file/type-body and duplicate-condition errors remain).

Before acceptance:

- [ ] Run host-backed iOS/tvOS UI tests and genuine unpaid/lapsed App Store entitlement flows; parser checks are not typechecking/runtime validation.
- [ ] Exercise CloudKit save-state, SRAM/memory-card, settings/progress, push and cold-launch sync with real accounts, including in-flight sync when ownership expires. Admission changes do not cancel an already running transfer.
- [ ] Audit/scopingly refactor the separate legacy iCloud Drive transport. Its folder migration/query/download paths do not consistently honor CloudKit content preference. This patch does not claim an authoritative paid gate on those legacy routes and does not force a potentially destructive migration.
- [ ] Verify no support/review/error prompt overlap in the app host; no existing review call site found in PVUI/Provenance Swift sources during this change.

No full app builds, physical-device operations, purchases, publishing, signing
changes, review submissions or website deployments performed. Recording, streaming,
clips, themes/icons/UI mode and other undecided extras retain existing gates.
