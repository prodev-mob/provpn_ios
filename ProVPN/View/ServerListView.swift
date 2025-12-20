//
//  ServerListView.swift
//  ProVPN
//
//  Created by DREAMWORLD on 24/11/25.
//

import SwiftUI
import NetworkExtension

/// Main view showing list of VPN servers
struct ServerListView: View {
    @StateObject private var viewModel = ServerListViewModel()
    @State private var showSettings = false
    @State private var showBrowser = false
    @State private var showConnectedCelebration = false
    @State private var showDisconnectingCelebration = false
    @State private var shouldShowDetailsView = false
    @State private var hasInitializedConnectionState = false
    @State private var previousConnectionStatus: NEVPNStatus = .invalid
    @State private var isCheckingInitialState = true
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
                // Animated VPN Background
                AnimatedBackground()
                
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(spacing: isIPad ? 30 : 20) {
                            // Anchor for scroll to top
                            Color.clear
                                .frame(height: 1)
                                .id("top")
                            
                            // Show different content based on connection state with animations
                            if isCheckingInitialState {
                                // Show nothing while checking initial connection state
                                Color.clear
                                    .frame(height: 200)
                            } else if showConnectedCelebration {
                                // Show Connected Celebration Animation
                                ConnectedCelebrationView(viewModel: viewModel, isIPad: isIPad)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.7)),
                                        removal: .scale(scale: 1.1).combined(with: .opacity).animation(.easeOut(duration: 0.4))
                                    ))
                            } else if showDisconnectingCelebration {
                                // Show Disconnecting Animation
                                DisconnectingCelebrationView(viewModel: viewModel, isIPad: isIPad)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.7)),
                                        removal: .scale(scale: 0.9).combined(with: .opacity).animation(.easeOut(duration: 0.4))
                                    ))
                            } else if shouldShowDetailsView && viewModel.isConnected() {
                                // Connected: Show Connection Details with Speed Gauge
                                ConnectedStateView(viewModel: viewModel, isIPad: isIPad, horizontalPadding: horizontalPadding, showBrowser: $showBrowser)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.9).combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.8)),
                                        removal: .scale(scale: 0.9).combined(with: .opacity).animation(.easeOut(duration: 0.3))
                                    ))
                            } else {
                                // Not Connected: Show Animated Status Card with VPN Toggle
                                DisconnectedStateView(viewModel: viewModel, isIPad: isIPad, horizontalPadding: horizontalPadding, contentMaxWidth: contentMaxWidth, gridColumns: gridColumns, handleServerTap: handleServerTap)
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.9).combined(with: .opacity).animation(.spring(response: 0.5, dampingFraction: 0.8)),
                                        removal: .scale(scale: 0.9).combined(with: .opacity).animation(.easeOut(duration: 0.3))
                                    ))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.isConnected())
                    }
                    .refreshable {
                        // Pull to refresh - reload servers from API
                        await viewModel.refreshServers()
                    }
                    .onChange(of: viewModel.connection.connectionStatus) { newStatus in
                        handleConnectionStatusChange(newStatus, scrollProxy: scrollProxy)
                    }
                    .onAppear {
                        // Initialize connection state on first appear
                        if isCheckingInitialState {
                            // Small delay to ensure VPN status is loaded
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                hasInitializedConnectionState = true
                                previousConnectionStatus = viewModel.connection.connectionStatus
                                
                                if viewModel.isConnected() {
                                    // Already connected - go directly to details view
                                    shouldShowDetailsView = true
                                    showConnectedCelebration = false
                                    showDisconnectingCelebration = false
                                }
                                
                                // Now show the appropriate view
                                withAnimation(.easeOut(duration: 0.2)) {
                                    isCheckingInitialState = false
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("ProVPN")
            .navigationBarTitleDisplayMode(isIPad ? .inline : .large)
            .toolbar(content: {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: isIPad ? 16 : 12) {
                        // Browser Button
                        Button(action: {
                            showBrowser = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari.fill")
                                if isIPad {
                                    Text("Browser")
                                }
                            }
                            .foregroundColor(.cyan)
                        }
                        
                        // Settings Button
                        Button(action: {
                            showSettings = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "gearshape.fill")
                                if isIPad {
                                    Text("Settings")
                                }
                            }
                            .foregroundColor(.cyan)
                        }
                    }
                }
            })
            .sheet(isPresented: $showSettings) {
                SettingsView(viewModel: viewModel, isIPad: isIPad)
            }
            .fullScreenCover(isPresented: $showBrowser) {
                NavigationView {
                    BrowserView(viewModel: viewModel)
                }
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
    
    private func handleConnectionStatusChange(_ status: NEVPNStatus, scrollProxy: ScrollViewProxy) {
        // Determine if this is a fresh connection (transitioning from connecting to connected)
        let isFreshConnection = previousConnectionStatus == .connecting || previousConnectionStatus == .reasserting
        
        // Update previous status for next comparison
        defer { previousConnectionStatus = status }
        
        switch status {
        case .connected:
            // Only show celebration for fresh connections, not app restore
            if isFreshConnection {
                // Show celebration animation for fresh connection
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showConnectedCelebration = true
                    showDisconnectingCelebration = false
                    shouldShowDetailsView = false
                }
                
                // Scroll to top
                withAnimation(.easeOut(duration: 0.3)) {
                    scrollProxy.scrollTo("top", anchor: .top)
                }
                
                // After 2 seconds, switch to details view
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showConnectedCelebration = false
                        shouldShowDetailsView = true
                    }
                }
            } else {
                // App restored with existing connection - go directly to details
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showConnectedCelebration = false
                    showDisconnectingCelebration = false
                    shouldShowDetailsView = true
                }
            }
            
        case .disconnecting:
            // Show disconnecting animation
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showDisconnectingCelebration = true
                showConnectedCelebration = false
                shouldShowDetailsView = false
            }
            
            // Scroll to top
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy.scrollTo("top", anchor: .top)
            }
            
        case .disconnected, .invalid:
            // If we were showing disconnecting animation, keep it for a moment
            if showDisconnectingCelebration {
                // After 1.5 seconds, switch to disconnected state view
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showDisconnectingCelebration = false
                        showConnectedCelebration = false
                        shouldShowDetailsView = false
                    }
                }
            } else {
                // Reset states immediately
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showConnectedCelebration = false
                    showDisconnectingCelebration = false
                    shouldShowDetailsView = false
                }
            }
            
            // Scroll to top
            withAnimation(.easeOut(duration: 0.3)) {
                scrollProxy.scrollTo("top", anchor: .top)
            }
            
        default:
            break
        }
    }
}

