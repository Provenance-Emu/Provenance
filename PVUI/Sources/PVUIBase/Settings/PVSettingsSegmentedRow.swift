//
//  PVSettingsSegmentedRow.swift
//  PVUI
//
//  Created by Joseph Mattiello on 2025-04-03.
//

import UIKit
import PVSettings
import PVThemes

/// A view controller that displays options with retrowave styling
public class PVOptionsViewController<T: RawRepresentable & CaseIterable & CustomStringConvertible>: UITableViewController where T: Hashable, T: Defaults.Serializable, T.RawValue == String {

    private let key: Defaults.Key<T>
    private let options: [T]
    private var selectedOption: T
    private var onSelection: ((T) -> Void)?

    public init(title: String, key: Defaults.Key<T>, options: [T]? = nil, onSelection: ((T) -> Void)? = nil) {
        self.key = key
        self.options = options ?? Array(T.allCases)
        self.selectedOption = Defaults[key]
        self.onSelection = onSelection

        super.init(style: .grouped)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        // Apply retrowave styling to the table view
        tableView.backgroundColor = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0) // RetroTheme.retroBlack
        tableView.separatorColor = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 0.3) // RetroTheme.retroPink with alpha

        // Register cell class
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "OptionCell")
    }

    // MARK: - Table view data source

    public override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OptionCell", for: indexPath)

        // Get the option for this row
        let option = options[indexPath.row]

        // Configure the cell
        cell.textLabel?.text = option.description
        cell.textLabel?.font = UIFont.systemFont(ofSize: 17, weight: .medium)

        // Apply retrowave styling
        cell.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0) // RetroTheme.retroDarkBlue
        cell.textLabel?.textColor = .white

        // Show checkmark for selected option
        if option.rawValue == selectedOption.rawValue {
            cell.accessoryType = .checkmark
            cell.tintColor = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 1.0) // RetroTheme.retroPink

            // Add glow effect to the selected cell
            cell.layer.shadowColor = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 0.5).cgColor
            cell.layer.shadowOffset = CGSize(width: 0, height: 0)
            cell.layer.shadowRadius = 5
            cell.layer.shadowOpacity = 0.5

            // Add pink text color
            cell.textLabel?.textColor = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 1.0) // RetroTheme.retroPink
        } else {
            cell.accessoryType = .none
            cell.layer.shadowOpacity = 0
        }

        return cell
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Get the selected option
        let option = options[indexPath.row]

        // Update the selected option
        selectedOption = option
        Defaults[key] = option

        // Reload the table to update the checkmark
        tableView.reloadData()

        // Call the selection handler
        onSelection?(option)

        // Animate a brief highlight
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.2, animations: {
                cell.backgroundColor = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 0.3) // RetroTheme.retroPink with alpha
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    cell.backgroundColor = UIColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 1.0) // RetroTheme.retroDarkBlue
                }
            }
        }

        // Deselect the row with animation
        tableView.deselectRow(at: indexPath, animated: true)

        // Pop back to the previous view controller after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}

/// A navigation row that displays selectable options for enum values in settings
public final class PVSettingsSegmentedRow<T: RawRepresentable & CaseIterable & CustomStringConvertible>: Row where T: Hashable, T: Defaults.Serializable, T.RawValue == String {

    public var text: String
    public var detailText: DetailText?
    public var icon: Icon?
    public var customization: ((UITableViewCell, Row) -> Void)?
    public var action: ((any Row) -> Void)?

    private let key: Defaults.Key<T>
    private let options: [T]
    private weak var viewController: UIViewController?

    public init(text: String, detailText: DetailText? = nil, key: Defaults.Key<T>, options: [T]? = nil, icon: Icon? = nil, viewController: UIViewController, customization: ((UITableViewCell, Row) -> Void)? = nil, action: ((any Row) -> Void)? = nil) {
        self.text = text
        self.detailText = detailText
        self.key = key
        self.options = options ?? Array(T.allCases)
        self.icon = icon
        self.viewController = viewController
        self.customization = customization

        // Set up the action to navigate to the options view controller
        self.action = { [weak self, weak viewController] _ in
            guard let self = self, let viewController = viewController else { return }

            // Create the options view controller
            let optionsVC = PVOptionsViewController(title: self.text, key: self.key, options: self.options) { selectedOption in
                // Call the custom action if provided
                action?(self)
            }

            // Push the options view controller
            viewController.navigationController?.pushViewController(optionsVC, animated: true)
        }
    }

    public func configure(_ cell: UITableViewCell) {
        // Set up the cell text
        cell.textLabel?.text = text

        // Set the detail text to show the current selection
        let currentValue = Defaults[key]
        cell.detailTextLabel?.text = currentValue.description

        // Apply retrowave styling to the detail text
        if #available(iOS 13.0, *) {
            cell.detailTextLabel?.textColor = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 1.0) // RetroTheme.retroPink
        }

        // Set icon if provided
        if let icon = icon {
            cell.imageView?.image = icon.image
            cell.imageView?.highlightedImage = icon.highlightedImage
        }

        // Apply custom styling if provided
        customization?(cell, self)
    }
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
        return .value1
    }

    public var accessoryType: UITableViewCell.AccessoryType {
        return .disclosureIndicator
    }

    public var isSelectable: Bool {
        return true
    }

    public var customize: ((UITableViewCell, Row & RowStyle) async -> Void)? {
        return nil
    }
}
