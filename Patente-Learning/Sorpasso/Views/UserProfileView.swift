//
//  UserProfileView.swift
//  Patente-Learning
//
//  Profile + exam-readiness overview, driven by ExamProgressManager and
//  ReadinessEngine (the fresh per-question tracking).
//

import SwiftUI

struct UserProfileView: View {
    // ── Identity ──────────────────────────────────────────────────────────
    @AppStorage("userName")  private var userName:  String = "Learner"
    @AppStorage("userEmoji") private var userEmoji: String = "🚗"

    @ObservedObject private var progress = ExamProgressManager.shared

    @State private var showEditProfile = false
    @State private var showResetAlert  = false

    @ScaledMetric(relativeTo: .largeTitle) private var avatarEmojiSize: CGFloat = 72

    private var report: ReadinessReport { ReadinessEngine.evaluate() }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                identityHeader

                ReadinessCardView()

                Divider().padding(.horizontal)

                statCardsRow

                Divider().padding(.horizontal)

                chapterBreakdownSection

                Divider().padding(.horizontal)

                actionsSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
    }

    // MARK: - Identity Header

    private var identityHeader: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                Text(userEmoji)
                    .font(.system(size: avatarEmojiSize))
                    .padding(8)
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

                Button {
                    showEditProfile = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .background(Circle().fill(Color.appBackground))
                }
            }

            Text(userName)
                .font(.title2.bold())

            Text("Your Patente Journey")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Stat Cards

    private var statCardsRow: some View {
        let r = report
        return HStack(spacing: 12) {
            statCard(title: "Questions Seen", value: "\(r.attemptedQuestions)")
            statCard(title: "Accuracy",       value: "\(Int(((progress.overallAccuracy() ?? 0) * 100).rounded()))%")
            statCard(title: "Bank Covered",   value: "\(Int((r.coverage * 100).rounded()))%")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }

    // MARK: - Chapter Breakdown

    private var chapterBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters Overview")
                .font(.headline)

            ForEach(BloccoStore.shared.chapterOrder, id: \.self) { chapter in
                let blocchi = BloccoStore.shared.blocchi(in: chapter)
                let mastery = chapterMastery(blocchi)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(chapter.capitalized)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(Int((mastery * 100).rounded()))%")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(.secondary)
                    }

                    ProgressView(value: mastery)
                        .progressViewStyle(.linear)
                        .tint(mastery >= 0.8 ? .green : .blue)
                        .scaleEffect(x: 1, y: 1.8)
                        .animation(.easeInOut(duration: 0.6), value: mastery)
                }
                .padding()
                .glassCard()
            }
        }
    }

    private func chapterMastery(_ blocchi: [Blocco]) -> Double {
        guard !blocchi.isEmpty else { return 0 }
        let total = blocchi.reduce(0.0) { $0 + progress.mastery(for: $1) }
        return total / Double(blocchi.count)
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(role: .destructive) {
                showResetAlert = true
            } label: {
                Label("Reset All Progress", systemImage: "arrow.counterclockwise.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .alert("Reset All Progress?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) {
                    progress.resetAll()
                    HapticsManager.success()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will erase all question practice and readiness data. This cannot be undone.")
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Previews

#Preview("Profile") {
    NavigationStack {
        UserProfileView()
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
    }
}
