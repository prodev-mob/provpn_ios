//
//  AnimatedLaunchViewController.swift
//  VPNClient
//
//  Created by DREAMWORLD on 24/11/25.
//

import UIKit

/// Animated launch screen view controller - Memory optimized with VPN theme
class AnimatedLaunchViewController: UIViewController {
    
    private weak var appIconView: UIImageView?
    private weak var circleBackground: UIView?
    private weak var appTitleLabel: UILabel?
    private weak var taglineLabel: UILabel?
    private weak var particleEmitter: CAEmitterLayer?
    private var gradientLayer: CAGradientLayer?
    private var pulseLayer: CAShapeLayer?
    private var gridLayer: CAShapeLayer?
    private var isAnimating = false
    
    deinit {
        stopAllAnimations()
        gradientLayer?.removeFromSuperlayer()
        particleEmitter?.removeFromSuperlayer()
        pulseLayer?.removeFromSuperlayer()
        gridLayer?.removeFromSuperlayer()
        gradientLayer = nil
        particleEmitter = nil
        pulseLayer = nil
        gridLayer = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !isAnimating {
            startAnimations()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAllAnimations()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer?.frame = view.bounds
        gridLayer?.frame = view.bounds
        gridLayer?.path = createGridPath().cgPath
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    private func setupUI() {
        // Dark themed background
        view.backgroundColor = UIColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1.0)
        
        // Animated gradient background
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [
            UIColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.06, green: 0.10, blue: 0.18, alpha: 1.0).cgColor
        ]
        gradient.locations = [0.0, 0.5, 1.0]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        view.layer.insertSublayer(gradient, at: 0)
        self.gradientLayer = gradient
        
        // Network grid pattern
        let grid = CAShapeLayer()
        grid.frame = view.bounds
        grid.path = createGridPath().cgPath
        grid.strokeColor = UIColor.cyan.withAlphaComponent(0.1).cgColor
        grid.fillColor = UIColor.clear.cgColor
        grid.lineWidth = 0.5
        view.layer.addSublayer(grid)
        self.gridLayer = grid
        
        // Particle emitter for network effect
        setupParticleEmitter()
        
        // Glowing circle background
        let circleBg = UIView()
        circleBg.backgroundColor = UIColor.clear
        circleBg.layer.cornerRadius = 70
        circleBg.translatesAutoresizingMaskIntoConstraints = false
        
        // Add glow effect
        circleBg.layer.shadowColor = UIColor.cyan.cgColor
        circleBg.layer.shadowOffset = .zero
        circleBg.layer.shadowRadius = 30
        circleBg.layer.shadowOpacity = 0.5
        
        // Add gradient border
        let gradientBorder = CAGradientLayer()
        gradientBorder.frame = CGRect(x: 0, y: 0, width: 140, height: 140)
        gradientBorder.colors = [
            UIColor.cyan.cgColor,
            UIColor.systemBlue.cgColor,
            UIColor.purple.cgColor
        ]
        gradientBorder.startPoint = CGPoint(x: 0, y: 0)
        gradientBorder.endPoint = CGPoint(x: 1, y: 1)
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 136, height: 136)).cgPath
        maskLayer.fillColor = UIColor.clear.cgColor
        maskLayer.strokeColor = UIColor.white.cgColor
        maskLayer.lineWidth = 3
        gradientBorder.mask = maskLayer
        circleBg.layer.addSublayer(gradientBorder)
        
        view.addSubview(circleBg)
        self.circleBackground = circleBg
        
        // App Icon from assets
        let appIcon = UIImageView()
        if let iconImage = UIImage(named: "AppIcon") ?? loadAppIcon() {
            appIcon.image = iconImage
        } else {
            // Fallback to SF Symbol
            let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
            appIcon.image = UIImage(systemName: "shield.checkmark.fill", withConfiguration: config)
            appIcon.tintColor = .cyan
        }
        appIcon.contentMode = .scaleAspectFit
        appIcon.layer.cornerRadius = 20
        appIcon.clipsToBounds = true
        appIcon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(appIcon)
        self.appIconView = appIcon
        
        // App title with gradient effect
        let titleLabel = UILabel()
        titleLabel.text = "ProVPN"
        titleLabel.font = .systemFont(ofSize: 36, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        self.appTitleLabel = titleLabel
        
        // Tagline
        let tagline = UILabel()
        tagline.text = "Secure • Private • Fast"
        tagline.font = .systemFont(ofSize: 16, weight: .medium)
        tagline.textColor = UIColor.cyan.withAlphaComponent(0.8)
        tagline.textAlignment = .center
        tagline.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tagline)
        self.taglineLabel = tagline
        
        // Constraints
        NSLayoutConstraint.activate([
            // Circle background
            circleBg.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            circleBg.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            circleBg.widthAnchor.constraint(equalToConstant: 140),
            circleBg.heightAnchor.constraint(equalToConstant: 140),
            
            // App icon
            appIcon.centerXAnchor.constraint(equalTo: circleBg.centerXAnchor),
            appIcon.centerYAnchor.constraint(equalTo: circleBg.centerYAnchor),
            appIcon.widthAnchor.constraint(equalToConstant: 80),
            appIcon.heightAnchor.constraint(equalToConstant: 80),
            
            // App title
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: circleBg.bottomAnchor, constant: 30),
            
            // Tagline
            tagline.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tagline.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tagline.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8)
        ])
        
        // Add pulse animation layer
        setupPulseLayer()
    }
    
    /// Load app icon from bundle
    private func loadAppIcon() -> UIImage? {
        // Try to load from AppIcon asset
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        
        // Try specific sizes from AppIcon
        let sizes = ["120", "180", "87", "80", "60"]
        for size in sizes {
            if let image = UIImage(named: size) {
                return image
            }
        }
        
        return nil
    }
    
    /// Create grid pattern path
    private func createGridPath() -> UIBezierPath {
        let path = UIBezierPath()
        let gridSize: CGFloat = 40
        
        // Vertical lines
        var x: CGFloat = 0
        while x <= view.bounds.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: view.bounds.height))
            x += gridSize
        }
        
        // Horizontal lines
        var y: CGFloat = 0
        while y <= view.bounds.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: view.bounds.width, y: y))
            y += gridSize
        }
        
        return path
    }
    
    /// Setup particle emitter for network effect
    private func setupParticleEmitter() {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: view.bounds.width / 2, y: view.bounds.height / 2)
        emitter.emitterSize = CGSize(width: view.bounds.width, height: view.bounds.height)
        emitter.emitterShape = .rectangle
        emitter.renderMode = .additive
        
        let cell = CAEmitterCell()
        cell.birthRate = 3
        cell.lifetime = 8
        cell.velocity = 20
        cell.velocityRange = 10
        cell.emissionRange = .pi * 2
        cell.scale = 0.1
        cell.scaleRange = 0.05
        cell.alphaSpeed = -0.1
        cell.color = UIColor.cyan.withAlphaComponent(0.6).cgColor
        
        // Create a small circle for the particle
        let size: CGFloat = 8
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), false, 0)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).fill()
        cell.contents = UIGraphicsGetImageFromCurrentImageContext()?.cgImage
        UIGraphicsEndImageContext()
        
        emitter.emitterCells = [cell]
        view.layer.insertSublayer(emitter, at: 1)
        self.particleEmitter = emitter
    }
    
    /// Setup pulse animation layer
    private func setupPulseLayer() {
        guard let circleBg = circleBackground else { return }
        
        let pulse = CAShapeLayer()
        pulse.path = UIBezierPath(ovalIn: CGRect(x: -30, y: -30, width: 200, height: 200)).cgPath
        pulse.fillColor = UIColor.clear.cgColor
        pulse.strokeColor = UIColor.cyan.withAlphaComponent(0.5).cgColor
        pulse.lineWidth = 2
        pulse.position = CGPoint(x: 70, y: 70)
        circleBg.layer.insertSublayer(pulse, at: 0)
        self.pulseLayer = pulse
    }
    
    private func startAnimations() {
        isAnimating = true
        
        // Initial state
        appIconView?.alpha = 0
        appIconView?.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        appTitleLabel?.alpha = 0
        appTitleLabel?.transform = CGAffineTransform(translationX: 0, y: 20)
        taglineLabel?.alpha = 0
        circleBackground?.alpha = 0
        circleBackground?.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        
        // Animate circle background
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5) { [weak self] in
            self?.circleBackground?.alpha = 1
            self?.circleBackground?.transform = .identity
        }
        
        // Animate app icon
        UIView.animate(withDuration: 0.8, delay: 0.2, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) { [weak self] in
            self?.appIconView?.alpha = 1
            self?.appIconView?.transform = .identity
        }
        
        // Animate title
        UIView.animate(withDuration: 0.6, delay: 0.4, options: .curveEaseOut) { [weak self] in
            self?.appTitleLabel?.alpha = 1
            self?.appTitleLabel?.transform = .identity
        }
        
        // Animate tagline
        UIView.animate(withDuration: 0.6, delay: 0.5, options: .curveEaseOut) { [weak self] in
            self?.taglineLabel?.alpha = 1
        }
        
        // Pulse animation
        animatePulse()
        
        // Gradient animation
        animateGradient()
    }
    
    private func animatePulse() {
        guard let pulseLayer = pulseLayer else { return }
        
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.5
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.5
        opacityAnimation.toValue = 0
        
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [scaleAnimation, opacityAnimation]
        animationGroup.duration = 1.5
        animationGroup.repeatCount = 2
        animationGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        pulseLayer.add(animationGroup, forKey: "pulse")
    }
    
    private func animateGradient() {
        guard let gradientLayer = gradientLayer else { return }
        
        let animation = CABasicAnimation(keyPath: "colors")
        animation.fromValue = gradientLayer.colors
        animation.toValue = [
            UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0).cgColor,
            UIColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0).cgColor
        ]
        animation.duration = 2.0
        animation.autoreverses = true
        animation.repeatCount = 1
        
        gradientLayer.add(animation, forKey: "gradientAnimation")
    }
    
    private func stopAllAnimations() {
        isAnimating = false
        
        appIconView?.layer.removeAllAnimations()
        circleBackground?.layer.removeAllAnimations()
        appTitleLabel?.layer.removeAllAnimations()
        taglineLabel?.layer.removeAllAnimations()
        pulseLayer?.removeAllAnimations()
        gradientLayer?.removeAllAnimations()
        particleEmitter?.removeAllAnimations()
        view.layer.removeAllAnimations()
    }
    
    /// Transition to main app
    func transitionToMainApp(in window: UIWindow, with viewController: UIViewController) {
        stopAllAnimations()
        
        // Scale down and fade out animation
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseIn, animations: { [weak self] in
            self?.view.alpha = 0
            self?.appIconView?.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
            self?.circleBackground?.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { [weak self] _ in
            self?.cleanup()
            window.rootViewController = viewController
        }
    }
    
    private func cleanup() {
        stopAllAnimations()
        
        gradientLayer?.removeFromSuperlayer()
        particleEmitter?.removeFromSuperlayer()
        pulseLayer?.removeFromSuperlayer()
        gridLayer?.removeFromSuperlayer()
        
        gradientLayer = nil
        particleEmitter = nil
        pulseLayer = nil
        gridLayer = nil
        
        view.subviews.forEach { $0.removeFromSuperview() }
    }
    
    /// Legacy hide method for compatibility
    func hide(completion: @escaping () -> Void) {
        stopAllAnimations()
        
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            self?.view.alpha = 0
        }) { [weak self] _ in
            self?.cleanup()
            self?.view.removeFromSuperview()
            completion()
        }
    }
}

