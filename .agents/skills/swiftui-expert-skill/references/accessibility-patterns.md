# SwiftUI Accessibility Patterns Reference

## Table of Contents

- [Core Principle](#core-principle)
- [Dynamic Type with @ScaledMetric](#dynamic-type-with-scaledmetric)
- [Accessibility Traits](#accessibility-traits)
- [Element Grouping](#element-grouping)
- [Custom Controls](#custom-controls)
- [Summary Checklist](#summary-checklist)

## Core Principle

Prefer `Button` over `onTapGesture` for tappable elements. `Button` provides VoiceOver support, focus handling, and proper traits for free.

## Dynamic Type with @ScaledMetric

System `Text` scales with Dynamic Type automatically. For custom numeric values (padding, image sizes, spacing), use `@ScaledMetric`:

```swift
struct ProfileHeader: View {
    @ScaledMetric private var avatarSize = 60.0
    @ScaledMetric private var spacing = 12.0

    var body: some View {
        HStack(spacing: spacing) {
            Image("avatar")
                .resizable()
                .frame(width: avatarSize, height: avatarSize)
            Text("Username")
        }
    }
}
```

Specify a `relativeTo` text style when the value should scale relative to a specific font size:

```swift
@ScaledMetric(relativeTo: .caption) private var iconSize = 16.0
```

## Accessibility Traits

Use `accessibilityAddTraits` and `accessibilityRemoveTraits` for state-driven traits:

```swift
Text(item.title)
    .accessibilityAddTraits(item.isSelected ? [.isSelected, .isButton] : .isButton)
```

Use `.disabled(true)` to make VoiceOver announce "Dimmed" for non-interactive elements.

## Element Grouping

### .combine -- Auto-join child labels

```swift
HStack {
    Image(systemName: "star.fill")
    Text("Favorites")
    Text("(\(count))")
}
.accessibilityElement(children: .combine)
```

VoiceOver reads all child labels as one element, separated by commas.

### .ignore -- Manual label for container

```swift
HStack {
    Text(item.name)
    Spacer()
    Text(item.price)
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("\(item.name), \(item.price)")
```

### .contain -- Semantic grouping

```swift
HStack {
    ForEach(tabs) { tab in
        TabButton(tab: tab)
    }
}
.accessibilityElement(children: .contain)
.accessibilityLabel("Tab bar")
```

VoiceOver announces the container name when focus enters/exits.

## Custom Controls

### Adjustable controls (increment/decrement)

```swift
PageControl(selectedIndex: $selectedIndex, pageCount: pageCount)
    .accessibilityElement()
    .accessibilityValue("Page \(selectedIndex + 1) of \(pageCount)")
    .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment:
            guard selectedIndex < pageCount - 1 else { break }
            selectedIndex += 1
        case .decrement:
            guard selectedIndex > 0 else { break }
            selectedIndex -= 1
        @unknown default:
            break
        }
    }
```

### Representing custom views as native controls

When a custom view should behave like a native control for accessibility:

```swift
HStack {
    Text(label)
    Toggle("", isOn: $isOn)
}
.accessibilityRepresentation {
    Toggle(label, isOn: $isOn)
}
```

### Label-content pairing

```swift
@Namespace private var ns

HStack {
    Text("Volume")
        .accessibilityLabeledPair(role: .label, id: "volume", in: ns)
    Slider(value: $volume)
        .accessibilityLabeledPair(role: .content, id: "volume", in: ns)
}
```

## Summary Checklist

- [ ] Use `Button` instead of `onTapGesture` for tappable elements
- [ ] Use `@ScaledMetric` for custom values that should scale with Dynamic Type
- [ ] Group related elements with `accessibilityElement(children:)`
- [ ] Provide `accessibilityLabel` when default labels are unclear
- [ ] Use `accessibilityRepresentation` for custom controls
- [ ] Use `accessibilityAdjustableAction` for increment/decrement controls
- [ ] Ensure navigation flow is logical when using VoiceOver grouping
