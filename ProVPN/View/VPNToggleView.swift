//
//  VPNToggleView.swift
//  ProVPN
//
//  Created by DREAMWORLD on 24/11/25.
//

import SwiftUI
import NetworkExtension

/// Premium animated VPN toggle button with continuous animations
struct VPNToggleView: View {
    @ObservedObject var viewModel: ServerListViewModel
    var isIPad: Bool = false
    
    @State private var outerPulse = false
    @State private var glowOpacity: Double = 0.5
    @State private var buttonScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0
    
    // Responsive sizes
    private var outerRingSize: CGFloat { isIPad ? 220 : 180 }
    private var middleRingSize: CGFloat { isIPad ? 190 : 155 }
    private var buttonSize: CGFloat { isIPad ? 160 : 130 }
    private var iconSize: CGFloat { isIPad ? 55 : 45 }
    
    var body: some View {
        // Use TimelineView for continuous animation during scroll
        TimelineView(.animation(minimumInterval: 0.016, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            ZStack {
                // Outer glow effect
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                statusColor.opacity(0.3),
                                statusColor.opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: buttonSize / 2,
                            endRadius: outerRingSize
                        )
                    )
                    .frame(width: outerRingSize + 80, height: outerRingSize + 80)
                    .blur(radius: 20)
                    .opacity(0.5 + sin(time * 2) * 0.2)
                
                // Animated pulse rings
                if viewModel.isConnectionInProgress() || viewModel.isConnected() {
                    PulseRingsView(
                        size: outerRingSize,
                        color: statusColor,
                        isConnected: viewModel.isConnected(),
                        lineWidth: isIPad ? 3 : 2
                    )
                }
                
                // Outer decorative ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                statusColor.opacity(0.3),
                                statusColor.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isIPad ? 2 : 1.5
                    )
                    .frame(width: outerRingSize, height: outerRingSize)
                
                // Middle progress ring background
                Circle()
                    .stroke(
                        Color.gray.opacity(0.15),
                        lineWidth: isIPad ? 10 : 8
                    )
                    .frame(width: middleRingSize, height: middleRingSize)
                
                // Animated progress ring - continuous rotation when connecting
                ProgressRingView(
                    size: middleRingSize,
                    lineWidth: isIPad ? 10 : 8,
                    color: statusColor,
                    isConnecting: viewModel.isConnectionInProgress(),
                    isConnected: viewModel.isConnected(),
                    time: time
                )
                
                // Rotating particles when connecting
                if viewModel.isConnectionInProgress() {
                    RotatingParticlesView(
                        size: middleRingSize,
                        particleSize: isIPad ? 10 : 8,
                        color: statusColor,
                        time: time
                    )
                }
                
                // Main button
                Button(action: handleTap) {
                    ZStack {
                        // Button shadow layer
                        Circle()
                            .fill(statusColor.opacity(0.3))
                            .frame(width: buttonSize, height: buttonSize)
                            .blur(radius: 15)
                            .offset(y: 5)
                        
                        // Main button background
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: buttonGradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: buttonSize, height: buttonSize)
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.3),
                                                Color.white.opacity(0.1),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .center
                                        )
                                    )
                                    .frame(width: buttonSize - 20, height: buttonSize - 20)
                                    .offset(x: -10, y: -10)
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.4),
                                                Color.white.opacity(0.1)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                                    .frame(width: buttonSize - 10, height: buttonSize - 10)
                            )
                        
                        // Icon and text
                        VStack(spacing: isIPad ? 8 : 6) {
                            Image(systemName: statusIcon)
                                .font(.system(size: iconSize, weight: .semibold))
                                .foregroundColor(.white)
                                .rotationEffect(.degrees(viewModel.isConnectionInProgress() ? time.truncatingRemainder(dividingBy: 1) * 360 : iconRotation))
                                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 2)
                            
                            if !viewModel.isConnectionInProgress() {
                                Text(viewModel.isConnected() ? "TAP TO\nDISCONNECT" : "TAP TO\nCONNECT")
                                    .font(.system(size: isIPad ? 11 : 9, weight: .bold))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineSpacing(2)
                            } else {
                                Text("CONNECTING")
                                    .font(.system(size: isIPad ? 11 : 9, weight: .bold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                    .scaleEffect(buttonScale)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canInteract)
            }
        }
        .frame(width: outerRingSize + 100, height: outerRingSize + 100)
        .onChange(of: viewModel.connection.connectionStatus) { newStatus in
            handleStatusChange(newStatus)
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch viewModel.connection.connectionStatus {
        case .connected:
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .connecting, .reasserting:
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .disconnecting:
            return Color(red: 1.0, green: 0.8, blue: 0.2)
        default:
            return Color(red: 0.4, green: 0.45, blue: 0.55)
        }
    }
    
    private var statusIcon: String {
        switch viewModel.connection.connectionStatus {
        case .connected:
            return "power"
        case .connecting, .reasserting:
            return "arrow.triangle.2.circlepath"
        case .disconnecting:
            return "xmark"
        default:
            return "power"
        }
    }
    
    private var buttonGradientColors: [Color] {
        switch viewModel.connection.connectionStatus {
        case .connected:
            return [
                Color(red: 0.15, green: 0.75, blue: 0.45),
                Color(red: 0.1, green: 0.6, blue: 0.35)
            ]
        case .connecting, .reasserting:
            return [
                Color(red: 1.0, green: 0.55, blue: 0.15),
                Color(red: 0.9, green: 0.4, blue: 0.1)
            ]
        case .disconnecting:
            return [
                Color(red: 1.0, green: 0.75, blue: 0.2),
                Color(red: 0.9, green: 0.65, blue: 0.15)
            ]
        default:
            return [
                Color(red: 0.35, green: 0.4, blue: 0.5),
                Color(red: 0.25, green: 0.3, blue: 0.4)
            ]
        }
    }
    
    private var canInteract: Bool {
        !viewModel.isConnectionInProgress() && 
        (viewModel.selectedServer != nil || viewModel.isConnected()) &&
        viewModel.isNetworkAvailable
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            buttonScale = 0.9
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                buttonScale = 1.0
            }
        }
        
        if viewModel.isConnected() {
            ConnectionDetailsCard.clearConnectionStartTime()
            viewModel.disconnect()
        } else if viewModel.selectedServer != nil {
            ConnectionDetailsCard.clearConnectionStartTime()
            viewModel.connect()
        }
    }
    
    private func handleStatusChange(_ status: NEVPNStatus) {
        switch status {
        case .connected:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                buttonScale = 1.15
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    buttonScale = 1.0
                }
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.4)) {
                iconRotation = 360
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                iconRotation = 0
            }
            
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
            
        case .disconnected:
            withAnimation(.easeOut(duration: 0.3)) {
                buttonScale = 1.0
            }
            
        default:
            break
        }
    }
}

