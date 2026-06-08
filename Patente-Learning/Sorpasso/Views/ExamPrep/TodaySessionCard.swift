//
//  TodaySessionCard.swift
//  Patente-Learning
//
//  The home-screen hero for the daily "Today's Session". The headline is the
//  live, self-correcting exam-ready forecast (the metric the persona actually
//  cares about); below it, today's set progress, the streak, and the start /
//  resume / done state. Tapping Start asks the parent to launch a session.
//

import SwiftUI

struct TodaySessionCard: View {
    @ObservedObject private var sessions = DailySessionStore.shared
    @ObservedObject private var progress = ExamProgressManager.shared

    /// Parent builds the question queue and presents the runner.
    let onStart: () -> Void

    private var forecast: ReadinessForecast { sessions.forecast() }
    private var report: ReadinessReport { ReadinessEngine.evaluate() }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            headline
            Divider().opacity(0.4)
            footerRow
            startButton
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .accentColor.opacity(0.12), radius: 10, y: 5)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Label("Today's Session", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.accentColor)
            Spacer()
            if sessions.streak > 0 {
                Label("\(sessions.streak)", systemImage: "flame.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.orange)
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("\(sessions.streak) day streak")
            }
        }
    }

    // MARK: - Headline (the forecast)

    @ViewBuilder
    private var headline: some View {
        if forecast.isReady {
            VStack(alignment: .leading, spacing: 4) {
                Text("You're exam ready 🎉")
                    .font(.title2.weight(.bold))
                Text("\(Int((report.probabilityOfPassing * 100).rounded()))% projected pass · \(report.band)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else if let date = forecast.readyDate {
            VStack(alignment: .leading, spacing: 4) {
                Text("Exam ready by \(dateString(date))")
                    .font(.title2.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Circle()
                        .fill(forecast.onTrack ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(forecast.onTrack ? "On track" : "Behind your plan")
                        .font(.caption.weight(.medium))
                        .foregroundColor(forecast.onTrack ? .green : .orange)
                    Text("· \(Int((report.probabilityOfPassing * 100).rounded()))% ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Text("Start your prep")
                .font(.title2.weight(.bold))
        }
    }

    // MARK: - Footer (set progress)

    private var footerRow: some View {
        HStack {
            Image(systemName: sessions.isGoalMetToday ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundColor(sessions.isGoalMetToday ? .green : .secondary)
            Text(progressText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var progressText: String {
        if sessions.isGoalMetToday {
            return "Done for today — see you tomorrow"
        }
        let next = sessions.subSessionsToday + 1
        if sessions.chunkCount > 1 {
            return "Set \(next) of \(sessions.chunkCount) · \(sessions.chunkSize) questions"
        }
        return "\(sessions.chunkSize) questions today"
    }

    // MARK: - Start button

    private var startButton: some View {
        Button(action: onStart) {
            Text(buttonTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(sessions.isGoalMetToday ? Color.secondary.opacity(0.18) : Color.accentColor)
                )
                .foregroundColor(sessions.isGoalMetToday ? .primary : .white)
        }
        .buttonStyle(.plain)
    }

    private var buttonTitle: String {
        if sessions.isGoalMetToday { return "Practice again" }
        return sessions.subSessionsToday > 0 ? "Resume session" : "Start session"
    }

    private func dateString(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}
