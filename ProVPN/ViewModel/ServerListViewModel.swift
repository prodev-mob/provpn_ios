//
//  ServerListViewModel.swift
//  ProVPN
//
//  Created by DREAMWORLD on 24/11/25.
//

import SwiftUI
import Combine
import NetworkExtension

/// ViewModel for managing server list and connection
public class ServerListViewModel: ObservableObject {
    @Published var servers: [VPNServer] = VPNServerList.servers
    @Published var selectedServer: VPNServer?
    @Published var connection: Connection
    @Published var profile: Profile
    @Published var isConnecting = false
    @Published var serverPings: [String: Int?] = [:] // Server ID -> Ping in ms
    @Published var searchText: String = ""
    @Published var isNetworkAvailable: Bool = true // Track network availability
    
    // Connection timeout tracking
    private var connectionTimeoutTimer: Timer?
    private var timeoutCount: Int = 0
    private let maxTimeoutCount = 3 // Number of timeouts before failing
    private let connectionTimeoutSeconds: TimeInterval = 30 // Max time to wait for connection
    
    /// Filtered servers based on search text
    var filteredServers: [VPNServer] {
        if searchText.isEmpty {
            return servers
        }
        let lowercasedSearch = searchText.lowercased()
        return servers.filter { server in
            server.name.lowercased().contains(lowercasedSearch) ||
            server.country.lowercased().contains(lowercasedSearch) ||
            server.countryCode.lowercased().contains(lowercasedSearch)
        }
    }
    
    private var viewModel: ProfileViewModel
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        // 1. Initialize simple stored properties first
        self.servers = VPNServerList.servers
        self.selectedServer = nil
        self.isConnecting = false
        
        // 2. Initialize profile + connection before using them
        let defaultProfile = Profile(profileName: "default", profileId: "default")
        defaultProfile.anonymousAuth = true // Always start with anonymous auth enabled
        self.profile = defaultProfile
        self.connection = Connection(profile: defaultProfile)
        
        // 3. Initialize viewModel AFTER profile + connection exist
        self.viewModel = ProfileViewModel()
        self.viewModel.profile = self.profile
        self.viewModel.connection = self.connection
        
        // 4. Load saved profile if exists
        if let savedProfile = Settings.getSelectedProfile() {
            // Update stored properties (they're already initialized!)
            self.profile = savedProfile
            // Ensure anonymousAuth is set based on whether server has credentials
            if let server = servers.first(where: { $0.id == savedProfile.profileId }) {
                if server.username != nil && server.password != nil {
                    // Server has credentials, so anonymousAuth should be false
                    self.profile.anonymousAuth = false
                } else {
                    // No credentials needed, use anonymous auth
                    self.profile.anonymousAuth = true
                }
                self.selectedServer = server
            } else {
                // Default to anonymous auth if server not found
                self.profile.anonymousAuth = true
            }
            self.connection = Connection(profile: self.profile)
            self.viewModel.profile = self.profile
            self.viewModel.connection = self.connection
        }
        
        // Observe connection status changes
        observeConnectionStatus()
        
        // Observe network disconnect notification
        observeNetworkDisconnect()
        
        // Observe network status changes for UI updates
        observeNetworkStatus()
        
        // Set initial network status
        isNetworkAvailable = NetworkMonitor.isCurrentlyConnected
        
