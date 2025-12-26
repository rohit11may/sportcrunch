//
//  AnimatedBackground.swift
//  SportCrunch
//
//  Created by Rohit Prasad on 26/12/2025.
//

import SwiftUI

// MARK: - Mesh Gradient Background

struct MeshGradientBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base color
            Color.scBackground
            
            // Animated blobs
            GeometryReader { geometry in
                ZStack {
                    // Primary blob
                    Circle()
                        .fill(Color.scGradientStart.opacity(0.15))
                        .blur(radius: 80)
                        .frame(width: 300, height: 300)
                        .offset(
                            x: animate ? 50 : -50,
                            y: animate ? -100 : 100
                        )
                    
                    // Secondary blob
                    Circle()
                        .fill(Color.scGradientEnd.opacity(0.1))
                        .blur(radius: 100)
                        .frame(width: 400, height: 400)
                        .offset(
                            x: animate ? -80 : 80,
                            y: animate ? 150 : -50
                        )
                    
                    // Accent blob
                    Circle()
                        .fill(Color.scTennis.opacity(0.08))
                        .blur(radius: 60)
                        .frame(width: 200, height: 200)
                        .offset(
                            x: animate ? 120 : -120,
                            y: animate ? -50 : 200
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

// MARK: - Sport Themed Background

struct SportThemedBackground: View {
    let sport: Sport
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.scBackground
            
            GeometryReader { geometry in
                ZStack {
                    Circle()
                        .fill(sport.accentColor.opacity(0.2))
                        .blur(radius: 100)
                        .frame(width: 400, height: 400)
                        .offset(
                            x: animate ? 50 : -50,
                            y: animate ? -150 : 50
                        )
                    
                    Circle()
                        .fill(sport.accentColor.opacity(0.1))
                        .blur(radius: 80)
                        .frame(width: 300, height: 300)
                        .offset(
                            x: animate ? -100 : 100,
                            y: animate ? 200 : 100
                        )
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(
                .easeInOut(duration: 6)
                .repeatForever(autoreverses: true)
            ) {
                animate = true
            }
        }
    }
}

// MARK: - Processing Animation

struct ProcessingAnimation: View {
    let sport: Sport
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(
                    sport.accentColor.opacity(0.2),
                    lineWidth: 4
                )
                .frame(width: 120, height: 120)
            
            // Animated arc
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(
                    sport.gradient,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(rotation))
            
            // Inner pulsing circle
            Circle()
                .fill(sport.gradient)
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
            
            // Sport emoji
            Text(sport.emoji)
                .font(.system(size: 28))
        }
        .onAppear {
            withAnimation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
            ) {
                rotation = 360
            }
            
            withAnimation(
                .easeInOut(duration: 1)
                .repeatForever(autoreverses: true)
            ) {
                scale = 1.15
            }
        }
    }
}

// MARK: - Success Animation

struct SuccessAnimation: View {
    @State private var showCheck = false
    @State private var showRing = false
    @State private var showConfetti = false
    
    var body: some View {
        ZStack {
            // Confetti particles
            if showConfetti {
                ConfettiView()
            }
            
            // Success ring
            Circle()
                .stroke(Color.scSuccess, lineWidth: 4)
                .frame(width: 100, height: 100)
                .scaleEffect(showRing ? 1 : 0)
                .opacity(showRing ? 1 : 0)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(Color.scSuccess)
                .scaleEffect(showCheck ? 1 : 0)
                .opacity(showCheck ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.1)) {
                showRing = true
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.3)) {
                showCheck = true
            }
            withAnimation(.easeOut(duration: 0.3).delay(0.5)) {
                showConfetti = true
            }
        }
    }
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .offset(x: particle.x, y: particle.y)
                        .opacity(particle.opacity)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                generateParticles(in: geometry.size)
            }
        }
    }
    
    private func generateParticles(in size: CGSize) {
        let colors: [Color] = [.scSuccess, .scTennis, .scGradientStart, .scGradientEnd, .scCricket]
        
        for i in 0..<30 {
            var particle = ConfettiParticle(
                id: i,
                x: CGFloat.random(in: -size.width/2...size.width/2),
                y: 0,
                size: CGFloat.random(in: 4...8),
                color: colors.randomElement()!,
                opacity: 1
            )
            
            particles.append(particle)
            
            // Animate each particle
            let delay = Double.random(in: 0...0.3)
            let endY = CGFloat.random(in: 100...200)
            let endX = particle.x + CGFloat.random(in: -50...50)
            
            withAnimation(.easeOut(duration: 1.5).delay(delay)) {
                if let index = particles.firstIndex(where: { $0.id == i }) {
                    particles[index].y = endY
                    particles[index].x = endX
                    particles[index].opacity = 0
                }
            }
        }
    }
}

struct ConfettiParticle: Identifiable {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}

// MARK: - Previews

#Preview("Mesh Background") {
    MeshGradientBackground()
}

#Preview("Processing Animation") {
    ProcessingAnimation(sport: .tennis)
        .frame(width: 200, height: 200)
        .background(Color.scBackground)
}

#Preview("Success Animation") {
    SuccessAnimation()
        .frame(width: 200, height: 200)
        .background(Color.scBackground)
}

