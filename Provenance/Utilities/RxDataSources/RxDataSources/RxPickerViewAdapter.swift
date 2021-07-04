//
//  RxPickerViewAdapter.swift
//  RxDataSources
//
//  Created by Sergey Shulga on 04/07/2017.
//  Copyright © 2017 kzaher. All rights reserved.
//

#if os(iOS)

import Foundation
import UIKit
#if !RX_NO_MODULE
    import RxSwift
    import RxCocoa
#endif

/// A reactive UIPickerView adapter which uses `func pickerView(UIPickerView, titleForRow: Int, forComponent: Int)` to display the content
/**
 Example:
 
let adapter = RxPickerViewStringAdapter<[T]>(...)
 
items
 .bind(to: firstPickerView.rx.items(adapter: adapter))
 .disposed(by: disposeBag)
 
 */
open class RxPickerViewStringAdapter<Components>: RxPickerViewDataSource<Components>, UIPickerViewDelegate {
    /**
     - parameter dataSource
     - parameter pickerView
     - parameter components
     - parameter row
     - parameter component
    */
    public typealias TitleForRow = (
        _ dataSource: RxPickerViewStringAdapter<Components>,
        _ pickerView: UIPickerView,
        _ components: Components,
        _ row: Int,
        _ component: Int
    ) -> String?
    
    private let titleForRow: TitleForRow

    /**
     - parameter components: Initial content value.
     - parameter numberOfComponents: Implementation of corresponding delegate method.
     - parameter numberOfRowsInComponent: Implementation of corresponding delegate method.
     - parameter titleForRow: Implementation of corresponding adapter method that converts component to `String`.
     */
    public init(components: Components,
                numberOfComponents: @escaping NumberOfComponents,
                numberOfRowsInComponent: @escaping NumberOfRowsInComponent,
                titleForRow: @escaping TitleForRow) {
        self.titleForRow = titleForRow
        super.init(components: components,
                   numberOfComponents: numberOfComponents,
                   numberOfRowsInComponent: numberOfRowsInComponent)
    }
    
    open func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return titleForRow(self, pickerView, components, row, component)
    }
}

/// A reactive UIPickerView adapter which uses `func pickerView(UIPickerView, viewForRow: Int, forComponent: Int, reusing: UIView?)` to display the content
/**
 Example:
 
 let adapter = RxPickerViewAttributedStringAdapter<[T]>(...)
 
 items
 .bind(to: firstPickerView.rx.items(adapter: adapter))
 .disposed(by: disposeBag)
 
 */
open class RxPickerViewAttributedStringAdapter<Components>: RxPickerViewDataSource<Components>, UIPickerViewDelegate {
    /**
     - parameter dataSource
     - parameter pickerView
     - parameter components
     - parameter row
     - parameter component
    */
    public typealias AttributedTitleForRow = (
        _ dataSource: RxPickerViewAttributedStringAdapter<Components>,
        _ pickerView: UIPickerView,
        _ components: Components,
        _ row: Int,
        _ component: Int
    ) -> NSAttributedString?
    
    private let attributedTitleForRow: AttributedTitleForRow

    /**
     - parameter components: Initial content value.
     - parameter numberOfComponents: Implementation of corresponding delegate method.
     - parameter numberOfRowsInComponent: Implementation of corresponding delegate method.
     - parameter attributedTitleForRow: Implementation of corresponding adapter method that converts component to `NSAttributedString`.
     */
    public init(components: Components,
                numberOfComponents: @escaping NumberOfComponents,
                numberOfRowsInComponent: @escaping NumberOfRowsInComponent,
                attributedTitleForRow: @escaping AttributedTitleForRow) {
        self.attributedTitleForRow = attributedTitleForRow
        super.init(components: components,
                   numberOfComponents: numberOfComponents,
                   numberOfRowsInComponent: numberOfRowsInComponent)
    }
    
    open func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        return attributedTitleForRow(self, pickerView, components, row, component)
    }
}

/// A reactive UIPickerView adapter which uses `func pickerView(pickerView:, viewForRow row:, forComponent component:)` to display the content
/**
 Example:
 
 let adapter = RxPickerViewViewAdapter<[T]>(...)
 
 items
 .bind(to: firstPickerView.rx.items(adapter: adapter))
 .disposed(by: disposeBag)
 
 */
open class RxPickerViewViewAdapter<Components>: RxPickerViewDataSource<Components>, UIPickerViewDelegate {
    /**
     - parameter dataSource
     - parameter pickerView
     - parameter components
     - parameter row
     - parameter component
     - parameter view
    */
    public typealias ViewForRow = (
        _ dataSource: RxPickerViewViewAdapter<Components>,
        _ pickerView: UIPickerView,
        _ components: Components,
        _ row: Int,
        _ component: Int,
        _ view: UIView?
    ) -> UIView
    
    private let viewForRow: ViewForRow

    /**
     - parameter components: Initial content value.
     - parameter numberOfComponents: Implementation of corresponding delegate method.
     - parameter numberOfRowsInComponent: Implementation of corresponding delegate method.
     - parameter attributedTitleForRow: Implementation of corresponding adapter method that converts component to `UIView`.
     */
    public init(components: Components,
                numberOfComponents: @escaping NumberOfComponents,
                numberOfRowsInComponent: @escaping NumberOfRowsInComponent,
                viewForRow: @escaping ViewForRow) {
        self.viewForRow = viewForRow
        super.init(components: components,
                   numberOfComponents: numberOfComponents,
                   numberOfRowsInComponent: numberOfRowsInComponent)
    }
    
    open func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        return viewForRow(self, pickerView, components, row, component, view)
    }
}

/// A reactive UIPickerView data source  
open class RxPickerViewDataSource<Components>: NSObject, UIPickerViewDataSource {
    /**
     - parameter dataSource
     - parameter pickerView
     - parameter components
    */
    public typealias NumberOfComponents = (
        _ dataSource: RxPickerViewDataSource,
        _ pickerView: UIPickerView,
        _ components: Components) -> Int
    /**
     - parameter dataSource
     - parameter pickerView
     - parameter components
     - parameter component
    */
    public typealias NumberOfRowsInComponent = (
        _ dataSource: RxPickerViewDataSource,
        _ pickerView: UIPickerView,
        _ components: Components,
        _ component: Int
    ) -> Int
    
    fileprivate var components: Components

    /**
     - parameter components: Initial content value.
     - parameter numberOfComponents: Implementation of corresponding delegate method.
     - parameter numberOfRowsInComponent: Implementation of corresponding delegate method.
     */
    init(components: Components,
         numberOfComponents: @escaping NumberOfComponents,
         numberOfRowsInComponent: @escaping NumberOfRowsInComponent) {
        self.components = components
        self.numberOfComponents = numberOfComponents
        self.numberOfRowsInComponent = numberOfRowsInComponent
        super.init()
    }
    
    private let numberOfComponents: NumberOfComponents
    private let numberOfRowsInComponent: NumberOfRowsInComponent
    
    // MARK: UIPickerViewDataSource
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return numberOfComponents(self, pickerView, components)
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return numberOfRowsInComponent(self, pickerView, components, component)
    }
}

extension RxPickerViewDataSource: RxPickerViewDataSourceType {
    public func pickerView(_ pickerView: UIPickerView, observedEvent: Event<Components>) {
        Binder(self) { dataSource, components in
            dataSource.components = components
            pickerView.reloadAllComponents()
        }.on(observedEvent)
    }
}

#endif
