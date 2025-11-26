//
//  ServerListView.swift
//  VPNClient
//
//  Created by DREAMWORLD on 24/11/25.
//

import SwiftUI
import NetworkExtension

/// Main view showing list of VPN servers
struct ServerListView: View {
    @StateObject private var viewModel = ServerListViewModel()
    @State private var showSettings = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Adaptive layout properties
    private var isIPad: Bool {
        horizontalSizeClass == .regular
    }
    
    private var contentMaxWidth: CGFloat {
        isIPad ? 900 : .infinity
    }
    
    private var horizontalPadding: CGFloat {
        isIPad ? 40 : 16
    }
    
    private var gridColumns: [GridItem] {
        if isIPad {
            return [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ]
        } else {
            return [GridItem(.flexible())]
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: isIPad ? 30 : 20) {
                        // Show different content based on connection state
                        if viewModel.isConnected() {
                            // Connected: Show Connection Details with Speed Gauge
                            ConnectionDetailsCard(viewModel: viewModel, isIPad: isIPad)
                                .frame(maxWidth: isIPad ? 700 : .infinity)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, isIPad ? 20 : 10)
                            
                            // Disconnect Button
                            Button(action: {
                                // Clear the connection timer when user explicitly disconnects
                                ConnectionDetailsCard.clearConnectionStartTime()
                                viewModel.disconnect()
                            }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Disconnect")
                                }
                                .font(isIPad ? .title3 : .headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: isIPad ? 300 : .infinity)
                                .padding(.vertical, isIPad ? 18 : 16)
                                .background(Color.red)
                                .cornerRadius(isIPad ? 16 : 12)
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, isIPad ? 40 : 30)
                        } else {
                            // Not Connected: Show Status Card and IP Checker
                            ConnectionStatusCard(viewModel: viewModel, isIPad: isIPad)
                                .frame(maxWidth: isIPad ? 600 : .infinity)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, isIPad ? 20 : 10)
                            
                            // IP Checker
                            MiniIPChecker(isIPad: isIPad)
                                .frame(maxWidth: isIPad ? 600 : .infinity)
                                .padding(.horizontal, horizontalPadding)
                            
                            // Search Bar
                            SearchBar(text: $viewModel.searchText, isDisabled: viewModel.isConnectionInProgress())
                                .frame(maxWidth: isIPad ? 600 : .infinity)
                                .padding(.horizontal, horizontalPadding)
                            