// MARK: - Connected Celebration View
struct ConnectedCelebrationView: View {
    @ObservedObject var viewModel: ServerListViewModel
    var isIPad: Bool
    
    @State private var showCheckmark = false
    @State private var showRings = false
    @State private var showText = false
    @State private var showShield = false
    
    // Responsive sizes based on screen height
    private var isSmallScreen: Bool { UIScreen.main.bounds.height < 700 }
    private var circleSize: CGFloat { 
        isIPad ? 200 : (isSmallScreen ? 120 : 160) 
    }
    private var checkmarkSize: CGFloat { 
        isIPad ? 80 : (isSmallScreen ? 45 : 60) 
    }
    private var ringSpacing: CGFloat {
        isIPad ? 35 : (isSmallScreen ? 22 : 35)
    }
    private var particleOffset: CGFloat {
        isIPad ? 45 : (isSmallScreen ? 30 : 45)
    }
    private var glowSize: CGFloat {
        isIPad ? 160 : (isSmallScreen ? 100 : 160)
    }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            VStack(spacing: isIPad ? 40 : (isSmallScreen ? 16 : 30)) {
                ZStack {
                    // Outer glow pulse - continuous
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.green.opacity(0.4),
                                    Color.green.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: circleSize / 2,
                                endRadius: circleSize + 80
                            )
                        )
                        .frame(width: circleSize + glowSize, height: circleSize + glowSize)
                        .scaleEffect(1.0 + sin(time * 2) * 0.05)
                        .opacity(showRings ? 0.8 : 0)
                    
