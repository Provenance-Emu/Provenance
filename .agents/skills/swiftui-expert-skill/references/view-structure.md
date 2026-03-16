# SwiftUI View Structure Reference

## Table of Contents

- [View Structure Principles](#view-structure-principles)
- [Prefer Modifiers Over Conditional Views](#prefer-modifiers-over-conditional-views)
- [Extract Subviews, Not Computed Properties](#extract-subviews-not-computed-properties)
- [When @ViewBuilder Functions Are Acceptable](#when-viewbuilder-functions-are-acceptable)
- [When to Extract Subviews](#when-to-extract-subviews)
- [Container View Pattern](#container-view-pattern)
- [ZStack vs overlay/background](#zstack-vs-overlaybackground)
- [Compositing Group Before Clipping](#compositing-group-before-clipping)
- [Reusable Styling with ViewModifier](#reusable-styling-with-viewmodifier)
- [Skeleton Loading with Redacted Views](#skeleton-loading-with-redacted-views)
- [UIViewRepresentable Essentials](#uiviewrepresentable-essentials)
- [Summary Checklist](#summary-checklist)

## View Structure Principles

SwiftUI's diffing algorithm compares view hierarchies to determine what needs updating. Proper view composition directly impacts performance.

## Prefer Modifiers Over Conditional Views

**Prefer "no-effect" modifiers over conditionally including views.** When you introduce a branch, consider whether you're representing multiple views or two states of the same view.

### Use Opacity Instead of Conditional Inclusion

```swift
// Good - same view, different states
SomeView()
    .opacity(isVisible ? 1 : 0)

// Avoid - creates/destroys view identity
if isVisible {
    SomeView()
}
```

**Why**: Conditional view inclusion can cause loss of state, poor animation performance, and breaks view identity. Using modifiers maintains view identity across state changes.

### When Conditionals Are Appropriate

Use conditionals when you truly have **different views**, not different states:

```swift
// Correct - fundamentally different views
if isLoggedIn {
    DashboardView()
} else {
    LoginView()
}

// Correct - optional content
if let user {
    UserProfileView(user: user)
}
```

### Conditional View Modifier Extensions Break Identity

A common pattern is an `if`-based `View` extension for conditional modifiers. This changes the view's return type between branches, which destroys view identity and breaks animations:

```swift
// Problematic -- different return types per branch
extension View {
    @ViewBuilder func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition {
            transform(self)  // Returns T
        } else {
            self              // Returns Self
        }
    }
}
```

Prefer applying the modifier directly with a ternary or always-present modifier:

```swift
// Good -- same view identity maintained
Text("Hello")
    .opacity(isHighlighted ? 1 : 0.5)

// Good -- modifier always present, value changes
Text("Hello")
    .foregroundStyle(isError ? .red : .primary)
```

## Extract Subviews, Not Computed Properties

### The Problem with @ViewBuilder Functions

When you use `@ViewBuilder` functions or computed properties for complex views, the entire function re-executes on every parent state change:

```swift
// BAD - re-executes complexSection() on every tap
struct ParentView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Button("Tap: \(count)") { count += 1 }
            complexSection()  // Re-executes every tap!
        }
    }

    @ViewBuilder
    func complexSection() -> some View {
        // Complex views that re-execute unnecessarily
        ForEach(0..<100) { i in
            HStack {
                Image(systemName: "star")
                Text("Item \(i)")
                Spacer()
                Text("Detail")
            }
        }
    }
}
```

### The Solution: Separate Structs

Extract to separate `struct` views. SwiftUI can skip their `body` when inputs don't change:

```swift
// GOOD - ComplexSection body SKIPPED when its inputs don't change
struct ParentView: View {
    @State private var count = 0

    var body: some View {
        VStack {
            Button("Tap: \(count)") { count += 1 }
            ComplexSection()  // Body skipped during re-evaluation
        }
    }
}

struct ComplexSection: View {
    var body: some View {
        ForEach(0..<100) { i in
            HStack {
                Image(systemName: "star")
                Text("Item \(i)")
                Spacer()
                Text("Detail")
            }
        }
    }
}
```

### Why This Works

1. SwiftUI compares the `ComplexSection` struct (which has no properties)
2. Since nothing changed, SwiftUI skips calling `ComplexSection.body`
3. The complex view code never executes unnecessarily

## When @ViewBuilder Functions Are Acceptable

Use for small, simple sections (a few views, no expensive computation) that don't affect performance. `@ViewBuilder` functions work particularly well for static content that doesn't depend on any `@State` or `@Binding`, since SwiftUI won't need to diff them independently. Extract to a separate `struct` when the section is complex, depends on state, or needs to be skipped during re-evaluation.

## When to Extract Subviews

Extract complex views into separate subviews when:
- The view has multiple logical sections or responsibilities
- The view contains reusable components
- The view body becomes difficult to read or understand
- You need to isolate state changes for performance
- The view is becoming large (keep views small for better performance)

## Container View Pattern

### Avoid Closure-Based Content

Closures can't be compared, causing unnecessary re-renders:

```swift
// BAD - closure prevents SwiftUI from skipping updates
struct MyContainer<Content: View>: View {
    let content: () -> Content

    var body: some View {
        VStack {
            Text("Header")
            content()  // Always called, can't compare closures
        }
    }
}

// Usage forces re-render on every parent update
MyContainer {
    ExpensiveView()
}
```

### Use @ViewBuilder Property Instead

```swift
// GOOD - view can be compared
struct MyContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack {
            Text("Header")
            content  // SwiftUI can compare and skip if unchanged
        }
    }
}

// Usage - SwiftUI can diff ExpensiveView
MyContainer {
    ExpensiveView()
}
```

## ZStack vs overlay/background

Use `ZStack` to **compose multiple peer views** that should be layered together and jointly define layout.

Prefer `overlay` / `background` when you’re **decorating a primary view**.  
Not primarily because they don’t affect layout size, but because they **express intent and improve readability**: the view being modified remains the clear layout anchor.

A key difference is **size proposal behavior**:
- In `overlay` / `background`, the child view implicitly adopts the size proposed to the parent when it doesn’t define its own size, making decorative attachments feel natural and predictable.
- In `ZStack`, each child participates independently in layout, and no implicit size inheritance exists. This makes it better suited for peer composition, but less intuitive for simple decoration.

Use `ZStack` (or another container) when the “decoration” **must explicitly participate in layout sizing**—for example, when reserving space, extending tappable/visible bounds, or preventing overlap with neighboring views.

### Examples

```swift
// GOOD - decoration via overlay (layout anchored to button)
Button("Continue") { }
    .overlay(alignment: .trailing) {
        Image(systemName: "lock.fill").padding(.trailing, 8)
    }

// BAD - ZStack when overlay suffices (layout no longer anchored to button)
ZStack(alignment: .trailing) {
    Button("Continue") { }
    Image(systemName: "lock.fill").padding(.trailing, 8)
}

// GOOD - background shape takes parent size
HStack(spacing: 12) { Text("Inbox"); Text("Next") }
    .background { Capsule().strokeBorder(.blue, lineWidth: 2) }
```

## Compositing Group Before Clipping

**Always add `.compositingGroup()` before `.clipShape()` when clipping layered views (`.overlay` or `.background`).** Without it, each layer is antialiased separately and then composited. Where antialiased edges overlap — typically at rounded corners — you get visible color fringes (semi-transparent pixels of different colors blending together).

```swift
let shape = RoundedRectangle(cornerRadius: 16)

// BAD - each layer antialiased separately, producing color fringes at corners
Color.red
    .overlay(.white, in: shape)
    .clipShape(shape)
    .frame(width: 200, height: 150)

// GOOD - layers composited first, antialiasing applied once during clipping
Color.red
    .overlay(.white, in: .rect)
    .compositingGroup()
    .clipShape(shape)
    .frame(width: 200, height: 150)
```

`.compositingGroup()` forces all child layers to be rendered into a single offscreen buffer before the clip is applied. This means antialiasing only happens once — on the final composited result — eliminating the fringe artifacts.

## Reusable Styling with ViewModifier

Extract repeated modifier combinations into a `ViewModifier` struct. Expose via a `View` extension for autocompletion:

```swift
private struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 12))
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
```

### Custom ButtonStyle

Use the `ButtonStyle` protocol for reusable button designs. Use `PrimitiveButtonStyle` only when you need custom interaction handling (e.g., simultaneous gestures):

```swift
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.smooth, value: configuration.isPressed)
    }
}
```

### Discoverability with Static Member Lookup

Make custom styles and modifiers discoverable via leading-dot syntax:

```swift
extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { .init() }
}

// Usage: .buttonStyle(.primary)
```

This pattern works for any SwiftUI style protocol (`ButtonStyle`, `ListStyle`, `ToggleStyle`, etc.).

## Skeleton Loading with Redacted Views

Use `.redacted(reason: .placeholder)` to show skeleton views while data loads. Use `.unredacted()` to opt out specific views:

```swift
VStack(alignment: .leading) {
    Text(article?.title ?? String(repeating: "X", count: 20))
        .font(.headline)
    Text(article?.author ?? String(repeating: "X", count: 12))
        .font(.subheadline)
    Text("SwiftLee")
        .font(.caption)
        .unredacted()
}
.redacted(reason: article == nil ? .placeholder : [])
```

Apply `.redacted` on a container to redact all children at once.

## UIViewRepresentable Essentials

When bridging UIKit views into SwiftUI:

- `makeUIView(context:)` is called **once** to create the UIKit view
- `updateUIView(_:context:)` is called on **every SwiftUI redraw** to sync state
- The representable struct itself is **recreated on every redraw** -- avoid heavy work in its init
- Use a `Coordinator` for delegate callbacks and two-way communication

```swift
struct MapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        map.setCenter(coordinate, animated: true)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, MKMapViewDelegate { }
}
```

## Summary Checklist

- [ ] Prefer modifiers over conditional views for state changes
- [ ] Avoid `if`-based conditional modifier extensions (they break view identity)
- [ ] Complex views extracted to separate subviews
- [ ] Views kept small for better performance
- [ ] `@ViewBuilder` functions only for simple sections
- [ ] Container views use `@ViewBuilder let content: Content`
- [ ] Extract views when they have multiple responsibilities or become hard to read
- [ ] Reusable styling extracted into `ViewModifier` or `ButtonStyle`
- [ ] Custom styles exposed via static member lookup for discoverability
- [ ] Use `.redacted(reason: .placeholder)` for skeleton loading states
- [ ] `.compositingGroup()` before `.clipShape()` on layered views (overlay/background) to avoid antialiasing fringes
- [ ] UIViewRepresentable: heavy work in make/update, not in struct init
