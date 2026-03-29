//
//  ActionViewController.swift
//  ROM File ProviderUI
//
//  Created by Joseph Mattiello on 8/23/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//
//  File Provider UI extension action view controller.
//
//  Presented when a user triggers a custom action on a Provenance item
//  in the Files.app document picker (e.g. long-press → custom action).
//  For v1 only a dismissible info sheet is shown.  Richer per-game
//  actions (launch, import, metadata edit) can be added in a follow-up.
//

import FileProviderUI
import UIKit

/// Principal class for the `com.apple.fileprovider-ui` extension point.
///
/// Subclasses `FPUIActionExtensionViewController` so the system can
/// present it as a modal sheet inside the Files.app document picker.
final class ActionViewController: FPUIActionExtensionViewController {

    // MARK: - UI

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var dismissButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Done"
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(dismissAction), for: .primaryActionTriggered)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupLayout()
    }

    // MARK: - FPUIActionExtensionViewController

    /// Called when the extension is prepared for a custom action.
    ///
    /// `actionIdentifier` matches the key defined in the file provider's
    /// `NSExtensionFileProviderActions` Info.plist entry (if any).
    /// `itemIdentifiers` are the items the user selected the action on.
    override func prepare(
        forActionWithIdentifier actionIdentifier: String,
        itemIdentifiers: [NSFileProviderItemIdentifier]
    ) {
        titleLabel.text = "Provenance"
        let count = itemIdentifiers.count
        bodyLabel.text = count == 1
            ? "This ROM is managed by Provenance."
            : "\(count) ROMs are managed by Provenance."
    }

    /// Called when the extension is presented to show an error to the user.
    override func prepare(forError error: Error) {
        titleLabel.text = "Provenance"
        bodyLabel.text = error.localizedDescription
    }

    // MARK: - Actions

    @objc private func dismissAction() {
        extensionContext.completeRequest()
    }

    // MARK: - Layout

    private func setupLayout() {
        let stack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel, dismissButton])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            dismissButton.widthAnchor.constraint(equalToConstant: 120),
        ])
    }
}