                    // Animated expanding rings - continuous using TimelineView
                    ForEach(0..<3, id: \.self) { index in
                        let phase = (time + Double(index) * 0.8).truncatingRemainder(dividingBy: 2.4)
                        let normalizedPhase = phase / 2.4
                        let scale = 1.0 + normalizedPhase * 0.6
                        let opacity = max(0, 0.5 - normalizedPhase * 0.6)
                        
                        Circle()
                            .stroke(
                                Color.green.opacity(0.5),
                                lineWidth: isIPad ? 3 : 2
                            )
                            .frame(width: circleSize, height: circleSize)
                            .scaleEffect(showRings ? scale : 0.5)
                            .opacity(showRings ? opacity : 0)
                    }
                    
                    // Static decorative rings
                    ForEach(0..<(isSmallScreen ? 3 : 4), id: \.self) { index in
                        Circle()
                            .stroke(
                                Color.green.opacity(0.2 - Double(index) * 0.04),
                                lineWidth: isIPad ? 2 : 1.5
                            )
                            .frame(width: circleSize + CGFloat(index) * ringSpacing, height: circleSize + CGFloat(index) * ringSpacing)
                            .scaleEffect(showRings ? 1 : 0.5)
                            .opacity(showRings ? (0.8 - Double(index) * 0.15) : 0)
                    }
                    
                    // Celebration particles - continuous rotation
                    ForEach(0..<(isSmallScreen ? 8 : 12), id: \.self) { index in
                        let rotation = time * 36 // degrees per second
                        let particleAngle = isSmallScreen ? 45.0 : 30.0
                        Circle()
                            .fill(particleColor(for: index))
                            .frame(width: isIPad ? 10 : (isSmallScreen ? 5 : 7), height: isIPad ? 10 : (isSmallScreen ? 5 : 7))
                            .shadow(color: particleColor(for: index).opacity(0.5), radius: isSmallScreen ? 2 : 4)
                            .offset(y: -(circleSize / 2 + particleOffset))
                            .rotationEffect(.degrees(Double(index) * particleAngle + rotation))
                            .opacity(showRings ? 1 : 0)
                    }
                    
                    // Inner sparkle particles - reverse rotation (hide on small screens)
                    if !isSmallScreen {
                        ForEach(0..<8, id: \.self) { index in
                            let rotation = -time * 24
                            Circle()
                                .fill(Color.white.opacity(0.8))
                                .frame(width: isIPad ? 6 : 4, height: isIPad ? 6 : 4)
                                .offset(y: -(circleSize / 2 - 20))
                                .rotationEffect(.degrees(Double(index) * 45 + rotation))
                                .opacity(showRings ? 0.7 : 0)
                        }
                    }
                    
