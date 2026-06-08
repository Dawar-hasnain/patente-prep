//
//  ExamPrepHomeView.swift
//  Patente-Learning
//
//  Entry point for the new exam-bank flow: browse the official chapters,
//  drill into a chapter's Blocchi (concept clusters), and open a ConceptCard
//  to study + practise the real ministry questions.
//
//  Backed by BloccoStore (questions_v2_en.json) — independent of the legacy
//  vocab screens, which remain untouched during the migration.
//

import SwiftUI

struct ExamPrepHomeView: View {
    private let store = BloccoStore.shared

    @State private var searchText = ""

    // Daily session
    @State private var showSession = false
    @State private var sessionQuestions: [Question] = []

    /// Blocchi matching the current query — searched across English topic,
    /// Italian topic, and chapter so users can jump straight to a concept
    /// instead of drilling the hierarchy (HIG: efficient navigation of large
    /// collections).
    private var matchingBlocchi: [Blocco] {
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return store.blocchi.filter {
            $0.topic_en.lowercased().contains(q) ||
            $0.topic.lowercased().contains(q) ||
            $0.chapter.lowercased().contains(q)
        }
    }

    var body: some View {
        List {
            if searchText.isEmpty {
                Section {
                    TodaySessionCard(onStart: startSession)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    ReadinessCardView()
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                    summaryHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                ForEach(store.chapterOrder, id: \.self) { chapter in
                    let blocchi = store.blocchi(in: chapter)
                    NavigationLink {
                        BloccoListView(chapter: chapter, blocchi: blocchi)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "book.closed.fill")
                                .font(.title3)
                                .foregroundColor(.accentColor)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(chapter.capitalized)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(blocchi.count) concepts · \(blocchi.reduce(0) { $0 + $1.questions.count }) questions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                searchResults
            }
        }
        .navigationTitle("Study")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search topics & chapters")
        .fullScreenCover(isPresented: $showSession) {
            TrueFalsePracticeView(
                title: "Today's Session",
                questions: sessionQuestions,
                onFinish: {
                    DailySessionStore.shared.recordSubSessionCompleted()
                    showSession = false
                }
            )
        }
    }

    /// Build the next sub-session's queue and present the runner.
    private func startSession() {
        sessionQuestions = SessionBuilder.buildSession(size: DailySessionStore.shared.chunkSize)
        guard !sessionQuestions.isEmpty else { return }
        showSession = true
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = matchingBlocchi
        if results.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            Section("\(results.count) concept\(results.count == 1 ? "" : "s")") {
                ForEach(results) { blocco in
                    NavigationLink {
                        ConceptCardView(blocco: blocco)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(blocco.topic_en)
                                .font(.subheadline.weight(.semibold))
                            Text("\(blocco.chapter.capitalized) · \(blocco.questions.count) questions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Official question bank")
                .font(.headline)
            Text("\(store.blocchi.count) concepts · \(store.totalQuestionCount) true/false questions")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .padding(.bottom, 4)
    }
}

// MARK: - Blocco list for a chapter

struct BloccoListView: View {
    let chapter: String
    let blocchi: [Blocco]

    @ObservedObject private var progress = ExamProgressManager.shared

    var body: some View {
        List(blocchi) { blocco in
            NavigationLink {
                ConceptCardView(blocco: blocco)
            } label: {
                HStack(spacing: 12) {
                    masteryRing(for: blocco)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(blocco.topic_en)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                        HStack(spacing: 8) {
                            Text("\(progress.attemptedCount(in: blocco))/\(blocco.questions.count) seen")
                            if !blocco.figures.isEmpty {
                                Label("\(blocco.figures.count)", systemImage: "photo")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle(chapter.capitalized)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func masteryRing(for blocco: Blocco) -> some View {
        let m = progress.mastery(for: blocco)
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.15), lineWidth: 4)
            Circle()
                .trim(from: 0, to: CGFloat(m))
                .stroke(m >= 0.8 ? Color.green : (m >= 0.4 ? Color.orange : Color.accentColor),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 26, height: 26)
    }
}