// MARK: - Pulse Rings View (Continuous Animation)
struct PulseRingsView: View {
    let size: CGFloat
    let color: Color
    let isConnected: Bool
    let lineWidth: CGFloat
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016, paused: false)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let phase = (time + Double(index) * 0.5).truncatingRemainder(dividingBy: isConnected ? 2.5 : 1.5)
                    let normalizedPhase = phase / (isConnected ? 2.5 : 1.5)
                    let scale = 1.0 + normalizedPhase * 0.5
                    let opacity = max(0, 0.6 - normalizedPhase * 0.8)
                    
                    Circle()
                        .stroke(color.opacity(0.4 - Double(index) * 0.1), lineWidth: lineWidth)
                        .frame(width: size, height: size)
                        .scaleEffect(scale)
                        .opacity(opacity)
                }
            }
        }
    }
}

// MARK: - Progress Ring View (Continuous Animation)
struct ProgressRingView: View {
    let size: CGFloat
    let lineWidth: CGFloat
    let color: Color
    let isConnecting: Bool
    let isConnected: Bool
    let time: TimeInterval
    
    var body: some View {
        let progress: CGFloat = isConnected ? 1.0 : (isConnecting ? CGFloat(time.truncatingRemainder(dividingBy: 2) / 2) : 0)
        let rotation: Double = isConnecting ? time * 120 : 0
        
        Circle()
            .trim(from: 0, to: progress)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0.3),
                        color.opacity(0.6),
                        color,
                        color.opacity(0.6),
                        color.opacity(0.3)
                    ]),
                    center: .center,
                    startAngle: .degrees(0),
                    endAngle: .degrees(360)
                ),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(-90 + rotation))
            .shadow(color: color.opacity(0.5), radius: 5)
    }
}