                    // Main circle with gradient
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.85, blue: 0.5),
                                    Color(red: 0.15, green: 0.7, blue: 0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: circleSize, height: circleSize)
                        .shadow(color: Color.green.opacity(0.5), radius: isSmallScreen ? 15 : 25, x: 0, y: isSmallScreen ? 5 : 10)
                        .scaleEffect(showCheckmark ? 1 : 0)
                        .overlay(
                            // Border glow
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .frame(width: circleSize - 4, height: circleSize - 4)
                                .scaleEffect(showCheckmark ? 1 : 0)
                        )
                    
                    // Glossy overlay
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                        .frame(width: circleSize - 20, height: circleSize - 20)
                        .offset(x: isSmallScreen ? -6 : -10, y: isSmallScreen ? -6 : -10)
                        .scaleEffect(showCheckmark ? 1 : 0)
                    
                    // Shield icon with pulse
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: checkmarkSize, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                        .scaleEffect(showShield ? (1.0 + sin(time * 3) * 0.03) : 0)
                        .opacity(showShield ? 1 : 0)
                }
                
                // Connected text
                VStack(spacing: isIPad ? 16 : (isSmallScreen ? 8 : 12)) {
                    Text("Connected!")
                        .font(isIPad ? .largeTitle : (isSmallScreen ? .title2 : .title))
                        .fontWeight(.bold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color(red: 0.3, green: 0.9, blue: 0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.green.opacity(0.3), radius: 10)
                        .scaleEffect(showText ? 1 : 0.8)
                        .opacity(showText ? 1 : 0)
                    
                    if let server = viewModel.selectedServer {
                        HStack(spacing: isSmallScreen ? 6 : 10) {
                            Text(server.flag)
                                .font(isIPad ? .title : (isSmallScreen ? .title3 : .title2))
                            Text(server.name)
                                .font(isIPad ? .title3 : (isSmallScreen ? .subheadline : .headline))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, isSmallScreen ? 14 : 20)
                        .padding(.vertical, isSmallScreen ? 8 : 10)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                        )
                        .scaleEffect(showText ? 1 : 0.8)
                        .opacity(showText ? 1 : 0)
                    }
                    
                    HStack(spacing: isSmallScreen ? 5 : 8) {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
                            .font(isSmallScreen ? .caption : .body)
                        Text("Your connection is now secure")
                            .font(isIPad ? .body : (isSmallScreen ? .caption : .subheadline))
                            .foregroundColor(.secondary)
                    }
                    .scaleEffect(showText ? 1 : 0.8)
                    .opacity(showText ? 1 : 0)
                }
            }
        }
        .padding(isIPad ? 50 : (isSmallScreen ? 24 : 40))
        .frame(maxWidth: isIPad ? 600 : .infinity)
        .background(BlurCardBackground(cornerRadius: isIPad ? 32 : (isSmallScreen ? 20 : 28)))
        .shadow(color: Color.green.opacity(0.25), radius: isSmallScreen ? 15 : 30, x: 0, y: isSmallScreen ? 8 : 15)
        .padding(.horizontal, isIPad ? 40 : 16)
        .padding(.top, isIPad ? 20 : (isSmallScreen ? 5 : 10))
        .onAppear {
            startCelebrationAnimation()
        }
    }
    
    private func particleColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color.green,
            Color(red: 0.3, green: 0.9, blue: 0.5),
            Color.cyan,
            Color.mint,
            Color.yellow.opacity(0.8)
        ]
        return colors[index % colors.count]
    }
    
    private func startCelebrationAnimation() {
        // Staggered animations for dramatic effect
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            showCheckmark = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showRings = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                showShield = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showText = true
            }
        }
        
        // Haptic feedback
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.success)
    }
}

// MARK: - Disconnecting Celebration View
struct DisconnectingCelebrationView: View {
    @ObservedObject var viewModel: ServerListViewModel
    var isIPad: Bool
    
    @State private var showIcon = false
    @State private var showRings = false
    @State private var showText = false
    
    // Responsive sizes
    private var isSmallScreen: Bool { UIScreen.main.bounds.height < 700 }
    private var circleSize: CGFloat { isIPad ? 200 : (isSmallScreen ? 120 : 160) }
    private var iconSize: CGFloat { isIPad ? 70 : (isSmallScreen ? 40 : 55) }
    
    var body: some View {
        VStack(spacing: isIPad ? 40 : (isSmallScreen ? 16 : 30)) {
            // Animation circle area
            DisconnectAnimationCircle(
                circleSize: circleSize,
                iconSize: iconSize,
                isIPad: isIPad,
                isSmallScreen: isSmallScreen,
                showIcon: showIcon,
                showRings: showRings
            )
            
            // Text content
            DisconnectTextContent(
                viewModel: viewModel,
                isIPad: isIPad,
                isSmallScreen: isSmallScreen,
                showText: showText
            )
        }
        .padding(isIPad ? 50 : (isSmallScreen ? 24 : 40))
        .frame(maxWidth: isIPad ? 600 : .infinity)
        .background(BlurCardBackground(cornerRadius: isIPad ? 32 : (isSmallScreen ? 20 : 28)))
        .shadow(color: Color.orange.opacity(0.25), radius: isSmallScreen ? 15 : 30, x: 0, y: isSmallScreen ? 8 : 15)
        .padding(.horizontal, isIPad ? 40 : 16)
        .padding(.top, isIPad ? 20 : (isSmallScreen ? 5 : 10))
        .onAppear {
            startDisconnectAnimation()
        }
    }
    
