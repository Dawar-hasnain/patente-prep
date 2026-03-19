//
//  WordCardView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//

import SwiftUI

struct WordCardView: View {
    let word: Words
    @Binding var flipped: Bool

    @State private var isPressed = false

    var body: some View {
        ZStack {
            // BACKGROUND SoftGlass Card (static — not flipping)
            RoundedRectangle(cornerRadius: 25)
                .fill(.ultraThinMaterial)

            // FRONT SIDE
            frontSide
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(
                    .degrees(flipped ? 180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )

            // BACK SIDE
            backSide
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(
                    .degrees(flipped ? 0 : -180),
                    axis: (x: 0, y: 1, z: 0)
                )
        }
        .frame(maxWidth: .infinity)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: flipped)
        .animation(.spring(response: 0.28, dampingFraction: 0.7), value: isPressed)
        .onTapGesture { flipCard() }

        // ⬇️ IMPORTANT: SAFE PARALLAX (does NOT use DragGesture)
        .modifier(SafeParallaxTilt())

        .softGlassCard()
        .padding(.horizontal, 24)
        .padding(.top, 12)

        // ⛔ REMOVED — this was blocking swipe
        // .simultaneousGesture(DragGesture(minimumDistance: 0))
    }

    // MARK: - FRONT SIDE
    private var frontSide: some View {
        VStack(spacing: 16) {
            Text(word.italian)
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 20)
        }
        .padding()
    }

    // MARK: - BACK SIDE
    private var backSide: some View {
        VStack(spacing: 12) {
            Text(word.italian)
                .font(.title2.weight(.semibold))
                .foregroundColor(.secondary.opacity(0.8))

            Divider()
                .frame(width: 60)
                .background(Color.primary.opacity(0.15))

            Text(word.english)
                .font(.largeTitle.bold())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Animations
    private func flipCard() {
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.impactOccurred()

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            flipped.toggle()
        }
    }

    private func pressDown() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isPressed = true
        }
    }

    private func releasePress() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isPressed = false
        }
    }
}

struct SafeParallaxTilt: ViewModifier {
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(tiltX * 12),
                axis: (x: 1, y: 0, z: 0)
            )
            .rotation3DEffect(
                .degrees(tiltY * 12),
                axis: (x: 0, y: 1, z: 0)
            )
            .onAppear {
                MotionManager.shared.startUpdates { pitch, roll in
                    withAnimation(.easeOut(duration: 0.12)) {
                        tiltX = pitch
                        tiltY = roll
                    }
                }
            }
    }
}

