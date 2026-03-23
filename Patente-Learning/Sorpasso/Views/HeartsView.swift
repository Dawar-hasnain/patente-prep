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
    let onRetry:        () -> Void
    let onDismiss:      () -> Void
    /// When non-nil, an "Instant Refill — 20 XP" button is shown.
    /// Tapping it continues the current session without resetting progress.
    let onRefillWithXP: (() -> Void)?

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

                    Text("Refill to keep going, or start fresh.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 24)

                // ── Heart regen timer ─────────────────────────────────────
                heartTimerBadge
                    .padding(.bottom, 32)

                Spacer()

                // ── Buttons ───────────────────────────────────────────────
                VStack(spacing: 14) {

                    // Instant refill with XP (premium — continues the session)
                    if let refill = onRefillWithXP {
                        Button(action: refill) {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                Text("Instant Refill — \(HeartsManager.xpRefillCost) XP")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(LinearGradient(
                                        colors: [Color.pink, Color.red],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                            )
                            .foregroundColor(.white)
                        }
                    }

                    // Free retry — resets session progress
                    Button(action: onRetry) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Try Again")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(onRefillWithXP != nil
                                      ? Color.secondary.opacity(0.1)
                                      : Color.red)
                        )
                        .foregroundColor(onRefillWithXP != nil ? .primary : .white)
                    }

                    Button(action: onDismiss) {
                        Text("Back to Map")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
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

    // MARK: - Heart Regen Timer

    /// Shows a live countdown to the next free heart, updated every second.
    @ViewBuilder
    private var heartTimerBadge: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let seconds = HeartsManager.shared.timeUntilNextHeart
            if seconds > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Next heart in \(formatSeconds(seconds))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.1))
                        .overlay(Capsule().strokeBorder(Color.orange.opacity(0.25), lineWidth: 1))
                )
            }
        }
    }

    private func formatSeconds(_ t: TimeInterval) -> String {
        let total   = max(0, Int(t))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
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

#Preview("Session Failed – no XP refill") {
    SessionFailedView(onRetry: {}, onDismiss: {}, onRefillWithXP: nil)
}

#Preview("Session Failed – XP refill available") {
    SessionFailedView(onRetry: {}, onDismiss: {}, onRefillWithXP: {})
}
