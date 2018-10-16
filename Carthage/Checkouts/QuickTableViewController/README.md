# QuickTableViewController

[![Build Status](https://travis-ci.org/bcylin/QuickTableViewController.svg?branch=master)](https://travis-ci.org/bcylin/QuickTableViewController)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![CocoaPods Compatible](https://img.shields.io/cocoapods/v/QuickTableViewController.svg)](https://cocoapods.org/pods/QuickTableViewController)
![Platform](https://img.shields.io/cocoapods/p/QuickTableViewController.svg)
[![codecov](https://codecov.io/gh/bcylin/QuickTableViewController/branch/master/graph/badge.svg)](https://codecov.io/gh/bcylin/QuickTableViewController)
![Swift 4.1](https://img.shields.io/badge/Swift-4.1-orange.svg)

A simple way to create a table view for settings, including:

* Table view cells with `UISwitch`
* Table view cells with center aligned text for tap actions
* A section that provides mutually exclusive options
* Actions performed when the row reacts to the user interaction
* Customizable table view cell image, cell style and accessory type

<img src="https://bcylin.github.io/QuickTableViewController/img/screenshots.png" width="80%"></img>

## Usage

Set up `tableContents` in `viewDidLoad`:

```swift
import QuickTableViewController

class ViewController: QuickTableViewController {

  override func viewDidLoad() {
    super.viewDidLoad()

    tableContents = [
      Section(title: "Switch", rows: [
        SwitchRow(title: "Setting 1", switchValue: true, action: { _ in }),
        SwitchRow(title: "Setting 2", switchValue: false, action: { _ in }),
      ]),

      Section(title: "Tap Action", rows: [
        TapActionRow(title: "Tap action", action: { [weak self] in self?.showAlert($0) })
      ]),

      Section(title: "Navigation", rows: [
        NavigationRow(title: "CellStyle.default", subtitle: .none, icon: .named("gear")),
        NavigationRow(title: "CellStyle", subtitle: .belowTitle(".subtitle"), icon: .named("globe")),
        NavigationRow(title: "CellStyle", subtitle: .rightAligned(".value1"), icon: .named("time"), action: { _ in }),
        NavigationRow(title: "CellStyle", subtitle: .leftAligned(".value2"))
      ]),

      RadioSection(title: "Radio Buttons", options: [
        OptionRow(title: "Option 1", isSelected: true, action: didToggleOption()),
        OptionRow(title: "Option 2", isSelected: false, action: didToggleOption()),
        OptionRow(title: "Option 3", isSelected: false, action: didToggleOption())
      ], footer: "See RadioSection for more details.")
    ]
  }

  // MARK: - Actions

  private func showAlert(_ sender: Row) {
    // ...
  }

  private func didToggleOption() -> (Row) -> Void {
    return { [weak self] row in
      // ...
    }
  }

}
```

### NavigationRow

#### Subtitle Styles

```swift
NavigationRow(title: "UITableViewCellStyle.default", subtitle: .none)
NavigationRow(title: "UITableViewCellStyle", subtitle: .belowTitle(".subtitle")
NavigationRow(title: "UITableViewCellStyle", subtitle: .rightAligned(".value1")
NavigationRow(title: "UITableViewCellStyle", subtitle: .leftAligned(".value2"))
```

#### Disclosure Indicator

* A `NavigationRow` with an `action` will be displayed in a table view cell with `.disclosureIndicator`.
* The `action` will be invoked when the table view cell is selected.

#### Images

```swift
enum Icon {
  case named(String)
  case image(UIImage)
  case images(normal: UIImage, highlighted: UIImage)
}
```

* Images in table view cells can be set by specifying the `icon` of each row.
* Table view cells in `UITableViewCellStyle.value2` will not show the image view.

### SwitchRow

* A `SwitchRow` is representing a table view cell with a `UISwitch` as its `accessoryView`.
* The `action` will be invoked when the switch value changes.
* The subtitle is disabled in `SwitchRow `.

### TapActionRow

* A `TapActionRow` is representing a button-like table view cell.
* The `action` will be invoked when the table view cell is selected.
* The icon and subtitle are disabled in `TapActionRow`.

### OptionRow

* An `OptionRow` is representing a table view cell with `.checkmark`.
* The subtitle is disabled in `OptionRow`.
* The `action` will be invoked when the selected state is toggled.

```swift
let didToggleOption: (Row) -> Void = { [weak self] in
  if let option = $0 as? OptionRowCompatible, option.isSelected {
    // to exclude the option that's toggled off
  }
}
```

### RadioSection

* `OptionRow` can be used with or without `RadioSection`, which allows only one selected option.
* Setting `alwaysSelectsOneOption` to true will keep one of the options selected.

## Customization

### Rows

All rows must conform to [`Row`](https://github.com/bcylin/QuickTableViewController/blob/develop/Source/Protocol/Row.swift) and [`RowStyle`](https://github.com/bcylin/QuickTableViewController/blob/develop/Source/Protocol/RowStyle.swift). Additional interface to work with specific types of rows are represented as different [protocols](https://github.com/bcylin/QuickTableViewController/blob/develop/Source/Protocol/RowCompatible.swift):

* `NavigationRowCompatible`
* `OptionRowCompatible`
* `SwitchRowCompatible`
* `TapActionRowCompatible`

### Cell Classes

A customized table view cell type can be specified to rows during initialization.

```swift
// Default is UITableViewCell.
NavigationRow<CustomCell>(title: "Navigation", subtitle: .none)

// Default is SwitchCell.
SwitchRow<CustomSwitchCell>(title: "Switch", switchValue: true, action: { _ in })

// Default is TapActionCell.
TapActionRow<CustomTapActionCell>(title: "Tap", action: { _ in })

// Default is UITableViewCell.
OptionRow<CustomOptionCell>(title: "Option", isSelected: true, action: { _ in })
```

Since the rows carry different cell types, they can be matched using either the concrete types or the related protocol:

```swift
let action: (Row) -> Void = {
  switch $0 {
  case let option as OptionRow<CustomOptionCell>:
    // only matches the option rows with a specific cell type
  case let option as OptionRowCompatible:
    // matches all option rows
  default:
    break
  }
}
```

### Overwrite Default Configuration

You can use `register(_:forCellReuseIdentifier:)` to specify custom cell types for the [table view](https://github.com/bcylin/QuickTableViewController/blob/develop/Source/QuickTableViewController.swift#L100-L102) to use. See [CustomizationViewController](https://github.com/bcylin/QuickTableViewController/blob/develop/Example-iOS/ViewControllers/CustomizationViewController.swift) for the cell reuse identifiers of different rows.

Table view cell classes that conform to `Configurable` can take the customization during `tableView(_:cellForRowAt:)`:

```swift
protocol Configurable {
  func configure(with row: Row & RowStyle)
}
```

Additional setups can also be added to each row using the `customize` closure:

```swift
protocol RowStyle {
  var customize: ((UITableViewCell, Row & RowStyle) -> Void)? { get }
}
```

The `customize` closure overwrites the `Configurable` setup.

### UIAppearance

As discussed in issue [#12](https://github.com/bcylin/QuickTableViewController/issues/12), UIAppearance customization works when the cell is dequeued from the storyboard. One way to work around this is to register nib objects to the table view. Check out [AppearanceViewController](https://github.com/bcylin/QuickTableViewController/blob/develop/Example-iOS/ViewControllers/AppearanceViewController.swift) for the setup.

## tvOS Differences

* `UISwitch` is replaced by a checkmark in `SwitchCell`.
* `TapActionCell` does not use center aligned text.
* Cell image view's left margin is 0.

## Limitation

> When to use **QuickTableViewController**?

QuickTableViewController is good for presenting static table contents, where the sections and rows don't change dynamically after `viewDidLoad`.

It's possible to update the table contents by replacing a specific section or row. Using different styles on each row requires additional configuration as described in the [Customization](#customization) section.

> When **not** to use it?

QuickTableViewController is not designed for inserting and deleting rows. It doesn't handle table view reload animation either. If your table view needs to update dynamically, you might want to consider other solutions such as [IGListKit](https://github.com/Instagram/IGListKit).

## Documentation

* [QuickTableViewController Reference](https://bcylin.github.io/QuickTableViewController)
* [Example Project](https://github.com/bcylin/QuickTableViewController/tree/develop/Example)

## Requirements

QuickTableViewController | iOS  | tvOS | Xcode | Swift
------------------------ | :--: | :--: | :---: | :---:
`~> 0.1.0`               | 8.0+ | -    | 6.4   | 1.2
`~> 0.2.0`               | 8.0+ | -    | 7.0   | 2.0
`~> 0.3.0`               | 8.0+ | -    | 7.3   | 2.2
`~> 0.4.0`               | 8.0+ | -    | 8.0   | 2.3
`~> 0.5.0`               | 8.0+ | -    | 8.0   | 3.0
`~> 0.6.0`               | 8.0+ | -    | 8.3   | 3.1
`~> 0.7.0`               | 8.0+ | -    | 9.0   | 3.2
`~> 0.8.0`               | 8.0+ | -    | 9.1   | 4.0
`~> 0.9.0`               | 8.0+ | -    | 9.3   | 4.1
`~> 1.0.0`               | 8.0+ | 9.0+ | 9.4   | 4.1

## Installation

### Use [CocoaPods](http://guides.cocoapods.org/)

Create a `Podfile` with the following specification and run `pod install`.

```rb
platform :ios, '8.0'
use_frameworks!

pod 'QuickTableViewController'
```

### Use [Carthage](https://github.com/Carthage/Carthage)

Create a `Cartfile` with the following specification and run `carthage update QuickTableViewController`.
Follow the [instructions](https://github.com/Carthage/Carthage#adding-frameworks-to-an-application) to add the framework to your project.

```
github "bcylin/QuickTableViewController"
```

### Use Git Submodule

```
git submodule add -b master git@github.com:bcylin/QuickTableViewController.git Dependencies/QuickTableViewController
```

* Drag **QuickTableViewController.xcodeproj** to your app project as a subproject.
* On your application target's **Build Phases** settings tab, add **QuickTableViewController-iOS** to **Target Dependencies**.

## License

QuickTableViewController is released under the MIT license.
See [LICENSE](https://github.com/bcylin/QuickTableViewController/blob/master/LICENSE) for more details.
Image source: [iconmonstr](http://iconmonstr.com/license/).
