# Using SwiftData with CloudKit

**These rules only apply if the project is configured to use SwiftData with CloudKit.**

- Never use `@Attribute(.unique)` or `#Unique`; they are *not* supported in CloudKit, and when used will cause local data to fail too.
- All model properties must always either have default values or be marked as optional.
- All relationships must be marked optional.
- Indexes and subclasses are supported in CloudKit, as long as the correct OS release is used.

Keep in mind that CloudKit is designed for *eventual consistency* – any SwiftData code written with CloudKit support must be able to function if data has yet to synchronize.
