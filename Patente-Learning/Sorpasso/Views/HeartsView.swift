//
//  HeartsView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 17/03/26.
//
//  Reusable heart display for review sessions.
//  Shows 5 hearts, animates when one is lost.
//

import SwiftUI

struct HeartsView: View {
    let hearts: Int                    // current remaining (0–5)
    let maxHearts: Int                 // always 5
    @State private var shakeHeart = false
    @State private var previousHearts: Int

    init(hearts: Int, maxHearts: Int = 5) {
        self.hearts = hearts
        self.maxHearts = maxHearts
        self._previousHearts = State(initialValue: hearts)
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<maxHearts, id: \.self) { index in
                Image(systemName: index < hearts ? "heart.fill" : "heart")
                    .font(.system(.body, weight: .semibold))
                    .foregroundColor(index < hearts ? .red : Color.secondary.opacity(0.3))
                    // The heart that was just lost gets the shake
                    .modifier(ShakeEffect(animatableData: (shakeHeart && index == hearts) ? 1 : 0))
                    .scaleEffect(index < hearts ? 1.0 : 0.85)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: hearts)
            }
        }
        .onChange(of: hearts) { newValue in
            if newValue < previousHearts {
                // Lost a heart — shake and haptic
                withAnimation(.default) { shakeHeart = true }
                HapticsManager.error()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    shakeHeart = false
                }
            }
            previousHearts = newValue
        }
    }
}

// MARK: - Session Failed View
// Shown inline when hearts reach 0.

struct SessionFailedView: View {
    let onRetry: () -> Void
    let onDismiss: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var failedIconSize: CGFloat = 64
    @State private var scaleIn = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Icon ──────────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 130, height: 130)

                    Image(systemName: "heart.slash.fill")
                        .font(.system(size: failedIconSize))
                        .foregroundColor(.red)
                        .scaleEffect(scaleIn ? 1.0 : 0.3)
                        .opacity(scaleIn ? 1.0 : 0)
                }
                .shadow(color: .red.opacity(0.2), radius: 16, y: 8)
                .padding(.bottom, 28)

                // ── Title ─────────────────────────────────────────────────
                VStack(spacing: 8) {
                    Text("Out of Hearts!")
                        .font(.system(.title2, design: .rounded).weight(.bold))

                    Text("Don't worry — keep practicing\nand try again.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 40)

                Spacer()

                // ── Buttons ───────────────────────────────────────────────
                VStack(spacing: 14) {
                    Button(action: onRetry) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Try Again")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.red))
                        .foregroundColor(.white)
                    }

                    Button(action: onDismiss) {
                        Text("Back to Map")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 14)
                                .fill(Color.secondary.opacity(0.1)))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                scaleIn = true
            }
            HapticsManager.heavyTap()
        }
    }
}

// MARK: - Previews

#Preview("Hearts – Full") {
    HeartsView(hearts: 5)
        .padding()
}

#Preview("Hearts – 2 Remaining") {
    HeartsView(hearts: 2)
        .padding()
}

#Preview("Session Failed") {
    SessionFailedView(onRetry: {}, onDismiss: {})
}
