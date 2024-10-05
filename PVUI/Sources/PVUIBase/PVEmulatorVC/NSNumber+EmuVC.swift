//
//  NSNumber+EmuVC.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/18/24.
//


// Extension to make gesture.allowedPressTypes and gesture.allowedTouchTypes sane.
extension NSNumber {
    static var menu: NSNumber {
        return NSNumber(pressType: .menu)
    }

    static var playPause: NSNumber {
        return NSNumber(pressType: .playPause)
    }

    static var select: NSNumber {
        return NSNumber(pressType: .select)
    }

    static var upArrow: NSNumber {
        return NSNumber(pressType: .upArrow)
    }

    static var downArrow: NSNumber {
        return NSNumber(pressType: .downArrow)
    }

    static var leftArrow: NSNumber {
        return NSNumber(pressType: .leftArrow)
    }

    static var rightArrow: NSNumber {
        return NSNumber(pressType: .rightArrow)
    }

    // MARK: - Private

    private convenience init(pressType: UIPress.PressType) {
        self.init(integerLiteral: pressType.rawValue)
    }
}
