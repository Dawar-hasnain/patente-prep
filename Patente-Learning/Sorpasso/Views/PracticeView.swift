//
//  PracticeView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 17/03/26.
//
//  Dedicated Practice tab — all on-demand challenge modes in one place.
//

import SwiftUI

struct PracticeView: View {
    @State private var selectedChapter: ChapterList = .la_strada
    @State private var showChapterPicker = false
    @State private var noWeakWordsAlert = false
    @State private var showRecallMode = false
    @State private var showWeakWords = false
    @State private var weakWordStates: [WordMemoryState] = []
    @State private var showPendingReview = false
    @State private var pendingReviewChapter: ChapterList? = nil
    @State private var pendingCheckpoint: ReviewCheckpoint? = nil
    @State private var showMockExam = false

    private let manager = ProgressManager.shared

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

                // ── Section header ────────────────────────────────────────
                sectionHeader(
                    icon: "brain.head.profile",
                    title: "Recall Practice",
                    subtitle: "Test yourself on a full chapter"
                )

                // ── Recall Practice Card ──────────────────────────────────
                practiceCard(
                    icon: "text.bubble.fill",
                    iconColor: .orange,
                    title: "Chapter Recall",
                    description: "Fill-in-the-blank sentences from a chapter of your choice.",
                    buttonLabel: "Choose Chapter & Start",
                    buttonColor: .orange
                ) {
                    showChapterPicker = true
                }

                // ── Weak Words Card ───────────────────────────────────────
                practiceCard(
                    icon: "exclamationmark.triangle.fill",
                    iconColor: .red,
                    title: "Weak Words",
                    description: "Revisit the words your memory is struggling with most.",
                    buttonLabel: "Start Weak Word Review",
                    buttonColor: .red
                ) {
                    let weak = manager.weakWords()
                    if weak.isEmpty {
                        noWeakWordsAlert = true
                    } else {
                        weakWordStates = weak
                        showWeakWords = true
                    }
                }

                // ── Divider ───────────────────────────────────────────────
                Divider().padding(.horizontal)

                // ── Section header ────────────────────────────────────────
                sectionHeader(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Spaced Review",
                    subtitle: "Pending review sessions from your progress"
                )

                // ── Pending reviews list ──────────────────────────────────
                pendingReviewsSection

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 100)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Practice")
        // Chapter picker sheet
        .sheet(isPresented: $showChapterPicker) {
            ChapterPickerSheet(selected: $selectedChapter) {
                showChapterPicker = false
                showRecallMode = true
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        // Recall Mode
        .fullScreenCover(isPresented: $showRecallMode) {
            RecallModeView(chapter: selectedChapter)
        }
        // Weak Words
        .fullScreenCover(isPresented: $showWeakWords) {
            TargetedRecallView(weakStates: weakWordStates)
        }
        // Pending Review Session (Duolingo-style)
        .fullScreenCover(isPresented: $showPendingReview) {
            if let chapter = pendingReviewChapter, let checkpoint = pendingCheckpoint {
                let chapterWords = loadChapter(chapter.filename).words
                LessonSessionView(
                    sessionWords: chapterWords,
                    allWords: chapterWords,
                    onFinish: {
                        manager.updateCheckpoint(
                            for: chapter,
                            section: checkpoint.section,
                            passed: true,
                            score: 1.0
                        )
                        showPendingReview = false
                    }
                )
            }
        }
        // Mock Exam
        .fullScreenCover(isPresented: $showMockExam) {
            MockExamView(onFinish: { showMockExam = false })
        }
        // No weak words alert
        .alert("No Weak Words Yet", isPresented: $noWeakWordsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Keep learning and reviewing — weak words will appear here once your memory data builds up.")
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
                    Text("30 Q · Max 3 mistakes")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.indigo)
                }
            }

            Text("True / False questions drawn from all 10 chapters. Pass with 3 or fewer mistakes — just like the real patente exam.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Stats row
            HStack(spacing: 20) {
                statPill(icon: "questionmark.circle.fill", label: "30 Questions", color: .indigo)
                statPill(icon: "xmark.circle.fill",        label: "3 Max Errors", color: .red)
                statPill(icon: "star.fill",                label: "100 XP",       color: .yellow)
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

    // MARK: - Pending Reviews

    @ViewBuilder
    private var pendingReviewsSection: some View {
        let pendingChapters = ChapterList.allCases.filter {
            ProgressManager.shared.nextPendingCheckpoint(for: $0) != nil
        }

        if pendingChapters.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("All reviews are up to date")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
        } else {
            VStack(spacing: 12) {
                ForEach(pendingChapters, id: \.self) { chapter in
                    if let checkpoint = ProgressManager.shared.nextPendingCheckpoint(for: chapter) {
                        Button {
                            pendingReviewChapter = chapter
                            pendingCheckpoint = checkpoint
                            showPendingReview = true
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(chapter.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text("Section \(checkpoint.section) ready")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Subview Builders

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

    @ViewBuilder
    private func practiceCard(
        icon: String,
        iconColor: Color,
        title: String,
        description: String,
        buttonLabel: String,
        buttonColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
            }

            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: action) {
                Text(buttonLabel)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(buttonColor))
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

// MARK: - Chapter Picker Sheet

struct ChapterPickerSheet: View {
    @Binding var selected: ChapterList
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            List(ChapterList.allCases) { chapter in
                Button {
                    selected = chapter
                } label: {
                    HStack {
                        Text(chapter.title)
                            .foregroundColor(.primary)
                        Spacer()
                        if selected == chapter {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
            }
            .navigationTitle("Choose Chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start") { onConfirm() }
                        .font(.headline)
                }
            }
        }
    }
}

// MARK: - Previews

#Preview("Practice") {
    NavigationStack {
        PracticeView()
    }
}

#Preview("Chapter Picker") {
    ChapterPickerSheet(selected: .constant(.la_strada)) { }
}