    private func startDisconnectAnimation() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            showIcon = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showRings = true
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showText = true
            }
        }
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Disconnect Animation Circle
private struct DisconnectAnimationCircle: View {
    let circleSize: CGFloat
    let iconSize: CGFloat
    let isIPad: Bool
    let isSmallScreen: Bool
    let showIcon: Bool
    let showRings: Bool
    
    private var glowSize: CGFloat { isIPad ? 160 : (isSmallScreen ? 100 : 160) }
    private var ringSpacing: CGFloat { isIPad ? 35 : (isSmallScreen ? 22 : 35) }
    private var particleOffset: CGFloat { isIPad ? 45 : (isSmallScreen ? 30 : 45) }
    private var particleCount: Int { isSmallScreen ? 8 : 12 }
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.02, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            ZStack {
                // Outer glow
                outerGlow(time: time)
                
                // Collapsing rings
                collapsingRings(time: time)
                
                // Decorative rings
                decorativeRings
                
                // Particles
                spinningParticles(time: time)
                if !isSmallScreen {
                    innerParticles(time: time)
                }
                
                // Main button
                mainCircle
                glossyOverlay
                powerIcon(time: time)
            }
        }
    }
    
    private func outerGlow(time: TimeInterval) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color.orange.opacity(0.4), Color.red.opacity(0.2), Color.clear],
                    center: .center,
                    startRadius: circleSize / 2,
                    endRadius: circleSize + 80
                )
            )
            .frame(width: circleSize + glowSize, height: circleSize + glowSize)
            .scaleEffect(1.0 + sin(time * 3) * 0.08)
            .opacity(showRings ? 0.8 : 0)
    }
    
    private func collapsingRings(time: TimeInterval) -> some View {
        ForEach(0..<3, id: \.self) { index in
            let phase = (time + Double(index) * 0.6).truncatingRemainder(dividingBy: 1.8)
            let normalizedPhase = phase / 1.8
            let scale = 1.5 - normalizedPhase * 0.5
            let ringOpacity = normalizedPhase * 0.6
            
            Circle()
                .stroke(Color.orange.opacity(0.5), lineWidth: isIPad ? 3 : 2)
                .frame(width: circleSize, height: circleSize)
                .scaleEffect(showRings ? scale : 1.5)
                .opacity(showRings ? ringOpacity : 0)
        }
    }
    
    private var decorativeRings: some View {
        ForEach(0..<(isSmallScreen ? 3 : 4), id: \.self) { index in
            Circle()
                .stroke(Color.orange.opacity(0.2 - Double(index) * 0.04), lineWidth: isIPad ? 2 : 1.5)
                .frame(width: circleSize + CGFloat(index) * ringSpacing, height: circleSize + CGFloat(index) * ringSpacing)
                .scaleEffect(showRings ? 1 : 1.2)
                .opacity(showRings ? (0.8 - Double(index) * 0.15) : 0)
        }
    }
    
    private func spinningParticles(time: TimeInterval) -> some View {
        let rotation = -time * 60
        let particleAngle = isSmallScreen ? 45.0 : 30.0
        return ForEach(0..<particleCount, id: \.self) { index in
            Circle()
                .fill(particleColor(for: index))
                .frame(width: isIPad ? 10 : (isSmallScreen ? 5 : 7), height: isIPad ? 10 : (isSmallScreen ? 5 : 7))
                .shadow(color: particleColor(for: index).opacity(0.5), radius: isSmallScreen ? 2 : 4)
                .offset(y: -(circleSize / 2 + particleOffset))
                .rotationEffect(.degrees(Double(index) * particleAngle + rotation))
                .opacity(showRings ? 1 : 0)
        }
    }
    
    private func innerParticles(time: TimeInterval) -> some View {
        let rotation = time * 45
        return ForEach(0..<8, id: \.self) { index in
            let pulse = CGFloat(sin(time * 4 + Double(index)) * 5)
            let offsetY = -((circleSize / 2) - 25 + pulse)
            Circle()
                .fill(Color.white.opacity(0.7))
                .frame(width: isIPad ? 5 : 4, height: isIPad ? 5 : 4)
                .offset(y: offsetY)
                .rotationEffect(.degrees(Double(index) * 45 + rotation))
                .opacity(showRings ? 0.8 : 0)
        }
    }
    
    private var mainCircle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color(red: 1.0, green: 0.5, blue: 0.2), Color(red: 0.9, green: 0.3, blue: 0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: circleSize, height: circleSize)
            .shadow(color: Color.orange.opacity(0.5), radius: isSmallScreen ? 15 : 25, x: 0, y: isSmallScreen ? 5 : 10)
            .scaleEffect(showIcon ? 1 : 0)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .frame(width: circleSize - 4, height: circleSize - 4)
                    .scaleEffect(showIcon ? 1 : 0)
            )
    }
    
    private var glossyOverlay: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.white.opacity(0.4), Color.white.opacity(0.15), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
            )
            .frame(width: circleSize - 20, height: circleSize - 20)
            .offset(x: -10, y: -10)
            .scaleEffect(showIcon ? 1 : 0)
    }
    
    private func powerIcon(time: TimeInterval) -> some View {
        Image(systemName: "power")
            .font(.system(size: iconSize, weight: .bold))
            .foregroundColor(.white)
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
            .scaleEffect(showIcon ? (1.0 + sin(time * 6) * 0.05) : 0)
            .rotationEffect(.degrees(sin(time * 8) * 3))
            .opacity(showIcon ? 1 : 0)
    }
    
    private func particleColor(for index: Int) -> Color {
        let colors: [Color] = [.orange, Color(red: 1.0, green: 0.5, blue: 0.3), .red.opacity(0.8), .yellow]
        return colors[index % colors.count]
    }
}