                            // Server List Section
                            VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
                                HStack {
                                    Text("Available Servers")
                                        .font(isIPad ? .title3 : .headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text("\(viewModel.filteredServers.count) servers")
                                        .font(isIPad ? .subheadline : .caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, horizontalPadding)
                                
                                if viewModel.filteredServers.isEmpty {
                                    // No results view
                                    VStack(spacing: isIPad ? 16 : 12) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.system(size: isIPad ? 60 : 40))
                                            .foregroundColor(.secondary)
                                        Text("No servers found")
                                            .font(isIPad ? .title2 : .headline)
                                            .foregroundColor(.secondary)
                                        Text("Try a different search term")
                                            .font(isIPad ? .body : .subheadline)
                                            .foregroundColor(.secondary.opacity(0.7))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, isIPad ? 60 : 40)
                                } else {
                                    // Server Grid/List
                                    LazyVGrid(columns: gridColumns, spacing: isIPad ? 16 : 12) {
                                        ForEach(viewModel.filteredServers) { server in
                                            ServerRow(
                                                server: server,
                                                isSelected: viewModel.selectedServer?.id == server.id,
                                                isConnected: viewModel.isConnected() && viewModel.selectedServer?.id == server.id,
                                                connectionStatus: viewModel.connection.connectionStatus,
                                                isListDisabled: viewModel.isConnectionInProgress(),
                                                ping: viewModel.serverPings[server.id] ?? nil,
                                                isIPad: isIPad
                                            ) {
                                                handleServerTap(server)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, horizontalPadding)
                                }
                            }
                            .frame(maxWidth: contentMaxWidth)
                            .padding(.bottom, isIPad ? 40 : 20)
                            .allowsHitTesting(!viewModel.isConnectionInProgress())
                            .opacity(viewModel.isConnectionInProgress() ? 0.5 : 1.0)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("VPN Client")
            .navigationBarTitleDisplayMode(isIPad ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                            if isIPad {
                                Text("Settings")
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel, isIPad: isIPad)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func handleServerTap(_ server: VPNServer) {
        // Don't allow selection if already connected or connecting
        guard !viewModel.isConnected() && !viewModel.isConnectionInProgress() else {
            return
        }
        
        // Only select the server, don't connect automatically
        viewModel.selectServer(server)
    }
}

/// Connection Status Card
struct ConnectionStatusCard: View {
    @ObservedObject var viewModel: ServerListViewModel
    var isIPad: Bool = false
    
    private var circleSize: CGFloat { isIPad ? 160 : 120 }
    private var iconSize: CGFloat { isIPad ? 70 : 50 }
    private var cardPadding: CGFloat { isIPad ? 32 : 24 }
    
    var body: some View {
        VStack(spacing: isIPad ? 28 : 20) {
            // Status Indicator
            ZStack {
                Circle()
                    .fill(statusBackgroundColor.opacity(0.15))
                    .frame(width: circleSize, height: circleSize)
                
                if viewModel.isConnectionInProgress() {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: statusColor))
                        .scaleEffect(isIPad ? 1.8 : 1.3)
                } else {
                    Image(systemName: statusIcon)
                        .font(.system(size: iconSize, weight: .medium))
                        .foregroundColor(statusColor)
                }
            }
            
            // Status Text
            VStack(spacing: isIPad ? 12 : 8) {
                Text(viewModel.statusText())
                    .font(isIPad ? .title : .title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                if let server = viewModel.selectedServer {
                    if viewModel.isConnected() {
                        HStack(spacing: 8) {
                            Text(server.flag)
                                .font(isIPad ? .title2 : .title3)
                            Text("\(server.name), \(server.countryCode)")
                                .font(isIPad ? .body : .subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: 8) {
                            Text(server.flag)
                                .font(isIPad ? .title2 : .title3)
                            Text("\(server.name) - Ready to connect")
                                .font(isIPad ? .body : .subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Select a server from the list below")
                        .font(isIPad ? .body : .subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Action Button
            Button(action: {
                if viewModel.isConnected() {
                    viewModel.disconnect()
                } else if viewModel.selectedServer != nil && !viewModel.isConnectionInProgress() {
                    // Clear any old timer before starting new connection
                    ConnectionDetailsCard.clearConnectionStartTime()
                    viewModel.connect()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: buttonIcon)
                        .font(isIPad ? .title3 : .body)
                    Text(buttonText)
                }
                .font(isIPad ? .title3 : .headline)
//                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: isIPad ? 300 : .infinity)
                .padding(.vertical, isIPad ? 18 : 16)
                .background(buttonBackgroundColor)
                .cornerRadius(isIPad ? 16 : 12)
            }
            .disabled(viewModel.isConnectionInProgress() || (viewModel.selectedServer == nil && !viewModel.isConnected()))
            .opacity((viewModel.isConnectionInProgress() || (viewModel.selectedServer == nil && !viewModel.isConnected())) ? 0.6 : 1.0)
        }
        .padding(cardPadding)
        .background(
            RoundedRectangle(cornerRadius: isIPad ? 24 : 20)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: Color.black.opacity(0.05), radius: isIPad ? 15 : 10, x: 0, y: 5)
        )
    }
    
    private var statusColor: Color {
        viewModel.statusColor()
    }
    
    private var statusBackgroundColor: Color {
        viewModel.statusColor()
    }
    
    private var statusIcon: String {
        if viewModel.isConnected() {
            return "checkmark.circle.fill"
        } else {
            return "circle"
        }
    }
    
    private var buttonText: String {
        if viewModel.isConnected() {
            return "Disconnect"
        } else if viewModel.selectedServer != nil {
            return "Connect"
        } else {
            return "Select a Server"
        }
    }
    
    private var buttonIcon: String {
        if viewModel.isConnected() {
            return "xmark.circle.fill"
        } else {
            return "lock.fill"
        }
    }
    
    private var buttonBackgroundColor: Color {
        if viewModel.isConnected() {
            return Color.red
        } else {
            return Color.green
        }
    }
}

/// Server Row Component
struct ServerRow: View {
    let server: VPNServer
    let isSelected: Bool
    let isConnected: Bool
    let connectionStatus: NEVPNStatus
    let isListDisabled: Bool
    let ping: Int?
    var isIPad: Bool = false
    let onTap: () -> Void
    
    private var flagSize: CGFloat { isIPad ? 48 : 36 }
    private var flagContainerSize: CGFloat { isIPad ? 64 : 50 }
    private var rowPadding: CGFloat { isIPad ? 20 : 16 }
    private var cornerRadius: CGFloat { isIPad ? 16 : 12 }
    
    var body: some View {
        Button(action: {
            // Only allow selection if list is not disabled
            if !isListDisabled {
                onTap()
            }
        }) {
            HStack(spacing: isIPad ? 20 : 16) {
                // Flag
                Text(server.flag)
                    .font(.system(size: flagSize))
                    .frame(width: flagContainerSize, height: flagContainerSize)
                    .background(
                        Circle()
                            .fill(Color(UIColor.tertiarySystemFill))
                    )
                
                // Server Info
                VStack(alignment: .leading, spacing: isIPad ? 6 : 4) {
                    Text(server.name)
                        .font(isIPad ? .title3 : .headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    HStack(spacing: 8) {
                        Text(server.countryCode)
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                        
//                        if let pingValue = ping {
//                            HStack(spacing: 4) {
//                                Image(systemName: "speedometer")
//                                    .font(.system(size: isIPad ? 12 : 10))
//                                Text("\(pingValue)ms")
//                                    .font(isIPad ? .subheadline : .caption)
//                            }
//                            .foregroundColor(pingColor(pingValue))
//                            .padding(.horizontal, isIPad ? 8 : 6)
//                            .padding(.vertical, isIPad ? 4 : 2)
//                            .background(pingColor(pingValue).opacity(0.1))
//                            .cornerRadius(isIPad ? 6 : 4)
//                        } else {
//                            HStack(spacing: 4) {
//                                ProgressView()
//                                    .scaleEffect(isIPad ? 0.6 : 0.5)
//                                Text("...")
//                                    .font(isIPad ? .subheadline : .caption)
//                            }
//                            .foregroundColor(.secondary)
//                        }
                    }
                }
                
                Spacer()
                
                // Status Indicator
                if isConnected {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: isIPad ? 10 : 8, height: isIPad ? 10 : 8)
                        Text("Connected")
                            .font(isIPad ? .subheadline : .caption)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, isIPad ? 12 : 8)
                    .padding(.vertical, isIPad ? 8 : 6)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                } else if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(isIPad ? .title2 : .title3)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(isIPad ? .body : .caption)
                }
            }
            .padding(rowPadding)
            .frame(minHeight: isIPad ? 90 : 70)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isListDisabled && !isConnected ? Color(UIColor.tertiarySystemFill) : Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: isIPad ? 3 : 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isListDisabled)
    }
    
    private func pingColor(_ ping: Int) -> Color {
        if ping < 100 {
            return .green
        } else if ping < 200 {
            return .orange
        } else {
            return .red
        }
    }
}

/// Settings View
struct SettingsView: View {
    @ObservedObject var viewModel: ServerListViewModel
    var isIPad: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @State private var passwordSecured = true
    @State private var privKeyPassSecured = true
    @State private var developerTapCount = 0
    @State private var isDeveloperMode = Settings.isDeveloperModeEnabled
    @State private var showDeveloperModeAlert = false
    
    private var logHeight: CGFloat { isIPad ? 400 : 300 }
    private var logFontSize: CGFloat { isIPad ? 13 : 11 }
    
    var body: some View {
        NavigationView {
            Form {
                if viewModel.profile.privKeyPassRequired {
                    Section(header: Text("Security").font(isIPad ? .headline : .subheadline)) {
                        HStack {
                            if privKeyPassSecured {
                                SecureField("Private Key Password", text: $viewModel.profile.privateKeyPassword)
                                    .font(isIPad ? .body : .callout)
                            } else {
                                TextField("Private Key Password", text: $viewModel.profile.privateKeyPassword)
                                    .autocapitalization(.none)
                                    .font(isIPad ? .body : .callout)
                            }
                            Button(action: {
                                self.privKeyPassSecured.toggle()
                            }) {
                                Image(systemName: privKeyPassSecured ? "eye.slash" : "eye")
                                    .foregroundColor(.blue)
                                    .font(isIPad ? .title3 : .body)
                            }
                        }
                        .padding(.vertical, isIPad ? 4 : 0)
                    }
                }
                
                Section(header: Text("DNS Settings").font(isIPad ? .headline : .subheadline)) {
                    Toggle(isOn: $viewModel.profile.customDNSEnabled) {
                        Text("Use Custom DNS")
                            .font(isIPad ? .body : .callout)
                    }
                    .padding(.vertical, isIPad ? 4 : 0)
                    
                    if viewModel.profile.customDNSEnabled {
                        ForEach(0..<viewModel.profile.dnsList.count, id: \.self) { index in
                            TextField("DNS Address", text: Binding(
                                get: {
                                    index < viewModel.profile.dnsList.count ? viewModel.profile.dnsList[index] : ""
                                },
                                set: {
                                    if index < viewModel.profile.dnsList.count {
                                        viewModel.profile.dnsList[index] = $0
                                    }
                                }
                            ))
                            .font(isIPad ? .body : .callout)
                            .padding(.vertical, isIPad ? 4 : 0)
                        }
                        
                        Button(action: {
                            viewModel.profile.dnsList.append("")
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(isIPad ? .title3 : .body)
                                Text("Add DNS Server")
                                    .font(isIPad ? .body : .callout)
                            }
                        }
                        .padding(.vertical, isIPad ? 4 : 0)
                    }
                }
                
                // Connection Logs - Only visible in Developer Mode
                if isDeveloperMode {
                    Section(header: developerLogHeader) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: isIPad ? 8 : 6) {
                                ForEach(Array(viewModel.connection.output.suffix(100)), id: \.id) { log in
                                    Text(log.text)
                                        .font(.system(size: logFontSize, design: .monospaced))
                                        .foregroundColor(logColor(log.level))
                                        .textSelection(.enabled)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: logHeight)
                        
                        Button(action: {
                            Settings.setDeveloperMode(false)
                            isDeveloperMode = false
                        }) {
                            HStack {
                                Image(systemName: "eye.slash.fill")
                                    .font(isIPad ? .title3 : .body)
                                Text("Exit Developer Mode")
                                    .font(isIPad ? .body : .callout)
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.vertical, isIPad ? 4 : 0)
                    }
                }
                
                // App Info Section
                Section(header: Text("About").font(isIPad ? .headline : .subheadline)) {
                    HStack {
                        Text("Version")
                            .font(isIPad ? .body : .callout)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                            .foregroundColor(.secondary)
                            .font(isIPad ? .body : .callout)
                    }
                    .padding(.vertical, isIPad ? 4 : 0)
                    
                    HStack {
                        Text("Device")
                            .font(isIPad ? .body : .callout)
                        Spacer()
                        Text(isIPad ? "iPad" : "iPhone")
                            .foregroundColor(.secondary)
                            .font(isIPad ? .body : .callout)
                    }
                    .padding(.vertical, isIPad ? 4 : 0)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    // Hidden developer mode trigger - tap 5 times on title
                    Text("Settings")
                        .font(isIPad ? .title3 : .headline)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            handleDeveloperTap()
                        }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        Settings.saveProfile(profile: viewModel.profile)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(isIPad ? .body : .callout)
                }
            }
            .alert(isPresented: $showDeveloperModeAlert) {
                Alert(
                    title: Text(isDeveloperMode ? "Developer Mode Enabled" : "Developer Mode Disabled"),
                    message: Text(isDeveloperMode ? "Connection logs are now visible." : "Connection logs are now hidden."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .frame(minWidth: isIPad ? 540 : nil, minHeight: isIPad ? 600 : nil)
    }
    
    private var developerLogHeader: some View {
        HStack {
            Text("Connection Logs")
            Spacer()
            Image(systemName: "hammer.fill")
                .foregroundColor(.orange)
                .font(.caption)
            Text("Developer")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    
    private func handleDeveloperTap() {
        developerTapCount += 1
        
        // Reset count after 3 seconds of inactivity
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if developerTapCount > 0 && developerTapCount < 5 {
                developerTapCount = 0
            }
        }
        
        // Toggle developer mode after 5 taps
        if developerTapCount >= 5 {
            developerTapCount = 0
            Settings.toggleDeveloperMode()
            isDeveloperMode = Settings.isDeveloperModeEnabled
            showDeveloperModeAlert = true
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private func logColor(_ level: Log.LogLevel) -> Color {
        switch level {
        case .debug:
            return .gray
        case .info, .notice:
            return .primary
        case .warning:
            return .orange
        case .error, .critical, .alert, .emergency:
            return .red
        }
    }
}

/// Custom Search Bar Component
struct SearchBar: View {
    @Binding var text: String
    var isDisabled: Bool = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isDisabled ? .secondary.opacity(0.5) : .secondary)
                
                TextField("Search servers...", text: $text)
                    .font(.body)
                    .foregroundColor(.primary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($isFocused)
                    .disabled(isDisabled)
                
                if !text.isEmpty && !isDisabled {
                    Button(action: {
                        text = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.blue : Color.clear, lineWidth: 1.5)
            )
            
            // Cancel button when focused
            if isFocused {
                Button("Cancel") {
                    text = ""
                    isFocused = false
                }
                .font(.body)
                .foregroundColor(.blue)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

struct ServerListView_Previews: PreviewProvider {
    static var previews: some View {
        ServerListView()
    }
}
