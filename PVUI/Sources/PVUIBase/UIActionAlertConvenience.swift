//
//  UIActionAlertConvenience.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/11/24.
//


// MARK: UIAlertAction

package let _fullscreenColor = UIColor.black.withAlphaComponent(0.8)
package let _destructiveButtonColor = UIColor.systemRed.withAlphaComponent(0.5)
package let _borderWidth = 4.0
package let _fontTitleF = 1.25
package let _animateDuration = 0.150

// os specific defaults
#if os(tvOS)
package let _blurFullscreen = false
package let _font = UIFont.systemFont(ofSize: 24.0)
package let _inset:CGFloat = 16.0
package let _maxTextWidthF:CGFloat = 0.25
package let _backgroundColor = UIColor(red:0.1, green:0.1, blue:0.1, alpha:1)      // secondarySystemGroupedBackground
package let _defaultButtonColor = UIColor(white: 0.2, alpha: 1)
#else
package let _blurFullscreen = true
package let _font = UIFont.preferredFont(forTextStyle: .body)
package let _inset:CGFloat = 16.0
internal let _maxTextWidthF:CGFloat = 0.50
package let _backgroundColor = UIColor.secondarySystemGroupedBackground
package let _defaultButtonColor = UIColor.systemGray4
#endif


internal extension UIAlertAction {
    func callActionHandler() {
        if let handler = self.value(forKey:"handler") as? NSObject {
            unsafeBitCast(handler, to:(@convention(block) (UIAlertAction) -> Void).self)(self)
        }
    }
}

extension UIAlertAction {
    convenience init(title: String, symbol:String, style: UIAlertAction.Style, handler: @escaping ((UIAlertAction) -> Void)) {
        self.init(title: title, style: style, handler: handler)
#if os(iOS)
    if let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(font: _font)) {
        self.setValue(image, forKey: "image")
    }
#endif
    }
    func getImage() -> UIImage? {
        return self.value(forKey: "image") as? UIImage
    }
}
