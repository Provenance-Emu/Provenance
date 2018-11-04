# Change Log
All notable changes to this project will be documented in this file.

---

#### Enhancements
* Reduce computational complexity. #242
* Adapted for RxSwift 4.2

## [3.1.0](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/3.1.0)

* Xcode 10.0 compatibility.

## [3.0.2](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/3.0.2)

* Makes `configureSupplementaryView` optional for reload data source. #186

## [3.0.1](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/3.0.1)

* Adds custom logic to control should perform animated updates.
* Fixes SPM integration.

## [3.0.0](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/3.0.0)

* Adapted for RxSwift 4.0

## [3.0.0-rc.0](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/3.0.0-rc.0)

* Cleans up public interface to use initializers vs nillable properties and deprecates nillable properties in favor of passing parameters
through init.

## [2.0.2](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/2.0.2)

* Adds Swift Package Manager support

## [2.0.1](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/2.0.1)

* Fixes issue with CocoaPods and Carthage integration.

## [2.0.0](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/2.0.0)

* Adds `UIPickerView` extensions.
* Separates `Differentiator` from `RxDataSources`.

## [1.0.4](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.4)

#### Anomalies
* Fixed crash that happened when using a combination of `estimatedHeightForRow` and `tableFooterView`. #129

## [1.0.3](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.3)

#### Anomalies

* #84 Set data source sections even if view is not in view hierarchy.
* #93 Silence optional debug print warning in swift 3.1
* #96 Adds additional call to `invalidateLayout` after reloading data.

## [1.0.2](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.2)

* Fixes issue with performing batch updates on view that is not in view hierarchy.

## [1.0.1](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.1)

* Fixes invalid version in bundle id.
* Update CFBundleShortVersionString to current release version number.

## [1.0.0](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.0)

* Small polish of public interface.

## [1.0.0-rc.2](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.0-rc.2)

#### Features

* Makes rest of data source classes and methods open.
* Small polish for UI.
* Removes part of deprecated extensions.

## [1.0.0-rc.1](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.0-rc.1)

#### Features

* Makes data sources open.
* Adaptations for RxSwift 3.0.0-rc.1

## [1.0.0-beta.2](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.0-beta.2)

#### Features

* Adaptations for Swift 3.0

#### Fixes

* Improves collection view animated updates behavior.

## [1.0.0.beta.1](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/1.0.0.beta.1)

#### Features

* Adaptations for Swift 3.0

#### Fixes

* Fixes `moveItem`

## [0.9](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/0.8.1)

#### Possibly breaking changes

* Adds default IdentifiableType extensions for:
	* String
	* Int
	* Float

This can break your code if you've implemented those extensions locally. This can be easily solved by just removing local extensions.

#### Features

* Swift 2.3 compatible
* Improves mutability checkes. If data source is being mutated after binding, warning assert is triggered.
* Deprecates `cellFactory` in favor of `configureCell`.
* Improves runtime checks in DEBUG mode for correct `SectionModelType.init` implementation.

#### Fixes

* Fixes default value for `canEditRowAtIndexPath` and sets it to `false`.
* Changes DEBUG asserting behavior in case multiple items with same identity are found to printing warning message to terminal. Fallbacks as before to `reloadData`.

## [0.8.1](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/0.8.1)

#### Anomalies

* Fixes problem with `SectionModel.init`.

## [0.8](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/0.8)

#### Features

* Adds new example of how to present heterogeneous sections.

#### Anomalies

* Fixes old `AnimatableSectionModel` definition.
* Fixes problem with `UICollectionView` iOS 9 reordering features.

## [0.7](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/0.7)

#### Interface changes

* Adds required initializer to `SectionModelType.init(original: Self, items: [Item])` to support moving of table rows with animation.
* `rx_itemsAnimatedWithDataSource` deprecated in favor of just using `rx_itemsWithDataSource`.

#### Features

* Adds new example how to use delegates and reactive data sources to customize look.

#### Anomalies

* Fixes problems with moving rows and animated data source.

## [0.6.2](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/0.6.2)

#### Features

* Xcode 7.3 / Swift 2.2 support

## [0.6.1](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/0.6.1)

#### Anomalies

* Fixes compilation issues when `DEBUG` is defined.

## [0.6](https://github.com/RxSwiftCommunity/RxDataSources/releases/tag/0.6)

#### Features

* Adds `self` data source as first parameter to all closures. (**breaking change**)
* Adds `AnimationConfiguration` to enable configuring animation.
* Replaces binding error handling logic with `UIBindingObserver`.