        // NOTE: Ping service disabled to reduce memory usage
        // Uncomment below to enable ping measurement
        // startPingingServers()
    }
    
    deinit {
        // Clean up subscriptions
        cancellables.removeAll()
        // Cancel timeout timer
        connectionTimeoutTimer?.invalidate()
        // Remove notification observers
        NotificationCenter.default.removeObserver(self, name: .networkLostDisconnectVPN, object: nil)
        NotificationCenter.default.removeObserver(self, name: .networkStatusChanged, object: nil)
        NotificationCenter.default.removeObserver(self, name: .retryConnection, object: nil)
    }
    
    /// Observe network disconnect notification to auto-disconnect VPN
    private func observeNetworkDisconnect() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkLost),
            name: .networkLostDisconnectVPN,
            object: nil
        )
    }
    
    /// Handle network lost - disconnect VPN automatically
    @objc private func handleNetworkLost() {
        if isConnected() {
            Log.append("Network lost - disconnecting VPN automatically", .warning, .mainApp)
            // Clear connection timer
            ConnectionDetailsCard.clearConnectionStartTime()
            // Disconnect VPN
            disconnect()
        }
    }
    
    /// Observe network status changes for enabling/disabling connect button
    private func observeNetworkStatus() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNetworkStatusChanged(_:)),
            name: .networkStatusChanged,
            object: nil
        )
        
        // Observe retry connection request
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRetryConnection),
            name: .retryConnection,
            object: nil
        )
    }
    
    /// Handle retry connection request from alert
    @objc private func handleRetryConnection() {
        // Only retry if we have a selected server and network
        guard selectedServer != nil, isNetworkAvailable else { return }
        
        // Small delay before retrying
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.connect()
        }
    }
    
    /// Handle network status change - update UI state
    @objc private func handleNetworkStatusChanged(_ notification: Notification) {
        if let isConnected = notification.userInfo?["isConnected"] as? Bool {
            DispatchQueue.main.async { [weak self] in
                self?.isNetworkAvailable = isConnected
            }
        }
    }
    
    // MARK: - Connection Timeout Handling
    
    /// Start connection timeout timer
    private func startConnectionTimeoutTimer() {
        cancelConnectionTimeoutTimer()
        
        connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeoutSeconds, repeats: false) { [weak self] _ in
            self?.handleConnectionTimeout()
        }
    }
    
    /// Cancel connection timeout timer
    private func cancelConnectionTimeoutTimer() {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        timeoutCount = 0
    }
    
    /// Monitor connection logs for timeout messages
    private func startMonitoringConnectionLogs() {
        // Observe log changes to detect server poll timeouts
        connection.$output
            .receive(on: DispatchQueue.main)
            .sink { [weak self] logs in
                self?.checkLogsForTimeout(logs)
            }
            .store(in: &cancellables)
    }
    
    /// Check logs for timeout patterns
    private func checkLogsForTimeout(_ logs: [Log]) {
        guard isConnecting || isConnectionInProgress() else { return }
        
        // Get recent logs (last 10)
        let recentLogs = logs.suffix(10)
        
        // Count timeout occurrences in recent logs
        var recentTimeouts = 0
        for log in recentLogs {
            let text = log.text.lowercased()
            if text.contains("server poll timeout") ||
               text.contains("connection timeout") ||
               text.contains("tls handshake failed") ||
               text.contains("server_poll") ||
               text.contains("inactivity timeout") {
                recentTimeouts += 1
            }
        }
        
        // If we have multiple timeouts, trigger failure
        if recentTimeouts >= maxTimeoutCount {
            handleConnectionTimeout(reason: "Server not responding. Multiple connection attempts failed.")
        }
        
        // Check for authentication errors
        for log in recentLogs {
            let text = log.text.lowercased()
            if text.contains("auth_failed") || text.contains("authentication failed") {
                handleConnectionTimeout(reason: "Authentication failed. Please check your credentials.")
                return
            }
            if text.contains("certificate verify failed") || text.contains("cert_verify_fail") {
                handleConnectionTimeout(reason: "Certificate verification failed.")
                return
            }
            if text.contains("connection refused") {
                handleConnectionTimeout(reason: "Connection refused by the server.")
                return
            }
        }
    }
    
    /// Handle connection timeout
    private func handleConnectionTimeout(reason: String? = nil) {
        guard isConnecting || isConnectionInProgress() else { return }
        
        let errorMessage = reason ?? "Connection timed out. The server is not responding."
        
        Log.append("Connection failed: \(errorMessage)", .error, .mainApp)
        
        // Stop the VPN attempt
        disconnect()
        
        // Clear connection timer
        ConnectionDetailsCard.clearConnectionStartTime()
        
        // Post notification to show alert
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .connectionFailed,
                object: nil,
                userInfo: ["reason": errorMessage]
            )
        }
    }
    
    /// Start pinging all servers to measure latency (disabled by default for memory optimization)
    func startPingingServers() {
        // Ping servers sequentially with delay to avoid memory spikes
        pingServersSequentially(index: 0)
    }
    
    /// Ping servers one at a time to reduce memory usage
    private func pingServersSequentially(index: Int) {
        guard index < servers.count else { return }
        
        let server = servers[index]
        pingServer(server) { [weak self] in
            // Small delay between pings to avoid memory pressure
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.pingServersSequentially(index: index + 1)
            }
        }
    }
    
    /// Ping a specific server
    func pingServer(_ server: VPNServer, completion: (() -> Void)? = nil) {
        guard let configData = server.loadConfigFile(),
              let configString = String(data: configData, encoding: .utf8) else {
            serverPings[server.id] = nil
            completion?()
            return
        }
        
        // Extract remote host and port from config
        var host: String?
        var port: Int = 443 // Default
        
        let lines = configString.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("remote ") {
                let parts = trimmed.components(separatedBy: .whitespaces)
                if parts.count >= 2 {
                    host = parts[1]
                    if parts.count >= 3, let portValue = Int(parts[2]) {
                        port = portValue
                    }
                }
                break
            }
        }
        
        guard let serverHost = host else {
            serverPings[server.id] = nil
            completion?()
            return
        }
        
        // Measure ping
        PingService.measurePing(host: serverHost, port: port) { [weak self] (ping: Int?) in
            DispatchQueue.main.async {
                self?.serverPings[server.id] = ping
                completion?()
            }
        }
    }
    
    /// Observe connection status changes for UI updates
    private func observeConnectionStatus() {
        // Observe connection status
        connection.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.objectWillChange.send()
                self?.updateConnectingState(status)
            }
            .store(in: &cancellables)
    }
    
    /// Update connecting state based on status
    private func updateConnectingState(_ status: NEVPNStatus) {
        switch status {
        case .connecting, .reasserting:
            isConnecting = true
        case .connected:
            // Successfully connected - cancel timeout timer
            cancelConnectionTimeoutTimer()
            isConnecting = false
        case .disconnected, .invalid, .disconnecting:
            // Connection ended - cancel timeout timer
            cancelConnectionTimeoutTimer()
            isConnecting = false
        @unknown default:
            isConnecting = false
        }
    }
    
    /// Select a server and load its configuration
    func selectServer(_ server: VPNServer) {
        selectedServer = server
        
        // Load config file
        guard let configData = server.loadConfigFile() else {
            Log.append("Failed to load config file for \(server.name)", .error, .mainApp)
            return
        }
        
        // Update profile with server info
        profile.profileName = "\(server.name) - \(server.country)"
        profile.profileId = server.id
        
        // Set config file
        connection.setConfigFile(configFile: configData)
        
        // Auto-set credentials if server has them defined (but keep anonymousAuth true for UI)
        if let username = server.username, let password = server.password {
            profile.username = username
            profile.password = password
            // Set anonymousAuth to false internally so credentials are used, but UI will show it as true
            profile.anonymousAuth = false
            Log.append("Auto-set credentials for \(server.name)", .info, .mainApp)
        } else {
            // Clear credentials for servers that don't need them
            profile.username = ""
            profile.password = ""
            profile.anonymousAuth = true
        }
        
        // Save profile
        Settings.saveProfile(profile: profile)
        Settings.setSelectedProfile(profileId: server.id)
    }
    
    /// Connect to selected server
    func connect() {
        guard selectedServer != nil else {
            Log.append("No server selected", .error, .mainApp)
            return
        }
        
        guard profile.configFile != nil else {
            Log.append("Config file is missing", .error, .mainApp)
            return
        }
        
        // Check network connectivity before connecting
        guard NetworkMonitor.isCurrentlyConnected else {
            Log.append("No internet connection - cannot connect to VPN", .error, .mainApp)
            // Post notification to show no internet alert
            NotificationCenter.default.post(name: .showNoInternetAlert, object: nil)
            return
        }
        
        // Reset timeout tracking
        timeoutCount = 0
        
        isConnecting = true
        connection.startVPN()
        
        // Start connection timeout timer
        startConnectionTimeoutTimer()
        
        // Start monitoring logs for timeout messages
        startMonitoringConnectionLogs()
    }
    
    /// Disconnect from current server
    func disconnect() {
        // Cancel timeout timer
        cancelConnectionTimeoutTimer()
        
        connection.stopVPN()
        isConnecting = false
    }
    
    /// Get connection status color
    func statusColor() -> Color {
        switch connection.connectionStatus {
        case .connected:
            return .green
        case .connecting, .reasserting:
            return .orange
        case .disconnecting:
            return .yellow
        case .disconnected, .invalid:
            return .gray
        @unknown default:
            return .gray
        }
    }
    
    /// Get connection status text
    func statusText() -> String {
        switch connection.connectionStatus {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnecting:
            return "Disconnecting..."
        case .reasserting:
            return "Reconnecting..."
        case .disconnected:
            return "Disconnected"
        case .invalid:
            return "Invalid"
        @unknown default:
            return "Unknown"
        }
    }
    
    /// Check if currently connected to a server
    func isConnected() -> Bool {
        return connection.connectionStatus == .connected
    }
    
    /// Check if connection is in progress
    func isConnectionInProgress() -> Bool {
        return connection.connectionStatus == .connecting ||
        connection.connectionStatus == .reasserting ||
        connection.connectionStatus == .disconnecting
    }
}
