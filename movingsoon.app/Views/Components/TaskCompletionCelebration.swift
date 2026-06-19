// TaskCompletionCelebration.swift — Micro-celebration overlay for task completion
import SwiftUI

// MARK: - Confetti Particle

private struct Particle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let color: Color
    let size: CGFloat
    let rotation: Double
    let xVelocity: CGFloat
    let yVelocity: CGFloat
}

// MARK: - Celebration View

struct TaskCompletionCelebration: View {
    let taskTitle: String
    let isVisible: Bool
    let onDismiss: () -> Void

    @State private var particles: [Particle] = []
    @State private var animating = false
    @State private var checkScale: CGFloat = 0
    @State private var textOpacity: Double = 0
    @State private var containerOffset: CGFloat = 60

    private let colors: [Color] = [
        Theme.accentPrimary, Theme.accentSuccess, Color.yellow,
        Color.blue.opacity(0.8), Color.purple.opacity(0.8)
    ]

    var body: some View {
        ZStack {
            if isVisible {
                // Dimmed background
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { dismiss() }

                VStack(spacing: 0) {
                    Spacer()

                    // Celebration card
                    VStack(spacing: 20) {
                        // Animated checkmark
                        ZStack {
                            Circle()
                                .fill(Theme.accentSuccess.opacity(0.15))
                                .frame(width: 80, height: 80)
                            Circle()
                                .stroke(Theme.accentSuccess.opacity(0.3), lineWidth: 2)
                                .frame(width: 80, height: 80)
                            Image(systemName: "checkmark")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Theme.accentSuccess)
                                .scaleEffect(checkScale)
                        }

                        VStack(spacing: 6) {
                            Text("Address updated!")
                                .font(.system(size: 20, weight: .bold, design: .serif))
                                .foregroundColor(Theme.textPrimary)
                            Text(taskTitle)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                        }
                        .opacity(textOpacity)

                        Button(action: dismiss) {
                            Text("Keep going →")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.accentSuccess)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .opacity(textOpacity)
                    }
                    .padding(28)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(Theme.accentSuccess.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .offset(y: containerOffset)

                    // Confetti overlay
                    .overlay(alignment: .top) {
                        ZStack {
                            ForEach(particles) { p in
                                Circle()
                                    .fill(p.color)
                                    .frame(width: p.size, height: p.size)
                                    .offset(x: p.x, y: p.y)
                                    .rotationEffect(.degrees(p.rotation))
                                    .opacity(animating ? 0 : 1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 1)
                    }

                    Spacer().frame(height: 40)
                }
                .transition(.opacity)
                .onAppear { startAnimation() }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
    }

    private func startAnimation() {
        // Haptic
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Spawn particles
        particles = (0..<20).map { _ in
            Particle(
                x: CGFloat.random(in: -120...120),
                y: 0,
                color: colors.randomElement()!,
                size: CGFloat.random(in: 4...10),
                rotation: Double.random(in: 0...360),
                xVelocity: CGFloat.random(in: -80...80),
                yVelocity: CGFloat.random(in: -120...(-40))
            )
        }

        // Slide card in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            containerOffset = 0
        }

        // Checkmark pop
        withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.15)) {
            checkScale = 1
        }

        // Fade text in
        withAnimation(.easeOut(duration: 0.3).delay(0.25)) {
            textOpacity = 1
        }

        // Animate particles outward
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            animating = true
            for i in particles.indices {
                particles[i].x += particles[i].xVelocity
                particles[i].y += particles[i].yVelocity
            }
        }

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            dismiss()
        }
    }

    private func dismiss() {
        withAnimation(.easeInOut(duration: 0.25)) {
            onDismiss()
        }
    }
}
