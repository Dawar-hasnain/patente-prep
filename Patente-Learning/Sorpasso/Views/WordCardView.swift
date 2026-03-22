//
//  WordCardView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 07/11/25.
//  Redesigned — added speaker button, tap-to-reveal hint, improved layout.
//

import SwiftUI
import AVFoundation

struct WordCardView: View {
    let word: Words
    @Binding var flipped: Bool

    @State private var isPressed     = false
    @State private var speakerPulse  = false   // brief scale on tap

    var body: some View {
        ZStack {
            // Static glass background
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)

            // Front face — Italian word
            frontSide
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(flipped ? 90 : 0), axis: (x: 0, y: 1, z: 0))

            // Back face — English translation
            backSide
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(flipped ? 0 : -90), axis: (x: 0, y: 1, z: 0))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 220)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.38, dampingFraction: 0.78), value: flipped)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onTapGesture { flipCard() }
        .modifier(SafeParallaxTilt())
        .softGlassCard()
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    // MARK: - Front Face

    private var frontSide: some View {
        ZStack(alignment: .bottom) {
            // Central word
            VStack(spacing: 0) {
                Spacer()
                Text(word.italian)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Spacer()
            }

            // Bottom row: "Tap to reveal" hint  +  speaker button
            HStack {
                Label("Tap to reveal", systemImage: "hand.tap")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary.opacity(0.55))
                    .padding(.leading, 16)
                    .padding(.bottom, 14)

                Spacer()

                speakerButton
                    .padding(.trailing, 14)
                    .padding(.bottom, 12)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Back Face

    private var backSide: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 10) {
                Spacer()

                // Italian (smaller, above)
                Text(word.italian)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundColor(.secondary)

                // Divider
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 48, height: 1)

                // English (large, main focus)
                Text(word.english)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)

                Spacer()
            }

            // Speaker button — bottom trailing
            speakerButton
                .padding(.trailing, 14)
                .padding(.bottom, 14)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Speaker Button

    private var speakerButton: some View {
        Button {
            SpeechManager.shared.speak(word.italian)
            HapticsManager.lightTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { speakerPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.3)) { speakerPulse = false }
            }
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .font(.callout.weight(.semibold))
                .foregroundColor(.accentColor)
                .padding(10)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))
                .scaleEffect(speakerPulse ? 1.22 : 1.0)
        }
        // Prevents the tap bubbling up to the flip gesture
        .buttonStyle(.plain)
    }

    // MARK: - Flip

    private func flipCard() {
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            flipped.toggle()
        }
    }
}

// MARK: - SafeParallaxTilt (unchanged)

struct SafeParallaxTilt: ViewModifier {
    @State private var tiltX: Double = 0
    @State private var tiltY: Double = 0

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(tiltX * 12), axis: (x: 1, y: 0, z: 0))
            .rotation3DEffect(.degrees(tiltY * 12), axis: (x: 0, y: 1, z: 0))
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
