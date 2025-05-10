import UIKit
import SwiftUI
import PVThemes

/// A retrowave-themed progress HUD to replace MBProgressHUD
public class RetroProgressHUD: UIView {
    // MARK: - Properties
    
    // UI Components
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let loadingIndicator = RetroLoadingIndicator()
    private var progressView: CustomRetroProgressBar?
    
    // Progress tracking
    private var currentProgress: Float = 0
    
    // Colors from RetroTheme
    private var retroPink: UIColor { UIColor(RetroTheme.retroPink) }
    private var retroPurple: UIColor { UIColor(RetroTheme.retroPurple) }
    private var retroBlue: UIColor { UIColor(RetroTheme.retroBlue) }
    private var retroDarkBlue: UIColor { UIColor(RetroTheme.retroDarkBlue) }
    private var retroBlack: UIColor { UIColor(RetroTheme.retroBlack) }
    
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
        
        // Create and configure progress bar
        let progressBar = CustomRetroProgressBar(frame: CGRect(x: 0, y: 0, width: 200, height: 10))
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.isHidden = true // Hide initially
        containerView.addSubview(progressBar)
        self.progressView = progressBar
        
        // Configure title label
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)
        
        // Add glow effect to container
        addGlowEffect(to: containerView)
        
        // Set up constraints with higher priority to ensure proper centering
        let centerXConstraint = containerView.centerXAnchor.constraint(equalTo: centerXAnchor)
        centerXConstraint.priority = .required
        
        let centerYConstraint = containerView.centerYAnchor.constraint(equalTo: centerYAnchor)
        centerYConstraint.priority = .required
        
        NSLayoutConstraint.activate([
            centerXConstraint,
            centerYConstraint,
            containerView.widthAnchor.constraint(equalToConstant: 240), // Slightly wider
            containerView.heightAnchor.constraint(equalToConstant: 200), // Slightly taller
            
            gridPattern.topAnchor.constraint(equalTo: containerView.topAnchor),
            gridPattern.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            gridPattern.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            gridPattern.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 25),
            loadingIndicator.widthAnchor.constraint(equalToConstant: 60),
            loadingIndicator.heightAnchor.constraint(equalToConstant: 60),
        ])
        
        // Set up progress bar constraints separately
        if let progressView = self.progressView {
            NSLayoutConstraint.activate([
                progressView.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 10),
                progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
                progressView.heightAnchor.constraint(equalToConstant: 10),
                
                titleLabel.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 15),
                titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
                titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
                titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -15)
            ])
        } else {
            // If progress view isn't available, connect title label directly to loading indicator
            NSLayoutConstraint.activate([
                titleLabel.topAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 15),
                titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
                titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
                titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -15)
            ])
        }
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
    
    /// Set the progress value (0.0 to 1.0)
    public func setProgress(_ progress: Float, animated: Bool = true) {
        currentProgress = progress
        
        guard let progressView = self.progressView else { return }
        
        // Show progress bar and hide loading indicator when in progress mode
        if progress > 0 && progress < 1 {
            progressView.isHidden = false
            loadingIndicator.isHidden = true
        } else if progress >= 1 {
            // At 100%, show a brief completion animation
            progressView.isHidden = false
            loadingIndicator.isHidden = true
            
            // Auto-hide after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.hide(animated: true)
            }
        } else {
            // At 0%, show the loading indicator
            progressView.isHidden = true
            loadingIndicator.isHidden = false
        }
        
        // Update the progress bar
        progressView.setProgress(progress, animated: animated)
    }
    
    /// Show the HUD in the specified view
    public static func show(in view: UIView, animated: Bool = true) -> RetroProgressHUD {
        let hud = RetroProgressHUD(frame: view.bounds)
        hud.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Ensure the HUD is centered in the view
        hud.frame = view.bounds
        
        // Add to the main window if possible to ensure it appears on top
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            window.addSubview(hud)
        } else {
            view.addSubview(hud)
        }
        
        // Force layout to ensure constraints are applied
        hud.layoutIfNeeded()
        
        if animated {
            hud.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            hud.alpha = 0
            
            UIView.animate(withDuration: 0.3) {
                hud.containerView.transform = .identity
                hud.alpha = 1
            }
        } else {
            hud.alpha = 1
        }
        
        return hud
    }
    
    /// Show the HUD if it's currently hidden
    public func show(animated: Bool = true) {
        // Update frame and center to ensure proper positioning
        if let superview = self.superview {
            self.frame = superview.bounds
            
            // Force layout to ensure constraints are applied
            self.layoutIfNeeded()
        }
        
        if self.alpha == 0 {
            if animated {
                self.containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                
                UIView.animate(withDuration: 0.3) {
                    self.containerView.transform = .identity
                    self.alpha = 1
                }
            } else {
                self.alpha = 1
                self.containerView.transform = .identity
            }
        }
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

// MARK: - CustomRetroProgressBar

/// A retrowave-styled progress bar
class CustomRetroProgressBar: UIView {
    // MARK: - Properties
    
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let glowLayer = CAShapeLayer()
    
    private var progress: Float = 0
    
    // Colors from RetroTheme
    private var retroPink: UIColor { UIColor(RetroTheme.retroPink) }
    private var retroBlue: UIColor { UIColor(RetroTheme.retroBlue) }
    private var retroPurple: UIColor { UIColor(RetroTheme.retroPurple) }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }
    
    // MARK: - Setup
    
    private func setupLayers() {
        // Track layer (background)
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.darkGray.cgColor
        trackLayer.lineWidth = 6
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)
        
        // Glow layer (for the neon effect)
        glowLayer.fillColor = UIColor.clear.cgColor
        glowLayer.strokeColor = retroBlue.cgColor
        glowLayer.lineWidth = 6
        glowLayer.lineCap = .round
        glowLayer.shadowColor = retroBlue.cgColor
        glowLayer.shadowOffset = CGSize(width: 0, height: 0)
        glowLayer.shadowOpacity = 0.8
        glowLayer.shadowRadius = 5
        layer.addSublayer(glowLayer)
        
        // Progress layer (foreground)
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = retroPink.cgColor
        progressLayer.lineWidth = 6
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0 // Start with no progress
        layer.addSublayer(progressLayer)
        
        // Add pulsing animation to the glow
        addPulsingAnimation()
    }
    
    private func addPulsingAnimation() {
        let pulseAnimation = CABasicAnimation(keyPath: "opacity")
        pulseAnimation.fromValue = 0.4
        pulseAnimation.toValue = 0.8
        pulseAnimation.duration = 1.0
        pulseAnimation.repeatCount = .infinity
        pulseAnimation.autoreverses = true
        glowLayer.add(pulseAnimation, forKey: "pulseAnimation")
    }
    
    // MARK: - Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayerFrames()
    }
    
    private func updateLayerFrames() {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 3, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.width - 3, y: bounds.midY))
        
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        glowLayer.path = path.cgPath
        
        // Update progress
        progressLayer.strokeEnd = CGFloat(progress)
        glowLayer.strokeEnd = CGFloat(progress)
    }
    
    // MARK: - Public Methods
    
    /// Set the progress value (0.0 to 1.0)
    func setProgress(_ progress: Float, animated: Bool) {
        let clampedProgress = min(max(progress, 0), 1)
        self.progress = clampedProgress
        
        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = CGFloat(clampedProgress)
            animation.duration = 0.3
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            progressLayer.strokeEnd = CGFloat(clampedProgress)
            progressLayer.add(animation, forKey: "progressAnimation")
            
            glowLayer.strokeEnd = CGFloat(clampedProgress)
            glowLayer.add(animation, forKey: "glowProgressAnimation")
        } else {
            progressLayer.strokeEnd = CGFloat(clampedProgress)
            glowLayer.strokeEnd = CGFloat(clampedProgress)
            setNeedsLayout()
        }
    }
}