// MARK: - Disconnect Text Content
private struct DisconnectTextContent: View {
    @ObservedObject var viewModel: ServerListViewModel
    let isIPad: Bool
    let isSmallScreen: Bool
    let showText: Bool
    
    var body: some View {
        VStack(spacing: isIPad ? 16 : (isSmallScreen ? 8 : 12)) {
            Text("Disconnecting...")
                .font(isIPad ? .largeTitle : (isSmallScreen ? .title2 : .title))
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange, Color(red: 1.0, green: 0.4, blue: 0.3)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.orange.opacity(0.3), radius: 10)
                .scaleEffect(showText ? 1 : 0.8)
                .opacity(showText ? 1 : 0)
            
            if let server = viewModel.selectedServer {
                serverBadge(server: server)
            }
            
            closingTunnelText
        }
    }
    
    private func serverBadge(server: VPNServer) -> some View {
        HStack(spacing: isSmallScreen ? 6 : 10) {
            Text(server.flag)
                .font(isIPad ? .title : (isSmallScreen ? .title3 : .title2))
            Text(server.name)
                .font(isIPad ? .title3 : (isSmallScreen ? .subheadline : .headline))
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, isSmallScreen ? 14 : 20)
        .padding(.vertical, isSmallScreen ? 8 : 10)
        .background(Capsule().fill(Color.orange.opacity(0.15)))
        .scaleEffect(showText ? 1 : 0.8)
        .opacity(showText ? 1 : 0)
    }
    
    private var closingTunnelText: some View {
        HStack(spacing: isSmallScreen ? 5 : 8) {
            Image(systemName: "wifi.slash")
                .foregroundColor(.orange)
                .font(isSmallScreen ? .caption : .body)
            Text("Closing secure tunnel...")
                .font(isIPad ? .body : (isSmallScreen ? .caption : .subheadline))
                .foregroundColor(.secondary)
        }
        .scaleEffect(showText ? 1 : 0.8)
        .opacity(showText ? 1 : 0)
    }
}

