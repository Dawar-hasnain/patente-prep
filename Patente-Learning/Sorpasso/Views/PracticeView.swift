//
//  PracticeView.swift
//  Patente-Learning
//
//  Practice tab for the exam-prep flow: a full Mock Exam and a targeted
//  review of the questions the learner is weakest on. Both draw from the
//  official question bank (BloccoStore) and record results into
//  ExamProgressManager.
//

import SwiftUI

struct PracticeView: View {
    @ObservedObject private var progress = ExamProgressManager.shared

    @State private var showMockExam = false
    @State private var showWeakReview = false
    @State private var weakQuestions: [Question] = []

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

                // ── Mock Exam ─────────────────────────────────────────────
                sectionHeader(
                    icon: "doc.text.fill",
                    title: "Mock Exam",
                    subtitle: "Simulate the real Italian driving theory test"
                )

                mockExamCard

                Divider().padding(.horizontal)

                // ── Weak Questions ────────────────────────────────────────
                sectionHeader(
                    icon: "exclamationmark.triangle.fill",
                    title: "Weak Questions",
                    subtitle: "Revisit the questions you get wrong most"
                )

                weakQuestionsCard

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Practice")
        // Mock Exam
        .fullScreenCover(isPresented: $showMockExam) {
            MockExamView(onFinish: { showMockExam = false })
        }
        // Weak-question review
        .fullScreenCover(isPresented: $showWeakReview) {
            TrueFalsePracticeView(
                title: "Weak Questions",
                questions: weakQuestions,
                onFinish: { showWeakReview = false }
            )
        }
    }

    // MARK: - Mock Exam Card

    private var mockExamCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mock Exam")
                        .font(.headline)
                    Text("30 Q · Max 3 mistakes · 30 min")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.indigo)
                }
            }

            Text("True / False questions drawn from the official bank. Pass with 3 or fewer mistakes — just like the real patente exam.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 20) {
                statPill(icon: "questionmark.circle.fill", label: "30 Questions", color: .indigo)
                statPill(icon: "xmark.circle.fill",        label: "3 Max Errors", color: .red)
                statPill(icon: "clock.fill",               label: "30 Minutes",   color: .orange)
            }

            Button {
                showMockExam = true
            } label: {
                Text("Start Mock Exam")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.indigo))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.indigo.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .indigo.opacity(0.1), radius: 8, x: 0, y: 4)
    }

    // MARK: - Weak Questions Card

    @ViewBuilder
    private var weakQuestionsCard: some View {
        let weakCount = progress.weakQuestionIDs(limit: 100).count

        if weakCount == 0 {
            // HIG: ContentUnavailableView is the sanctioned empty-state
            // component — not an alert, which is reserved for critical
            // interruptions.
            ContentUnavailableView {
                Label("No Weak Questions Yet", systemImage: "checkmark.seal")
            } description: {
                Text("Practise some questions first — the ones you miss most will collect here for focused review.")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                    Text("Weak Questions")
                        .font(.headline)
                }

                Text("\(weakCount) question\(weakCount == 1 ? "" : "s") need more practice. Review them now to raise your readiness.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    let ids = progress.weakQuestionIDs(limit: 30)
                    let qs = BloccoStore.shared.questions(ids: ids)
                    guard !qs.isEmpty else { return }
                    weakQuestions = qs
                    showWeakReview = true
                } label: {
                    Text("Start Weak Question Review")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.red))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        }
    }

    // MARK: - Subview Builders

    @ViewBuilder
    private func statPill(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(color)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Previews

#Preview("Practice") {
    NavigationStack {
        PracticeView()
    }
}
