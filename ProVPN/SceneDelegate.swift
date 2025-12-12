//
//  SceneDelegate.swift
//  ProVPN
//
//  Created by DREAMWORLD on 24/11/25.
//

import UIKit
import SwiftUI
import Network
import Combine

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var animatedLaunchVC: AnimatedLaunchViewController?
    private var hasCheckedConnectivity = false
    private var networkCancellable: AnyCancellable?
    private var wasConnectedToNetwork = true
    private var isShowingAlert = false
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            
            // Create the SwiftUI view that provides the window contents.
            let contentView = ServerListView()
            let hostingController = UIHostingController(rootView: contentView)
            
            // Show animated launch screen first
            let animatedLaunch = AnimatedLaunchViewController()
            self.animatedLaunchVC = animatedLaunch
            window.rootViewController = animatedLaunch
            self.window = window
            window.makeKeyAndVisible()
            
            // Hide launch screen after delay and check connectivity
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self, weak window] in
                guard let self = self, let window = window else { return }
                
                self.animatedLaunchVC?.transitionToMainApp(in: window, with: hostingController)
                self.animatedLaunchVC = nil // Release reference
                
                // Check network connectivity after transition
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.checkNetworkConnectivity()
                    // Start continuous network monitoring
                    self.startNetworkMonitoring()
                }
            }
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Release animated launch controller if still held
        animatedLaunchVC = nil
        stopNetworkMonitoring()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Check connectivity when app becomes active (returning from Settings)
        if hasCheckedConnectivity {
            // Re-check when coming back from background/settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.checkNetworkConnectivity()
            }
        }
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Re-check connectivity when coming to foreground
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.checkNetworkConnectivity()
        }
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
    
    // MARK: - Network Monitoring
    
    /// Start continuous network monitoring
    private func startNetworkMonitoring() {
        // Subscribe to network status changes via Combine
        networkCancellable = NetworkMonitor.shared.$isConnected
            .dropFirst() // Skip initial value
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.handleNetworkChange(isConnected: isConnected)
            }
        
        // Also observe the notification for instant updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkStatusNotification(_:)),
            name: .networkStatusChanged,
            object: nil
        )
        
        // Observe show alert notification from ViewModel
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleShowNoInternetAlert),
            name: .showNoInternetAlert,
            object: nil
        )
        
        // Observe connection failed notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionFailed(_:)),
            name: .connectionFailed,
            object: nil
        )
    }
    
    @objc private func handleNetworkStatusNotification(_ notification: Notification) {
        guard let isConnected = notification.userInfo?["isConnected"] as? Bool else { return }
        handleNetworkChange(isConnected: isConnected)
    }
    
    @objc private func handleShowNoInternetAlert() {
        showNoInternetAlert(message: "Please connect to the internet before connecting to VPN.")
    }
    
    @objc private func handleConnectionFailed(_ notification: Notification) {
        let reason = notification.userInfo?["reason"] as? String ?? "Connection failed. Please try again."
        showConnectionFailedAlert(reason: reason)
    }
    
    /// Stop network monitoring
    private func stopNetworkMonitoring() {
        networkCancellable?.cancel()
        networkCancellable = nil
        NotificationCenter.default.removeObserver(self, name: .networkStatusChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .showNoInternetAlert, object: nil)
        NotificationCenter.default.removeObserver(self, name: .connectionFailed, object: nil)
    }
    
    /// Handle network connectivity changes
    private func handleNetworkChange(isConnected: Bool) {
        if !isConnected && wasConnectedToNetwork {
            // Network just disconnected
            Log.append("Network disconnected - stopping VPN", .warning, .mainApp)
            
            // Disconnect VPN
            disconnectVPNDueToNetworkLoss()
            
            // Show alert
            showNoInternetAlert(message: "Your internet connection was lost. The VPN has been disconnected.")
        } else if isConnected && !wasConnectedToNetwork {
            // Network restored
            Log.append("Network connection restored", .info, .mainApp)
            
            // Dismiss any existing no-internet alert
            dismissNoInternetAlertIfPresent()
        }
        
        wasConnectedToNetwork = isConnected
    }
    
    /// Disconnect VPN when network is lost
    private func disconnectVPNDueToNetworkLoss() {
        // Post notification to disconnect VPN
        NotificationCenter.default.post(name: .networkLostDisconnectVPN, object: nil)
    }
    
    // MARK: - Network Connectivity Check
    
    private func checkNetworkConnectivity() {
        NetworkMonitor.checkConnectivity { [weak self] isConnected in
            self?.hasCheckedConnectivity = true
            self?.wasConnectedToNetwork = isConnected
            
            if !isConnected {
                self?.showNoInternetAlert()
            }
        }
    }
    
    private func showNoInternetAlert(message: String? = nil) {
        guard let rootViewController = window?.rootViewController else { return }
        guard !isShowingAlert else { return }
        
        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Don't show multiple alerts
        if topController is UIAlertController { return }
        
        isShowingAlert = true
        
        let alertMessage = message ?? "Please connect to WiFi or enable cellular data to use the VPN."
        
        let alert = UIAlertController(
            title: "No Internet Connection",
            message: alertMessage,
            preferredStyle: .alert
        )
        
        // Open Settings action
        let settingsAction = UIAlertAction(title: "Open Settings", style: .default) { [weak self] _ in
            self?.isShowingAlert = false
            NetworkMonitor.openSettings()
        }
        
        // Retry action
        let retryAction = UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.isShowingAlert = false
            self?.checkNetworkConnectivity()
        }
        
        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.isShowingAlert = false
        }
        
        alert.addAction(settingsAction)
        alert.addAction(retryAction)
        alert.addAction(cancelAction)
        
        topController.present(alert, animated: true, completion: nil)
    }
    
    private func dismissNoInternetAlertIfPresent() {
        guard let rootViewController = window?.rootViewController else { return }
        
        // Find if there's an alert being presented
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Dismiss if it's our no-internet alert
        if let alert = topController as? UIAlertController,
           alert.title == "No Internet Connection" {
            alert.dismiss(animated: true) { [weak self] in
                self?.isShowingAlert = false
            }
        }
    }
    
    // MARK: - Connection Failed Alert
    
    private func showConnectionFailedAlert(reason: String) {
        guard let rootViewController = window?.rootViewController else { return }
        guard !isShowingAlert else { return }
        
        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        // Don't show multiple alerts
        if topController is UIAlertController { return }
        
        isShowingAlert = true
        
        let alert = UIAlertController(
            title: "Connection Failed",
            message: reason,
            preferredStyle: .alert
        )
        
        // Try Again action
        let retryAction = UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in
            self?.isShowingAlert = false
            // Post notification to retry connection
            NotificationCenter.default.post(name: .retryConnection, object: nil)
        }
        
        // Choose Another Server action
        let chooseAction = UIAlertAction(title: "Choose Another Server", style: .default) { [weak self] _ in
            self?.isShowingAlert = false
            // Post notification to reset connection state
            NotificationCenter.default.post(name: .resetConnectionState, object: nil)
        }
        
        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.isShowingAlert = false
        }
        
        alert.addAction(retryAction)
        alert.addAction(chooseAction)
        alert.addAction(cancelAction)
        
        topController.present(alert, animated: true, completion: nil)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkLostDisconnectVPN = Notification.Name("networkLostDisconnectVPN")
    static let showNoInternetAlert = Notification.Name("showNoInternetAlert")
    static let connectionFailed = Notification.Name("connectionFailed")
    static let retryConnection = Notification.Name("retryConnection")
    static let resetConnectionState = Notification.Name("resetConnectionState")
}
