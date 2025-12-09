//
//  NetworkMonitor.swift
//  ProVPN
//
//  Created by DREAMWORLD on 26/11/25.
//

import Foundation
import Network
import UIKit

/// Monitors network connectivity status
public class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .userInitiated)
    
    @Published var isConnected: Bool = true
    @Published var connectionType: ConnectionType = .unknown
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }
    
    private init() {
        startMonitoring()
    }
    
    /// Start monitoring network changes
    func startMonitoring() {
        // Cancel existing monitor if any
        monitor?.cancel()
        
        // Create new monitor
        let newMonitor = NWPathMonitor()
        monitor = newMonitor
        
        newMonitor.pathUpdateHandler = { [weak self] path in
            // Immediately update on main thread for faster UI response
            DispatchQueue.main.async {
                let wasConnected = self?.isConnected ?? true
                let nowConnected = path.status == .satisfied
                
                self?.isConnected = nowConnected
                self?.updateConnectionType(path)
                
                // Post notification immediately if connection state changed
                if wasConnected && !nowConnected {
                    NotificationCenter.default.post(name: .networkStatusChanged, object: nil, userInfo: ["isConnected": false])
                } else if !wasConnected && nowConnected {
                    NotificationCenter.default.post(name: .networkStatusChanged, object: nil, userInfo: ["isConnected": true])
                }
            }
        }
        newMonitor.start(queue: queue)
    }
    
    /// Stop monitoring network changes
    func stopMonitoring() {
        monitor?.cancel()
        monitor = nil
    }
    
    /// Force refresh network status
    func refreshStatus() {
        // Restart monitoring to get immediate status
        startMonitoring()
    }
    
    /// Update the connection type based on path
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else {
            connectionType = .unknown
        }
    }
    
    /// Check current connectivity status - instant check using cached value
    static var isCurrentlyConnected: Bool {
        return shared.isConnected
    }
    
    /// Check current connectivity status with callback
    /// Returns true if connected, false otherwise
    static func checkConnectivity(completion: @escaping (Bool) -> Void) {
        // First return cached value for instant response
        let cachedStatus = shared.isConnected
        
        // Also do a fresh check
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "ConnectivityCheck", qos: .userInitiated)
        
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                let isConnected = path.status == .satisfied
                // Update shared instance
                shared.isConnected = isConnected
                completion(isConnected)
            }
            monitor.cancel()
        }
        monitor.start(queue: queue)
    }
    
    /// Open device Settings app
    /// Note: Only works in main app, not in extensions
    static func openSettings() {
        // Use this workaround to avoid "shared is unavailable in extensions" error
        guard let application = Self.sharedApplication() else { return }
        
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if application.canOpenURL(url) {
                application.open(url, options: [:], completionHandler: nil)
            }
        }
    }
    
    /// Open WiFi Settings directly (iOS 16+)
    /// Note: Only works in main app, not in extensions
    static func openWiFiSettings() {
        guard let application = Self.sharedApplication() else {
            return
        }
        
        // Try WiFi settings first (may not work on all iOS versions)
        if let url = URL(string: "App-Prefs:root=WIFI") {
            if application.canOpenURL(url) {
                application.open(url, options: [:], completionHandler: nil)
                return
            }
        }
        // Fallback to general settings
        openSettings()
    }
    
    /// Get shared UIApplication instance safely (works around extension restriction)
    /// Returns nil if running in an extension
    private static func sharedApplication() -> UIApplication? {
        let sharedSelector = NSSelectorFromString("sharedApplication")
        guard UIApplication.responds(to: sharedSelector) else { return nil }
        
        let shared = UIApplication.perform(sharedSelector)
        return shared?.takeUnretainedValue() as? UIApplication
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