// MARK: - Rotating Particles View (Continuous Animation)
struct RotatingParticlesView: View {
    let size: CGFloat
    let particleSize: CGFloat
    let color: Color
    let time: TimeInterval
    
    var body: some View {
        let rotation = time * 180 // degrees per second
        
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(color.opacity(Double(index + 1) / 12.0))
                    .frame(width: particleSize, height: particleSize)
                    .offset(y: -(size / 2 + 20))
                    .rotationEffect(.degrees(Double(index) * 30 + rotation))
            }
        }
    }
}

// MARK: - Premium Connection Status Card
struct AnimatedConnectionStatusCard: View {
    @ObservedObject var viewModel: ServerListViewModel
    var isIPad: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    private var cardPadding: CGFloat { isIPad ? 40 : 28 }
    
    var body: some View {
        VStack(spacing: isIPad ? 28 : 20) {
            // VPN Toggle Button
            VPNToggleView(viewModel: viewModel, isIPad: isIPad)
                .padding(.top, isIPad ? 10 : 5)
            
            // Status Text
            VStack(spacing: isIPad ? 12 : 8) {
                Text(viewModel.statusText())
                    .font(isIPad ? .largeTitle : .title)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: statusGradientColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                if let server = viewModel.selectedServer {
                    HStack(spacing: 10) {
                        Text(server.flag)
                            .font(isIPad ? .largeTitle : .title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(server.name)
                                .font(isIPad ? .title3 : .headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(viewModel.isConnected() ? "Connected securely" : "Ready to connect")
                                .font(isIPad ? .body : .subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, isIPad ? 24 : 16)
                    .padding(.vertical, isIPad ? 14 : 10)
                    .background(
                        RoundedRectangle(cornerRadius: isIPad ? 16 : 12)
                            .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    )
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "server.rack")
                            .foregroundColor(.secondary)
                        Text("Select a server from the list below")
                            .font(isIPad ? .body : .subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Network status warning
            if !viewModel.isNetworkAvailable {
                HStack(spacing: 8) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(isIPad ? .body : .subheadline)
                    Text("No internet connection")
                        .font(isIPad ? .body : .subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, isIPad ? 20 : 16)
                .padding(.vertical, isIPad ? 12 : 10)
                .background(
                    Capsule()
                        .fill(Color.red.opacity(0.9))
                )
            }
        }
        .padding(cardPadding)
        .frame(maxWidth: isIPad ? 500 : .infinity)
        .background(BlurCardBackground(cornerRadius: isIPad ? 28 : 24))
        .shadow(color: Color.black.opacity(0.15), radius: isIPad ? 20 : 15, x: 0, y: 8)
    }
    
    private var statusGradientColors: [Color] {
        switch viewModel.connection.connectionStatus {
        case .connected:
            return [Color.green, Color.green.opacity(0.8)]
        case .connecting, .reasserting:
            return [Color.orange, Color.orange.opacity(0.8)]
        default:
            return [Color.primary, Color.primary.opacity(0.8)]
        }
    }
}

#Preview {
    ZStack {
        AnimatedBackground()
        VStack {
            AnimatedConnectionStatusCard(viewModel: ServerListViewModel(), isIPad: false)
                .padding()
        }
    }
}
