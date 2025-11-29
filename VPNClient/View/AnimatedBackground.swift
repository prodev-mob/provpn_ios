//
//  AnimatedBackground.swift
//  VPNClient
//
//  Created by DREAMWORLD on 24/11/25.
//

import SwiftUI

/// VPN-themed animated background with network particles - Performance Optimized
struct AnimatedBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient background
                backgroundGradient
                
                // Static network grid (no animation for better performance)
                StaticGridView()
                    .opacity(colorScheme == .dark ? 0.2 : 0.1)
                
                // Optimized floating particles
                OptimizedParticlesView(size: geometry.size)
                    .drawingGroup() // GPU accelerated rendering
                
                // Glowing orbs with reduced complexity
                SimpleGlowingOrbsView()
                    .opacity(colorScheme == .dark ? 0.5 : 0.3)
                
                // Top gradient overlay for better text readability
                VStack {
                    LinearGradient(
                        colors: [
                            backgroundColor.opacity(0.95),
                            backgroundColor.opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 120)
                    
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark ? [
                Color(red: 0.05, green: 0.08, blue: 0.15),
                Color(red: 0.08, green: 0.12, blue: 0.22),
                Color(red: 0.06, green: 0.10, blue: 0.18)
            ] : [
                Color(red: 0.94, green: 0.96, blue: 0.98),
                Color(red: 0.88, green: 0.92, blue: 0.98),
                Color(red: 0.92, green: 0.95, blue: 0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark 
            ? Color(red: 0.05, green: 0.08, blue: 0.15)
            : Color(red: 0.94, green: 0.96, blue: 0.98)
    }
}

/// Static network grid pattern - No animation for performance
struct StaticGridView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 50
            let lineColor = colorScheme == .dark 
                ? Color.cyan.opacity(0.15) 
                : Color.blue.opacity(0.1)
            
            // Draw vertical lines
            for x in stride(from: 0, through: size.width, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            
            // Draw horizontal lines
            for y in stride(from: 0, through: size.height, by: gridSize) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
    }
}

/// Optimized floating network particles - Reduced count and update frequency
struct OptimizedParticlesView: View {
    let size: CGSize
    @State private var particles: [OptimizedParticle] = []
    @State private var animationTrigger = false
    @Environment(\.colorScheme) var colorScheme
    
    private let particleCount = 12 // Reduced from 20
    private let updateInterval: TimeInterval = 1/20 // Reduced from 1/30
    
    var body: some View {
        Canvas { context, canvasSize in
            let particleColor = colorScheme == .dark 
                ? Color.cyan
                : Color.blue
            
            // Draw particles
            for particle in particles {
                let rect = CGRect(
                    x: particle.x - particle.size/2,
                    y: particle.y - particle.size/2,
                    width: particle.size,
                    height: particle.size
                )
                context.fill(
                    Circle().path(in: rect), 
                    with: .color(particleColor.opacity(particle.opacity))
                )
            }
            
            // Draw connections (optimized - only check nearby particles)
            drawConnections(context: context, particleColor: particleColor)
        }
        .onAppear {
            initializeParticles()
            startAnimation()
        }
    }
    
    private func drawConnections(context: GraphicsContext, particleColor: Color) {
        let maxDistance: CGFloat = 100
        
        for i in 0..<particles.count {
            // Only check next few particles to reduce O(n²) complexity
            for j in (i+1)..<min(i+4, particles.count) {
                let dx = particles[i].x - particles[j].x
                let dy = particles[i].y - particles[j].y
                let distanceSquared = dx*dx + dy*dy
                
                if distanceSquared < maxDistance * maxDistance {
                    let distance = sqrt(distanceSquared)
                    var path = Path()
                    path.move(to: CGPoint(x: particles[i].x, y: particles[i].y))
                    path.addLine(to: CGPoint(x: particles[j].x, y: particles[j].y))
                    
                    let opacity = (1 - distance/maxDistance) * 0.2
                    context.stroke(path, with: .color(particleColor.opacity(opacity)), lineWidth: 0.5)
                }
            }
        }
    }
    
    private func initializeParticles() {
        particles = (0..<particleCount).map { _ in
            OptimizedParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 3...5),
                speedX: CGFloat.random(in: -0.2...0.2),
                speedY: CGFloat.random(in: -0.2...0.2),
                opacity: Double.random(in: 0.3...0.6)
            )
        }
    }
    
    private func startAnimation() {
        // Use a timer with longer interval for better performance
        Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            updateParticles()
        }
    }
    
    private func updateParticles() {
        for i in 0..<particles.count {
            particles[i].x += particles[i].speedX
            particles[i].y += particles[i].speedY
            
            // Wrap around edges
            if particles[i].x < 0 { particles[i].x = size.width }
            if particles[i].x > size.width { particles[i].x = 0 }
            if particles[i].y < 0 { particles[i].y = size.height }
            if particles[i].y > size.height { particles[i].y = 0 }
        }
    }
}

/// Optimized particle model
struct OptimizedParticle {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var speedX: CGFloat
    var speedY: CGFloat
    var opacity: Double
}

/// Simplified glowing orbs - Reduced animations
struct SimpleGlowingOrbsView: View {
    @State private var animate = false
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Large background orb 1
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (colorScheme == .dark ? Color.cyan : Color.blue).opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(x: -geometry.size.width/3, y: -geometry.size.height/4)
                    .offset(x: animate ? 20 : 0, y: animate ? -10 : 10)
                    .blur(radius: 40)
                
                // Large background orb 2
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (colorScheme == .dark ? Color.purple : Color.indigo).opacity(0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: geometry.size.width/3, y: geometry.size.height/5)
                    .offset(x: animate ? -15 : 10, y: animate ? 15 : -10)
                    .blur(radius: 35)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Glass Card Modifier
struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Frosted glass effect
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            colorScheme == .dark
                                ? Color.white.opacity(0.08)
                                : Color.white.opacity(0.7)
                        )
                    
                    // Subtle border
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            colorScheme == .dark
                                ? Color.white.opacity(0.1)
                                : Color.white.opacity(0.5),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.1),
                    radius: 15,
                    x: 0,
                    y: 8
                )
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Blur Card Background
struct BlurCardBackground: View {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat = 16
    
    var body: some View {
        ZStack {
            // Base blur layer - using solid color instead of material for better performance
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    colorScheme == .dark
                        ? Color(red: 0.1, green: 0.12, blue: 0.18).opacity(0.9)
                        : Color.white.opacity(0.85)
                )
            
            // Gradient overlay
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color.white.opacity(0.05), Color.clear]
                            : [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Border
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    colorScheme == .dark
                        ? Color.white.opacity(0.1)
                        : Color.white.opacity(0.5),
                    lineWidth: 0.5
                )
        }
    }
}

// MARK: - Preview
#Preview {
    AnimatedBackground()
}
