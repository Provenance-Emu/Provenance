//
//  UIColor+Components.swift
//  PVThemes
//
//  Created by Joseph Mattiello on 10/7/24.
//

extension FloatingPoint {
    
    /// Clamps a floating point to a range
    /// - Parameter range: Range to clamp to
    /// - Returns: New value clamped to range
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

public extension UIColor {
    
    /// Subtracts from the saturation of the current UIColor
    /// Also takes a negative value or you can use `addSaturation()`
    /// - Parameter newBrighness: From 0...1
    /// - Returns: Color with adusted saturation
    func subtractSaturation(_ adjustment: CGFloat) -> UIColor {
        addSaturation(adjustment * -1)
    }
    
    /// Adds to the saturation of the current UIColor
    /// Also takes a negative value or you can use `subtractSaturation()`
    /// - Parameter newBrighness: From 0...1
    /// - Returns: Color with adusted saturation
    func addSaturation(_ adjustment: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Get the current color components
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Create a new color with the adjusted saturation
            // It is also range bound from 0 to 1
            let newSaturation = (saturation + adjustment).clamped(to: 0...1)
            return UIColor(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
        }
        
        // If we couldn't get the color components, return the original color
        return self
    }
    
    /// Adjust the saturation of the current UIColor
    /// - Parameter newSaturation: From 0...1
    /// - Returns: Color with adusted saturation
    func saturation(_ newSaturation: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Get the current color components
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Create a new color with the adjusted saturation
            return UIColor(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
        }
        
        // If we couldn't get the color components, return the original color
        return self
    }
    
    /// Adjust the brightness of the current UIColor
    /// - Parameter newBrighness: From 0...1
    /// - Returns: Color with adusted brightness
    func brightness(_ newBrighness: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Get the current color components
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Create a new color with the adjusted brightness
            return UIColor(hue: hue, saturation: saturation, brightness: newBrighness, alpha: alpha)
        }
        
        // If we couldn't get the color components, return the original color
        return self
    }
    
    /// Adjust the hue of the current UIColor
    /// - Parameter newBrighness: From 0...1
    /// - Returns: Color with adusted hue
    func hue(_ newHue: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        // Get the current color components
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            // Create a new color with the adjusted hue
            return UIColor(hue: newHue, saturation: saturation, brightness: brightness, alpha: alpha)
        }
        
        // If we couldn't get the color components, return the original color
        return self
    }
}
