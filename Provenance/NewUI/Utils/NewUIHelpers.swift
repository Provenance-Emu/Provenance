//
//  NewUIHelpers.swift
//  Provenance
//
//  Created by Ian Clawson on 1/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation
import UIKit

public extension UIImage {
    class func symbolNameWithFallBack(name: String) -> UIImage? {
        if #available(iOS 13, *) {
            if let img = UIImage(systemName: name) {
                return img
            }
        }
        if let img = UIImage(named: name) {
            return img
        }
        return nil
    }
}


public extension UIBarButtonItem {
    class func makeFromCustomView(image: UIImage, target: Any, action: Selector, padLeft: Bool = false, padRight: Bool = false) -> UIBarButtonItem {
        let button = UIButton(type: .system)
        button.setImage(image, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(target, action: action, for: .touchUpInside)
        return UIBarButtonItem(customView: button)
    }
}
