//
//  PVSettingsSegmentedRow.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2025-04-03.
//

import UIKit
import PVSettings

/// A segmented control row for enum values in settings
public final class PVSettingsSegmentedRow<T: RawRepresentable & CaseIterable & CustomStringConvertible>: Row where T: Hashable, T:Defaults.Serializable, T.RawValue == String {
    
    public var text: String
    public var detailText: DetailText?
    public var icon: Icon?
    public var customization: ((UITableViewCell, Row) -> Void)?
    public var action: ((any Row) -> Void)?

    private let key: Defaults.Key<T>
    private let options: [T]
    
    public init(text: String, detailText: DetailText? = nil, key: Defaults.Key<T>, options: [T]? = nil, icon: Icon? = nil, customization: ((UITableViewCell, Row) -> Void)? = nil, action: ((any Row) -> Void)? = nil) {
        self.text = text
        self.detailText = detailText
        self.key = key
        self.options = options ?? Array(T.allCases)
        self.icon = icon
        self.customization = customization
        self.action = action
    }
    
    public func configure(_ cell: UITableViewCell) {
        cell.textLabel?.text = text
        
        if let detailText = detailText {
            switch detailText {
            case .none:
                cell.detailTextLabel?.text = nil
            case .subtitle(let text):
                cell.detailTextLabel?.text = text
            case .value1(let text):
                cell.detailTextLabel?.text = text
            case .value2(let text):
                cell.detailTextLabel?.text = text
            }
        }
        
        if let icon = icon {
            cell.imageView?.image = icon.image
            cell.imageView?.highlightedImage = icon.highlightedImage
        }
        
        // Create segmented control with proper styling
        let segmentedControl = UISegmentedControl(items: options.map { $0.description })
        
        // Set current selection
        let currentValue = Defaults[key]
        if let index = options.firstIndex(where: { $0 == currentValue }) {
            segmentedControl.selectedSegmentIndex = index
        }
        
        // Configure size and appearance
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.apportionsSegmentWidthsByContent = true
        segmentedControl.setContentHuggingPriority(.required, for: .horizontal)
        segmentedControl.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        // Add retrowave styling if available
        if #available(iOS 13.0, *) {
            // Use system colors that match our retrowave theme
            segmentedControl.selectedSegmentTintColor = UIColor(red: 0.9, green: 0.2, blue: 0.6, alpha: 1.0) // Pink
            segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
            segmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.lightGray], for: .normal)
        }
        
        // Add action
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)
        
        // Store key, options, and row for action handler
        segmentedControl.tag = options.hashValue
        objc_setAssociatedObject(segmentedControl, &AssociatedKeys.optionsKey, options, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(segmentedControl, &AssociatedKeys.defaultsKey, key, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(segmentedControl, &AssociatedKeys.rowKey, self, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Create a container view for the segmented control
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(segmentedControl)
        
        // Set constraints for the segmented control
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            segmentedControl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            segmentedControl.topAnchor.constraint(equalTo: containerView.topAnchor),
            segmentedControl.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            containerView.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            containerView.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add to cell
        cell.accessoryView = containerView
        
        // Apply custom styling
        customization?(cell, self)
    }
    
    @objc private func segmentChanged(_ sender: UISegmentedControl) {
        guard let options = objc_getAssociatedObject(sender, &AssociatedKeys.optionsKey) as? [T],
              let key = objc_getAssociatedObject(sender, &AssociatedKeys.defaultsKey) as? Defaults.Key<T>,
              sender.selectedSegmentIndex >= 0,
              sender.selectedSegmentIndex < options.count else {
            return
        }
        
        let selectedOption = options[sender.selectedSegmentIndex]
        Defaults[key] = selectedOption
        
        // Call the action if provided
        if let row = objc_getAssociatedObject(sender, &AssociatedKeys.rowKey) as? PVSettingsSegmentedRow<T> {
            row.action?(row)
        }
    }
}

// Associated objects keys
private struct AssociatedKeys {
    static var optionsKey = "PVSettingsSegmentedRowOptionsKey"
    static var defaultsKey = "PVSettingsSegmentedRowDefaultsKey"
    static var rowKey = "PVSettingsSegmentedRowKey"
}

// Conform to RowStyle
extension PVSettingsSegmentedRow: RowStyle {
    public var cellType: UITableViewCell.Type {
        return UITableViewCell.self
    }
    
    public var cellReuseIdentifier: String {
        return "PVSettingsSegmentedRow"
    }
    
    public var cellStyle: UITableViewCell.CellStyle {
        return .subtitle
    }
    
    public var accessoryType: UITableViewCell.AccessoryType {
        return .none
    }
    
    public var isSelectable: Bool {
        return false
    }
    
    public var customize: ((UITableViewCell, Row & RowStyle) async -> Void)? {
        return nil
    }
}
