//
//  NSNumber.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//

#if canImport(UIKit)
import UIKit
#endif
import Foundation

internal
extension NSNumber {
    static var direct: NSNumber {
        return NSNumber(touchType: .direct)
    }

    static var indirect: NSNumber {
        return NSNumber(touchType: .indirect)
    }

    // MARK: - Private

    private convenience init(touchType: UITouch.TouchType) {
        self.init(integerLiteral: touchType.rawValue)
    }
}
