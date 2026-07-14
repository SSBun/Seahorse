#if os(macOS)
//
//  ParsingFireEffect.swift
//  Seahorse
//
//  Animated fire/sparkle overlay for cards being AI-parsed.
//

import SwiftUI

// MARK: - Particle

private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
    var speed: CGFloat
    var angle: Double
    var hue: Double
    var phase: Double
}

// MARK: - Fire Particle View

struct ParsingFireEffect: View {
    var body: some View {
        GeometryReader { geo in
            FireParticleCanvas(size: geo.size)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
    }
}

// MARK: - Fire Canvas

private struct FireParticleCanvas: View {
    let size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [Particle] = []
    @State private var startTime = Date()
    @State private var lastUpdate = Date()
    @State private var glowPhase: CGFloat = 0

    private let particleCount = 28
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Dark inner shadow base
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.25))

            // Fire inner glow at bottom
            fireGlow

            // Particles
            Canvas { context, _ in
                for p in particles {
                    let rect = CGRect(
                        x: p.x - p.size / 2,
                        y: p.y - p.size / 2,
                        width: p.size,
                        height: p.size
                    )

                    // Core
                    context.opacity = p.opacity
                    let color = Color(
                        hue: p.hue,
                        saturation: 0.8,
                        brightness: 1.0
                    )
                    context.fill(
                        Circle().path(in: rect),
                        with: .color(color)
                    )

                    // Glow halo
                    context.opacity = p.opacity * 0.3
                    let glowRect = rect.insetBy(dx: -p.size * 0.6, dy: -p.size * 0.6)
                    context.fill(
                        Circle().path(in: glowRect),
                        with: .color(color.opacity(0.4))
                    )
                }
            }

            // Inner shadow border (fire-tinted)
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.6),
                            Color.red.opacity(0.3),
                            Color.orange.opacity(0.5),
                            Color.yellow.opacity(0.4),
                            Color.orange.opacity(0.6)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
                .blur(radius: 2)

            // Center label
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .orange.opacity(0.8), radius: 4)
                Text("AI Parsing...")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .orange, radius: 2)
            }
        }
        .onAppear {
            startTime = Date()
            lastUpdate = startTime
            initializeParticles()
        }
        .onReceive(timer) { _ in
            if !reduceMotion {
                updateParticles()
            }
        }
    }

    // MARK: - Fire Glow

    private var fireGlow: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: Color.orange.opacity(0.15), location: 0.3),
                            .init(color: Color.orange.opacity(0.3 * glowPhase), location: 0.7),
                            .init(color: Color.yellow.opacity(0.2 * glowPhase), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: size.height * 0.6)
                .blur(radius: 8)
        }
    }

    // MARK: - Particle Lifecycle

    private func initializeParticles() {
        particles = (0..<particleCount).map { _ in
            createParticle(born: true)
        }
    }

    private func createParticle(born: Bool = false) -> Particle {
        let y: CGFloat
        if born {
            y = CGFloat.random(in: 0...size.height)
        } else {
            // Spawn from bottom edge
            y = size.height + CGFloat.random(in: 0...20)
        }
        return Particle(
            x: CGFloat.random(in: 0...size.width),
            y: y,
            size: CGFloat.random(in: 2...6),
            opacity: 0,
            speed: CGFloat.random(in: 20...60),
            angle: .pi / 2 + Double.random(in: -0.3...0.3), // mostly upward
            hue: Double.random(in: 0.02...0.13), // red-orange-yellow range
            phase: Double.random(in: 0...(.pi * 2))
        )
    }

    private func updateParticles() {
        let now = Date()
        let elapsed = now.timeIntervalSince(startTime)
        let dt = CGFloat(min(max(now.timeIntervalSince(lastUpdate), 0), 0.1))
        lastUpdate = now
        glowPhase = (sin(elapsed * 3) + 1) / 2

        for i in particles.indices {
            let p = particles[i]

            // Move upward with slight drift
            let dx = cos(p.angle) * p.speed * dt + CGFloat(sin(p.phase + elapsed * 2)) * 0.5
            let dy = -p.speed * dt
            particles[i].x += dx
            particles[i].y += dy

            // Fade in then out based on height
            let progress = 1 - (particles[i].y / size.height)
            if progress < 0.2 {
                particles[i].opacity = Double(progress / 0.2) * 0.8
            } else if progress > 0.7 {
                particles[i].opacity = Double((1 - progress) / 0.3) * 0.8
            } else {
                particles[i].opacity = 0.8
            }

            // Shrink as it rises
            particles[i].size = max(1, particles[i].size - dt)

            // Shift hue toward yellow as it rises
            particles[i].hue = min(0.16, particles[i].hue + Double(dt) * 0.01)
        }

        // Respawn dead particles
        for i in particles.indices {
            if particles[i].y < -10 || particles[i].size < 1 {
                particles[i] = createParticle()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        ParsingFireEffect()
            .frame(width: 280, height: 210)
            .cornerRadius(12)
    }
    .frame(width: 320, height: 260)
}

#endif
