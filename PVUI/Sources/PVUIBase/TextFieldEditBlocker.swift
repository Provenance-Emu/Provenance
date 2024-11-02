//
//  GameLaunchingViewController.swift
//  Provenance
//
//  Created by Joseph Mattiello on 2/13/18.
//  Copyright © 2018 James Addyman. All rights reserved.
//

import PVLibrary
import PVSupport
import RealmSwift
#if canImport(UIKit)
import UIKit
#endif
import ZipArchive
import AsyncAlgorithms
import PVSettings

#if os(iOS)
    final class TextFieldEditBlocker: NSObject, UITextFieldDelegate {
        var didSetConstraints = false

        var switchControl: UISwitch? {
            didSet {
                didSetConstraints = false
            }
        }

        // Prevent selection
        func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
            // Get rid of border
            textField.superview?.backgroundColor = textField.backgroundColor

            // Fix the switches frame from being below center
            if !didSetConstraints, let switchControl = switchControl {
                switchControl.constraints.forEach {
                    if $0.firstAttribute == .height {
                        switchControl.removeConstraint($0)
                    }
                }

                switchControl.heightAnchor.constraint(equalTo: textField.heightAnchor, constant: -4).isActive = true
                let centerAnchor = switchControl.centerYAnchor.constraint(equalTo: textField.centerYAnchor, constant: 0)
                centerAnchor.priority = .defaultHigh + 1
                centerAnchor.isActive = true

                textField.constraints.forEach {
                    if $0.firstAttribute == .height {
                        $0.constant += 20
                    }
                }

                didSetConstraints = true
            }

            return false
        }

        func textField(_: UITextField, shouldChangeCharactersIn _: NSRange, replacementString _: String) -> Bool {
            return false
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            textField.resignFirstResponder()
        }
    }

    // Need a strong reference, so making static
    let textEditBlocker = TextFieldEditBlocker()
#endif
