import UIKit
import SwiftUI

/// A retrowave-themed progress HUD to replace MBProgressHUD
public class RetroProgressHUD: UIView {
    // MARK: - Properties
    
    // UI Components
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let loadingIndicator = RetroLoadingIndicator()
    
    // Colors from RetroTheme
    private let retroPink = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 1.0)
    private let retroPurple = UIColor(red: 0.53, green: 0.11, blue: 0.91, alpha: 1.0)
    private let retroBlue = UIColor(red: 0.0, green: 0.75, blue: 0.95, alpha: 1.0)
    private let retroDarkBlue = UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1.0)
    private let retroBlack = UIColor(red: 0.05, green: 0.0, blue: 0.1, alpha: 1.0)
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    // MARK: - Setup
    
    private func setupViews() {
        // Configure background
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        
        // Configure container view
        containerView.backgroundColor = retroBlack
        containerView.layer.cornerRadius = 16
        containerView.layer.borderWidth = 2
        containerView.layer.borderColor = retroPink.cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerView)
        
        // Add grid pattern to container
        let gridPattern = createGridPattern()
        gridPattern.alpha = 0.3
        containerView.addSubview(gridPattern)
        
        // Configure loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(loadingIndicator)
        
        // Configure title label
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Add glow effect to container
        addGlowEffect(to: containerView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 200),
            containerView.heightAnchor.constraint(equalToConstant: 160),
            
            gridPattern.topAnchor.constraint(equalTo: containerView.topAnchor),
            gridPattern.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gridPattern.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            gridPattern.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: -15),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 80),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -15)
        ])
    }
    
    private func createGridPattern() -> UIView {
        let gridView = UIView()
        gridView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create horizontal lines
        for i in 0...10 {
            let lineView = UIView()
            lineView.backgroundColor = retroBlue.withAlphaComponent(0.2)
            lineView.translatesAutoresizingMaskIntoConstraints = false
            gridView.addSubview(lineView)
            
            NSLayoutConstraint.activate([
                lineView.leadingAnchor.constraint(equalTo: gridView.leadingAnchor),
                lineView.trailingAnchor.constraint(equalTo: gridView.trailingAnchor),
                lineView.heightAnchor.constraint(equalToConstant: 1),
                lineView.topAnchor.constraint(equalTo: gridView.topAnchor, constant: CGFloat(i) * 16)
            ])
        }
        
        // Create vertical lines
        for i in 0...10 {
            let lineView = UIView()
            lineView.backgroundColor = retroBlue.withAlphaComponent(0.2)
            lineView.translatesAutoresizingMaskIntoConstraints = false
            gridView.addSubview(lineView)
            
            NSLayoutConstraint.activate([
                lineView.topAnchor.constraint(equalTo: gridView.topAnchor),
                lineView.bottomAnchor.constraint(equalTo: gridView.bottomAnchor),
                lineView.widthAnchor.constraint(equalToConstant: 1),
                lineView.leadingAnchor.constraint(equalTo: gridView.leadingAnchor, constant: CGFloat(i) * 20)
            ])
        }
        
        return gridView
    }
    
    private func addGlowEffect(to view: UIView) {
        view.layer.shadowColor = retroPink.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 0)
        view.layer.shadowOpacity = 0.8
        view.layer.shadowRadius = 10
        view.layer.masksToBounds = false
    }
    
    // MARK: - Public Methods
    
    /// Set the text to display in the HUD
    public func setText(_ text: String) {
        titleLabel.text = text
    }
    
    /// Show the HUD in the specified view
    public static func show(in view: UIView, animated: Bool = true) -> RetroProgressHUD {
        let hud = RetroProgressHUD(frame: view.bounds)
        hud.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(hud)
        
        if animated {
            hud.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            hud.alpha = 0
            
            UIView.animate(withDuration: 0.3) {
                hud.containerView.transform = .identity
                hud.alpha = 1
            }
        }
        
        return hud
    }
    
    /// Hide the HUD
    public func hide(animated: Bool = true, afterDelay delay: TimeInterval = 0) {
        let hideAction = {
            if animated {
                UIView.animate(withDuration: 0.3, animations: {
                    self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                    self.alpha = 0
                }, completion: { _ in
                    self.removeFromSuperview()
                })
            } else {
                self.removeFromSuperview()
            }
        }
        
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: hideAction)
        } else {
            hideAction()
        }
    }
}

// MARK: - RetroLoadingIndicator

class RetroLoadingIndicator: UIView {
    private var animationLayer: CAShapeLayer!
    private var glowLayer: CAShapeLayer!
    
    private let retroPink = UIColor(red: 0.99, green: 0.11, blue: 0.55, alpha: 1.0)
    private let retroBlue = UIColor(red: 0.0, green: 0.75, blue: 0.95, alpha: 1.0)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrames()
    }
    
    private func setupLayers() {
        // Create the main animation layer
        animationLayer = CAShapeLayer()
        animationLayer.strokeColor = retroPink.cgColor
        animationLayer.fillColor = UIColor.clear.cgColor
        animationLayer.lineWidth = 3
        animationLayer.lineCap = .round
        layer.addSublayer(animationLayer)
        
        // Create the glow layer
        glowLayer = CAShapeLayer()
        glowLayer.strokeColor = retroBlue.cgColor
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.lineWidth = 3
        glowLayer.lineCap = .round
        glowLayer.opacity = 0.7
        layer.addSublayer(glowLayer)
        
        // Start the animations
        startAnimating()
    }
    
    private func updateLayerFrames() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = min(bounds.width, bounds.height) / 2 - 10
        
        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        animationLayer.path = path.cgPath
        glowLayer.path = path.cgPath
    }
    
    func startAnimating() {
        // Create stroke animation for main layer
        let strokeAnimation = CABasicAnimation(keyPath: "strokeEnd")
        strokeAnimation.fromValue = 0
        strokeAnimation.toValue = 1
        strokeAnimation.duration = 1.5
        strokeAnimation.repeatCount = .infinity
        animationLayer.add(strokeAnimation, forKey: "strokeAnimation")
        
        // Create rotation animation
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")
        rotationAnimation.fromValue = 0
        rotationAnimation.toValue = 2 * Double.pi
        rotationAnimation.duration = 2
        rotationAnimation.repeatCount = .infinity
        layer.add(rotationAnimation, forKey: "rotationAnimation")
        
        // Create pulse animation for glow
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.3
        pulseAnimation.toValue = 0.8
        pulseAnimation.duration = 1
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        glowLayer.add(pulseAnimation, forKey: "pulseAnimation")
    }
}