// MARK: - Connection Status Card
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
                            if !viewModel.isNetworkAvailable && !viewModel.isConnected() {
                                Text("\(server.name)")
                                    .font(isIPad ? .body : .subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(server.name) - Ready to connect")
                                    .font(isIPad ? .body : .subheadline)
                                    .foregroundColor(.secondary)
                            }
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
            .disabled(isButtonDisabled)
            .opacity(isButtonDisabled ? 0.6 : 1.0)
            
            // No internet warning
//            if !viewModel.isNetworkAvailable && !viewModel.isConnected() {
//                HStack(spacing: 6) {
//                    Image(systemName: "wifi.slash")
//                        .font(.caption)
//                    Text("No internet connection")
//                        .font(isIPad ? .subheadline : .caption)
//                }
//                .foregroundColor(.red)
//                .padding(.top, 4)
//            }
        }
        .padding(cardPadding)
        .background(BlurCardBackground(cornerRadius: isIPad ? 24 : 20))
        .shadow(color: Color.black.opacity(0.1), radius: isIPad ? 15 : 10, x: 0, y: 5)
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
        } else if !viewModel.isNetworkAvailable {
            return "No Internet"
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
        } else if !viewModel.isNetworkAvailable {
            return Color.gray
        } else {
            return Color.green
        }
    }
    
    /// Check if button should be disabled
    private var isButtonDisabled: Bool {
        // Disable if connection in progress
        if viewModel.isConnectionInProgress() {
            return true
        }
        // Disable if no server selected and not connected
        if viewModel.selectedServer == nil && !viewModel.isConnected() {
            return true
        }
        // Disable connect button if no network (but allow disconnect)
        if !viewModel.isNetworkAvailable && !viewModel.isConnected() {
            return true
        }
        return false
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
            .background(BlurCardBackground(cornerRadius: cornerRadius))
            .opacity(isListDisabled && !isConnected ? 0.6 : 1.0)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isSelected ? Color.cyan : Color.clear,
                        lineWidth: isIPad ? 3 : 2
                    )
            )
            .shadow(color: isSelected ? Color.cyan.opacity(0.3) : Color.clear, radius: 8)
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
                
//                Section(header: Text("DNS Settings").font(isIPad ? .headline : .subheadline)) {
//                    Toggle(isOn: $viewModel.profile.customDNSEnabled) {
//                        Text("Use Custom DNS")
//                            .font(isIPad ? .body : .callout)
//                    }
//                    .padding(.vertical, isIPad ? 4 : 0)
//                    
//                    if viewModel.profile.customDNSEnabled {
//                        ForEach(0..<viewModel.profile.dnsList.count, id: \.self) { index in
//                            TextField("DNS Address", text: Binding(
//                                get: {
//                                    index < viewModel.profile.dnsList.count ? viewModel.profile.dnsList[index] : ""
//                                },
//                                set: {
//                                    if index < viewModel.profile.dnsList.count {
//                                        viewModel.profile.dnsList[index] = $0
//                                    }
//                                }
//                            ))
//                            .font(isIPad ? .body : .callout)
//                            .padding(.vertical, isIPad ? 4 : 0)
//                        }
//                        
//                        Button(action: {
//                            viewModel.profile.dnsList.append("")
//                        }) {
//                            HStack {
//                                Image(systemName: "plus.circle.fill")
//                                    .font(isIPad ? .title3 : .body)
//                                Text("Add DNS Server")
//                                    .font(isIPad ? .body : .callout)
//                            }
//                        }
//                        .padding(.vertical, isIPad ? 4 : 0)
//                    }
//                }
                
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
            .background(BlurCardBackground(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.cyan : Color.clear, lineWidth: 1.5)
            )
            .shadow(color: isFocused ? Color.cyan.opacity(0.2) : Color.clear, radius: 5)
            
            // Cancel button when focused
            if isFocused {
                Button("Cancel") {
                    text = ""
                    isFocused = false
                }
                .font(.body)
                .foregroundColor(.cyan)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
}

// MARK: - Connected State View
struct ConnectedStateView: View {
    @ObservedObject var viewModel: ServerListViewModel
    var isIPad: Bool
    var horizontalPadding: CGFloat
    @Binding var showBrowser: Bool
    
    @State private var appearAnimation = false
    
