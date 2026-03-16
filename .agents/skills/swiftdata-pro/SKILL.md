---
name: swiftdata-pro
description: Writes, reviews, and improves SwiftData code using modern APIs and best practices. Use when reading, writing, or reviewing projects that use SwiftData.
license: MIT
metadata:
  author: Paul Hudson
  version: "1.0"
---

Write and review SwiftData code for correctness, modern API usage, and adherence to project conventions. Report only genuine problems - do not nitpick or invent issues.

Review process:

1. Check for core SwiftData issues using `references/core-rules.md`.
1. Check that predicates are safe and supported using `references/predicates.md`.
1. If the project uses CloudKit, check for CloudKit-specific constraints using `references/cloudkit.md`.
1. If the project targets iOS 18+, check for indexing opportunities using `references/indexing.md`.
1. If the project targets iOS 26+, check for class inheritance patterns using `references/class-inheritance.md`.

If doing partial work, load only the relevant reference files.


## Core Instructions

- Target Swift 6.2 or later, using modern Swift concurrency.
- The user strongly prefers to use SwiftData across the board. Do not suggest Core Data functionality unless it is a feature that cannot be solved with SwiftData.
- Do not introduce third-party frameworks without asking first.
- Use a consistent project structure, with folder layout determined by app features.


## Output Format

If the user asks for a review, organize findings by file. For each issue:

1. State the file and relevant line(s).
2. Name the rule being violated.
3. Show a brief before/after code fix.

Skip files with no issues. End with a prioritized summary of the most impactful changes to make first.

If the user asks you to write or improve code, follow the same rules above but make the changes directly instead of returning a findings report.

Example output:

### Destination.swift

**Line 8: Add an explicit delete rule for relationships.**

```swift
// Before
var sights: [Sight]

// After
@Relationship(deleteRule: .cascade, inverse: \Sight.destination) var sights: [Sight]
```

**Line 22: Do not use `isEmpty == false` in predicates – it crashes at runtime. Use `!` instead.**

```swift
// Before
#Predicate<Destination> { $0.sights.isEmpty == false }

// After
#Predicate<Destination> { !$0.sights.isEmpty }
```

### DestinationListView.swift

**Line 5: `@Query` must only be used inside SwiftUI views.**

```swift
// Before
class DestinationStore {
    @Query var destinations: [Destination]
}

// After
class DestinationStore {
    var modelContext: ModelContext

    func fetchDestinations() throws -> [Destination] {
        try modelContext.fetch(FetchDescriptor<Destination>())
    }
}
```

### Summary

1. **Data loss (high):** Missing delete rule on line 8 of Destination.swift means sights will be orphaned when a destination is deleted.
2. **Crash (high):** `isEmpty == false` on line 22 will crash at runtime – use `!isEmpty` instead.
3. **Incorrect behavior (high):** `@Query` on line 5 of DestinationListView.swift only works inside SwiftUI views.

End of example.


## References

- `references/core-rules.md` - autosaving, relationships, delete rules, property restrictions, and FetchDescriptor optimization.
- `references/predicates.md` - supported predicate operations, dangerous patterns that crash at runtime, and unsupported methods.
- `references/cloudkit.md` - CloudKit-specific constraints including uniqueness, optionality, and eventual consistency.
- `references/indexing.md` - database indexing for iOS 18+, including single and compound property indexes.
- `references/class-inheritance.md` - model subclassing for iOS 26+, including @available requirements, schema setup, and predicate filtering.
