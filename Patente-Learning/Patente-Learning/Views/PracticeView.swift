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

    private let manager = ProgressManager.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {

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
        // Pending Review Session
        .fullScreenCover(isPresented: $showPendingReview) {
            if let chapter = pendingReviewChapter, let checkpoint = pendingCheckpoint {
                ReviewSessionView(
                    chapter: chapter,
                    currentProgress: manager.progress(for: chapter),
                    checkpoint: checkpoint,
                    onCompletion: { passed, score in
                        manager.updateCheckpoint(for: chapter, section: checkpoint.section, passed: passed, score: score)
                        showPendingReview = false
                    },
                    onDismiss: {
                        manager.delayCheckpoint(checkpoint, for: chapter)
                        showPendingReview = false
                    }
                )
            }
        }
        // No weak words alert
        .alert("No Weak Words Yet", isPresented: $noWeakWordsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Keep learning and reviewing — weak words will appear here once your memory data builds up.")
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
