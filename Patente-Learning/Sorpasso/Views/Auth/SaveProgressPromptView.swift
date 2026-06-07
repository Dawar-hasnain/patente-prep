//
//  SaveProgressPromptView.swift
//  Patente-Learning
//
//  A non-intrusive sheet that re-surfaces sign-in for guest users after meaningful
//  milestones (first chapter completed, first 3-day streak, etc.).
//
//  Trigger rules (enforced by MilestoneTracker):
//    • Never shown to already-authenticated users.
//    • Shown at most once every 24 hours.
//    • Dismissed "Maybe Later" → suppressed for 24 h.
//    • Dismissed "Don't ask again" → never shown again.
//

import SwiftUI
import Combine

// MARK: - Milestone Tracker

/// Decides whether the save-progress prompt should appear.
/// Call `shouldShow(after:)` after learning events; present the sheet when true.
final class MilestoneTracker: ObservableObject {

    // UserDefaults keys
    private enum Keys {
        static let lastPromptDate   = "savePrompt_lastShownDate"
        static let neverAskAgain    = "savePrompt_neverAskAgain"
        static let totalLearnedPrev = "savePrompt_prevLearnedCount"
    }

    private let suppressionInterval: TimeInterval = 24 * 60 * 60  // 24 h

    // MARK: - Check

    /// Returns true when a milestone is met and the prompt hasn't been recently shown.
    func shouldShow(authState: AuthState) -> Bool {
        guard authState == .anonymous || authState == .offlineGuest else { return false }
        guard !UserDefaults.standard.bool(forKey: Keys.neverAskAgain) else { return false }

        if let last = UserDefaults.standard.object(forKey: Keys.lastPromptDate) as? Date {
            guard Date().timeIntervalSince(last) > suppressionInterval else { return false }
        }

        return isMilestoneMet()
    }

    /// Records that the prompt was shown right now.
    func markShown() {
        UserDefaults.standard.set(Date(), forKey: Keys.lastPromptDate)
    }

    /// Suppresses the prompt forever.
    func markNeverAskAgain() {
        UserDefaults.standard.set(true, forKey: Keys.neverAskAgain)
    }

    // MARK: - Milestones

    private func isMilestoneMet() -> Bool {
        // Milestone: the learner has practised a meaningful number of questions.
        return ExamProgressManager.shared.seenQuestionCount >= 20
    }
}

// MARK: - SaveProgressPromptView

struct SaveProgressPromptView: View {

    @EnvironmentObject private var auth: AuthManager
    @StateObject private var tracker = MilestoneTracker()

    @ScaledMetric(relativeTo: .largeTitle) private var cloudIconSize: CGFloat = 48

    /// Controls visibility — set to true by the parent when `tracker.shouldShow()` returns true.
    @Binding var isPresented: Bool

    // Local UI state
    @State private var showAuthSheet   = false
    @State private var animateContent  = false

    // Snapshot of progress to display inside the card
    private let seenQuestions   = ExamProgressManager.shared.seenQuestionCount
    private let totalQuestions  = BloccoStore.shared.totalQuestionCount
    private let readinessPct    = Int((ReadinessEngine.evaluate().probabilityOfPassing * 100).rounded())

    var body: some View {
        VStack(spacing: 0) {

            // ── Handle ───────────────────────────────────────────────────────
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 40, height: 4)
                .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // ── Header ───────────────────────────────────────────────
                    VStack(spacing: 10) {
                        Image(systemName: "cloud.fill")
                            .font(.system(size: cloudIconSize))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(animateContent ? 1.0 : 0.5)
                            .opacity(animateContent ? 1.0 : 0.0)

                        Text("Don't lose your progress!")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        Text("You're making real progress. Sign in to sync it across all your devices.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .padding(.top, 20)

                    // ── Progress snapshot card ────────────────────────────────
                    HStack(spacing: 0) {
                        progressStat(
                            value: "\(seenQuestions)",
                            label: "Questions\nPractised",
                            icon: "book.fill",
                            color: .blue
                        )

                        Divider().frame(height: 44)

                        progressStat(
                            value: "\(readinessPct)%",
                            label: "Exam\nReadiness",
                            icon: "checkmark.seal.fill",
                            color: .green
                        )

                        Divider().frame(height: 44)

                        progressStat(
                            value: "\(totalQuestions)",
                            label: "Total\nQuestions",
                            icon: "doc.text.fill",
                            color: .orange
                        )
                    }
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.07), radius: 6, y: 3)
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)

                    // ── CTA button ────────────────────────────────────────────
                    Button {
                        tracker.markShown()
                        showAuthSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "icloud.and.arrow.up.fill")
                            Text("Sign In & Save Progress")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                    }
                    .offset(y: animateContent ? 0 : 20)
                    .opacity(animateContent ? 1 : 0)

                    // ── Secondary actions ─────────────────────────────────────
                    VStack(spacing: 6) {
                        Button("Maybe Later") {
                            tracker.markShown()     // suppresses for 24 h
                            isPresented = false
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)

                        Button("Don't ask again") {
                            tracker.markNeverAskAgain()
                            isPresented = false
                        }
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.6))
                    }
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.appBackground)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.15)) {
                animateContent = true
            }
        }
        // Full-screen auth sheet — when the user signs in successfully the prompt auto-closes
        .fullScreenCover(isPresented: $showAuthSheet) {
            AuthView(isPresentedAsSheet: true)
                .environmentObject(auth)
        }
        .onChange(of: auth.authState) { state in
            // If the user successfully authenticated via the sheet, dismiss the prompt
            if state == .authenticated {
                isPresented = false
            }
        }
    }

    // MARK: - Helpers

    private func progressStat(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(value)
                .font(.title3.bold())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    SaveProgressPromptView(isPresented: .constant(true))
        .environmentObject(AuthManager.shared)
}
