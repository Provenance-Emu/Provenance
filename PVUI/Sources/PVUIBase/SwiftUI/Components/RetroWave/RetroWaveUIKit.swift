//
//  RetroWaveUIKit.swift
//  PVUI
//
//  Created by Joseph Mattiello on 3/31/25.
//

import UIKit
import SwiftUI

// MARK: - Retrowave UIKit Extensions

// Retrowave color palette for UIKit
public extension UIColor {
    static let retroPink = UIColor(red: 0.98, green: 0.2, blue: 0.6, alpha: 1.0)
    static let retroPurple = UIColor(red: 0.5, green: 0.0, blue: 0.8, alpha: 1.0)
    static let retroBlue = UIColor(red: 0.0, green: 0.8, blue: 0.95, alpha: 1.0)
    static let retroYellow = UIColor(red: 0.98, green: 0.84, blue: 0.2, alpha: 1.0)
    static let retroOrange = UIColor(red: 0.98, green: 0.5, blue: 0.2, alpha: 1.0)
    static let retroBlack = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1.0)
}

// UIKit styling extensions
public extension UIView {
    func applyRetroWaveBorder(color: UIColor = .retroPink, width: CGFloat = 2.0) {
        layer.borderColor = color.cgColor
        layer.borderWidth = width
        layer.cornerRadius = 12
    }
    
    func applyRetroWaveShadow(color: UIColor = .retroPink, opacity: Float = 0.7, radius: CGFloat = 5, offset: CGSize = .zero) {
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = opacity
        layer.shadowRadius = radius
        layer.shadowOffset = offset
        layer.masksToBounds = false
    }
    
    func applyRetroWaveGradientBackground(colors: [UIColor] = [.retroPurple, .retroPink], startPoint: CGPoint = CGPoint(x: 0, y: 0), endPoint: CGPoint = CGPoint(x: 1, y: 1)) {
        // Remove any existing gradient layers
        layer.sublayers?.filter { $0 is CAGradientLayer }.forEach { $0.removeFromSuperlayer() }
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = bounds
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = startPoint
        gradientLayer.endPoint = endPoint
        
        // Insert at index 0 to be behind other content
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func applyRetroWaveStyle(backgroundColor: UIColor = .retroBlack, borderColor: UIColor = .retroPink, shadowColor: UIColor = .retroPink) {
        self.backgroundColor = backgroundColor
        applyRetroWaveBorder(color: borderColor)
        applyRetroWaveShadow(color: shadowColor)
    }
}

// UIKit button styling
public extension UIButton {
    func applyRetroWaveButtonStyle(textColor: UIColor = .white, backgroundColor: UIColor = .retroBlack, borderColor: UIColor = .retroPink) {
        setTitleColor(textColor, for: .normal)
        setTitleColor(textColor.withAlphaComponent(0.7), for: .highlighted)
        
        self.backgroundColor = backgroundColor
        applyRetroWaveBorder(color: borderColor)
        applyRetroWaveShadow(color: borderColor)
        
        titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
    }
}

// UIKit label styling
public extension UILabel {
    func applyRetroWaveTextStyle(color: UIColor = .white, fontSize: CGFloat = 16, weight: UIFont.Weight = .bold) {
        textColor = color
        font = UIFont.systemFont(ofSize: fontSize, weight: weight)
        
        // Add text shadow for neon effect
        layer.shadowColor = color == .white ? UIColor.retroPink.cgColor : color.cgColor
        layer.shadowRadius = 2
        layer.shadowOpacity = 0.7
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.masksToBounds = false
    }
    
    func applyRetroWaveTitleStyle() {
        applyRetroWaveTextStyle(color: .retroBlue, fontSize: 24, weight: .heavy)
    }
    
    func applyRetroWaveSubtitleStyle() {
        applyRetroWaveTextStyle(color: .retroPink, fontSize: 18, weight: .semibold)
    }
}

// UIKit table/collection view styling
public extension UITableView {
    func applyRetroWaveStyle() {
        backgroundColor = .retroBlack
        #if !os(tvOS)
        separatorColor = .retroPink.withAlphaComponent(0.3)
        separatorStyle = .singleLine
        #endif
        indicatorStyle = .white
    }
}

public extension UICollectionView {
    func applyRetroWaveStyle() {
        backgroundColor = .retroBlack
        indicatorStyle = .white
    }
}

// UIKit navigation bar styling
public extension UINavigationBar {
    func applyRetroWaveStyle() {
        barTintColor = .retroBlack
        tintColor = .retroBlue
        titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor.white,
            NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20, weight: .bold)
        ]
        isTranslucent = true
        
        // For iOS 15 and later
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .retroBlack
            appearance.titleTextAttributes = [
                NSAttributedString.Key.foregroundColor: UIColor.white,
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20, weight: .bold)
            ]
            
            standardAppearance = appearance
            scrollEdgeAppearance = appearance
        }
    }
}

// Grid background pattern generator
public class RetroWaveGridBackground {
    public static func createGridBackground(for view: UIView, gridColor: UIColor = .retroPink.withAlphaComponent(0.3), lineWidth: CGFloat = 1, spacing: CGFloat = 40) {
        // Remove any existing grid layers
        view.layer.sublayers?.filter { $0.name == "retroGridLayer" }.forEach { $0.removeFromSuperlayer() }
        
        let gridLayer = CAShapeLayer()
        gridLayer.name = "retroGridLayer"
        gridLayer.frame = view.bounds
        
        let path = UIBezierPath()
        
        // Horizontal lines
        for y in stride(from: 0, to: view.bounds.height, by: spacing) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: view.bounds.width, y: y))
        }
        
        // Vertical lines
        for x in stride(from: 0, to: view.bounds.width, by: spacing) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: view.bounds.height))
        }
        
        gridLayer.path = path.cgPath
        gridLayer.strokeColor = gridColor.cgColor
        gridLayer.lineWidth = lineWidth
        
        // Insert at index 0 to be behind other content
        view.layer.insertSublayer(gridLayer, at: 0)
    }
}
