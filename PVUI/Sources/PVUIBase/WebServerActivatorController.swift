//
//  WebServerActivatorController.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//


#if canImport(UIKit)
import UIKit
#endif

public protocol WebServerActivatorController: AnyObject {
    func showServerActiveAlert(sender: UIView?, barButtonItem: UIBarButtonItem?)
}
