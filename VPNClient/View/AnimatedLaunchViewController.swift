//
//  AnimatedLaunchViewController.swift
//  VPNClient
//
//  Created by DREAMWORLD on 24/11/25.
//

import UIKit

/// Animated launch screen view controller - Memory optimized
class AnimatedLaunchViewController: UIViewController {
    
    private weak var lockIconView: UIImageView?
    private weak var circleBackground: UIView?
    private weak var appTitleLabel: UILabel?
    private weak var taglineLabel: UILabel?
    private weak var loadingIndicator: UIView?
    private var gradientLayer: CAGradientLayer?
    private var isAnimating = false
    
    deinit {
        // Ensure all animations are stopped when view controller is deallocated
        stopAllAnimations()
        gradientLayer?.removeFromSuperlayer()
        gradientLayer = nil
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
        // Update gradient frame on layout changes
        gradientLayer?.frame = view.bounds
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.1, green: 0.16, blue: 0.26, alpha: 1.0)
        
        // Background gradient
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [
            UIColor(red: 0.1, green: 0.16, blue: 0.26, alpha: 1.0).cgColor,
            UIColor(red: 0.15, green: 0.22, blue: 0.35, alpha: 1.0).cgColor
        ]
        gradient.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1.0)
        view.layer.insertSublayer(gradient, at: 0)
        self.gradientLayer = gradient
        
        // Lock icon circle background
        let circleBg = UIView()
        circleBg.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        circleBg.layer.cornerRadius = 75
        circleBg.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(circleBg)
        self.circleBackground = circleBg
        
        // Lock icon - using smaller image
        let config = UIImage.SymbolConfiguration(pointSize: 50, weight: .medium)
        let lockIcon = UIImageView(image: UIImage(systemName: "lock.shield.fill", withConfiguration: config))
        lockIcon.tintColor = .systemBlue
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lockIcon)
        self.lockIconView = lockIcon
        
        // App title
        let titleLabel = UILabel()
        titleLabel.text = "VPN Client"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        self.appTitleLabel = titleLabel
        
        // Tagline
        let tagline = UILabel()
        tagline.text = "Secure & Private Connection"
        tagline.font = .systemFont(ofSize: 17, weight: .medium)
        tagline.textColor = UIColor.white.withAlphaComponent(0.8)
        tagline.textAlignment = .center
        tagline.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tagline)
        self.taglineLabel = tagline
        
        // Constraints
        NSLayoutConstraint.activate([
            // Circle background
            circleBg.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            circleBg.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            circleBg.widthAnchor.constraint(equalToConstant: 150),
            circleBg.heightAnchor.constraint(equalToConstant: 150),
            
            // Lock icon
            lockIcon.centerXAnchor.constraint(equalTo: circleBg.centerXAnchor),
            lockIcon.centerYAnchor.constraint(equalTo: circleBg.centerYAnchor),
            lockIcon.widthAnchor.constraint(equalToConstant: 80),
            lockIcon.heightAnchor.constraint(equalToConstant: 80),
            
            // App title
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            titleLabel.topAnchor.constraint(equalTo: circleBg.bottomAnchor, constant: 20),
            
            // Tagline
            tagline.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tagline.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tagline.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10)
        ])
    }
    
    private func startAnimations() {
        isAnimating = true
        
        // Simple fade in animation for title and tagline - NO repeating animations
        appTitleLabel?.alpha = 0
        taglineLabel?.alpha = 0
        
        UIView.animate(withDuration: 0.6, delay: 0.2, options: .curveEaseOut) { [weak self] in
            self?.appTitleLabel?.alpha = 1
        }
        
        UIView.animate(withDuration: 0.6, delay: 0.4, options: .curveEaseOut) { [weak self] in
            self?.taglineLabel?.alpha = 1
        }
        
        // Single pulse animation for icon (not repeating)
        UIView.animate(withDuration: 0.8, delay: 0, options: .curveEaseInOut) { [weak self] in
            self?.lockIconView?.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        } completion: { [weak self] _ in
            UIView.animate(withDuration: 0.4) {
                self?.lockIconView?.transform = .identity
            }
        }
    }
    
    private func stopAllAnimations() {
        isAnimating = false
        
        // Remove all animations from views
        lockIconView?.layer.removeAllAnimations()
        circleBackground?.layer.removeAllAnimations()
        appTitleLabel?.layer.removeAllAnimations()
        taglineLabel?.layer.removeAllAnimations()
        loadingIndicator?.layer.removeAllAnimations()
        loadingIndicator?.subviews.forEach { $0.layer.removeAllAnimations() }
        view.layer.removeAllAnimations()
    }
    
    /// Transition to main app
    func transitionToMainApp(in window: UIWindow, with viewController: UIViewController) {
        stopAllAnimations()
        
        UIView.animate(withDuration: 0.3, animations: { [weak self] in
            self?.view.alpha = 0
        }) { [weak self] _ in
            self?.cleanup()
            window.rootViewController = viewController
        }
    }
    
    private func cleanup() {
        stopAllAnimations()
        
        // Remove gradient layer
        gradientLayer?.removeFromSuperlayer()
        gradientLayer = nil
        
        // Remove all subviews
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