    var body: some View {
        VStack(spacing: isIPad ? 30 : 20) {
            // Connected: Show Connection Details with Speed Gauge
            ConnectionDetailsCard(viewModel: viewModel, isIPad: isIPad)
                .frame(maxWidth: isIPad ? 700 : .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, isIPad ? 20 : 10)
                .scaleEffect(appearAnimation ? 1 : 0.95)
                .opacity(appearAnimation ? 1 : 0)
            
            // Action Buttons
            HStack(spacing: isIPad ? 16 : 12) {
                // Browser Button
                Button(action: {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
                    showBrowser = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "safari.fill")
                        Text("Browse")
                    }
                    .font(isIPad ? .title3 : .headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isIPad ? 18 : 16)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.cyan.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(isIPad ? 16 : 12)
                    .shadow(color: Color.cyan.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                
                // Disconnect Button
                Button(action: {
                    // Haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    
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
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, isIPad ? 18 : 16)
                    .background(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(isIPad ? 16 : 12)
                    .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, isIPad ? 40 : 30)
            .scaleEffect(appearAnimation ? 1 : 0.95)
            .opacity(appearAnimation ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1)) {
                appearAnimation = true
            }
        }
        .onDisappear {
            appearAnimation = false
        }
    }
}

// MARK: - Disconnected State View
struct DisconnectedStateView: View {
    @ObservedObject var viewModel: ServerListViewModel
    var isIPad: Bool
    var horizontalPadding: CGFloat
    var contentMaxWidth: CGFloat
    var gridColumns: [GridItem]
    var handleServerTap: (VPNServer) -> Void
    
    @State private var appearAnimation = false
    
    var body: some View {
        VStack(spacing: isIPad ? 20 : 16) {
            // Animated Status Card with VPN Toggle
            AnimatedConnectionStatusCard(viewModel: viewModel, isIPad: isIPad)
                .frame(maxWidth: isIPad ? 600 : .infinity)
                .padding(.horizontal, horizontalPadding)
                .padding(.top, isIPad ? 20 : 10)
                .scaleEffect(appearAnimation ? 1 : 0.95)
                .opacity(appearAnimation ? 1 : 0)
            
            // IP Checker
            MiniIPChecker(isIPad: isIPad)
                .frame(maxWidth: isIPad ? 600 : .infinity)
                .padding(.horizontal, horizontalPadding)
                .scaleEffect(appearAnimation ? 1 : 0.95)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appearAnimation)
            
            // Search Bar
            SearchBar(text: $viewModel.searchText, isDisabled: viewModel.isConnectionInProgress())
                .frame(maxWidth: isIPad ? 600 : .infinity)
                .padding(.horizontal, horizontalPadding)
                .scaleEffect(appearAnimation ? 1 : 0.95)
                .opacity(appearAnimation ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15), value: appearAnimation)
            
            // Server List Section
            VStack(alignment: .leading, spacing: isIPad ? 16 : 12) {
                HStack {
                    Text("Available Servers")
                        .font(isIPad ? .title3 : .headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if viewModel.isLoadingServers {
                        ProgressView()
                            .scaleEffect(isIPad ? 0.8 : 0.7)
                    } else {
                    Text("\(viewModel.filteredServers.count) servers")
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, horizontalPadding)
                
                // Show error message if server loading failed
                if let error = viewModel.serverLoadError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(isIPad ? .body : .caption)
                        Text(error)
                            .font(isIPad ? .subheadline : .caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Retry") {
                            viewModel.fetchServersFromAPI()
                        }
                        .font(isIPad ? .subheadline : .caption)
                        .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, isIPad ? 8 : 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, horizontalPadding)
                }
                
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
                        ForEach(Array(viewModel.filteredServers.enumerated()), id: \.element.id) { index, server in
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
                            .scaleEffect(appearAnimation ? 1 : 0.9)
                            .opacity(appearAnimation ? 1 : 0)
                            .animation(
                                .spring(response: 0.4, dampingFraction: 0.7)
                                    .delay(0.2 + Double(index) * 0.03),
                                value: appearAnimation
                            )
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
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                appearAnimation = true
            }
        }
        .onDisappear {
            appearAnimation = false
        }
    }
}

struct ServerListView_Previews: PreviewProvider {
    static var previews: some View {
        ServerListView()
    }
}
