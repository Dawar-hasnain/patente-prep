//
//  SettingsView.swift
//  Patente-Learning
//
//  Created by Dawar Hasnain on 09/11/25.
//  Redesigned 17/03/26 — custom card layout matching design reference.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    // ── Preferences ───────────────────────────────────────────────────────
    @AppStorage("isDarkMode")           private var isDarkMode           = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("soundEffectsEnabled")  private var soundEffectsEnabled  = true
    @AppStorage("accentColor")          private var accentColorName       = ThemeColor.Blue.rawValue
    @AppStorage("reminderHour")         private var reminderHour          = 19   // 7 PM

    // ── UI state ──────────────────────────────────────────────────────────
    @State private var showTimePicker   = false
    @State private var showEditProfile  = false
    @State private var showAbout        = false
    @State private var showResetAlert   = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {

                // ── 1. General Preferences ────────────────────────────────
                settingsGroup(title: "GENERAL PREFERENCES") {
                    toggleRow(
                        icon: "bell.fill",
                        iconColor: .blue,
                        title: "Notifications",
                        subtitle: "Reminders to keep your streak alive",
                        isOn: $notificationsEnabled
                    )
                    .onChange(of: notificationsEnabled) { enabled in
                        enabled ? scheduleNotification() : removePendingNotifications()
                    }

                    Divider().padding(.leading, 56)

                    // Reminder time — only shown when notifications on
                    if notificationsEnabled {
                        timeRow(
                            icon: "clock.fill",
                            iconColor: .orange,
                            title: "Daily Reminder",
                            subtitle: "Time for your daily practice"
                        )

                        Divider().padding(.leading, 56)
                    }

                    toggleRow(
                        icon: "speaker.wave.2.fill",
                        iconColor: .purple,
                        title: "Sound Effects",
                        subtitle: "Play sounds during lessons",
                        isOn: $soundEffectsEnabled
                    )

                    Divider().padding(.leading, 56)

                    toggleRow(
                        icon: isDarkMode ? "moon.fill" : "sun.max.fill",
                        iconColor: isDarkMode ? .indigo : .yellow,
                        title: "Dark Mode",
                        subtitle: "Easier on the eyes at night",
                        isOn: $isDarkMode
                    )
                    .onChange(of: isDarkMode) { newValue in
                        UIApplication.shared.connectedScenes
                            .compactMap { $0 as? UIWindowScene }
                            .flatMap { $0.windows }
                            .first?
                            .overrideUserInterfaceStyle = newValue ? .dark : .light
                    }
                }

                // ── 2. Appearance ─────────────────────────────────────────
                settingsGroup(title: "APPEARANCE") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            iconBadge("paintpalette.fill", color: .pink)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Accent Colour")
                                    .font(.subheadline.weight(.semibold))
                                Text("Personalise your app theme")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                        HStack(spacing: 12) {
                            ForEach(ThemeColor.allCases) { theme in
                                Button {
                                    accentColorName = theme.rawValue
                                    HapticsManager.lightTap()
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 36, height: 36)
                                        if accentColorName == theme.rawValue {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }
                }

                // ── 3. Account ────────────────────────────────────────────
                settingsGroup(title: "ACCOUNT") {
                    chevronRow(
                        icon: "person.fill",
                        iconColor: .green,
                        title: "Edit Profile",
                        subtitle: "Name and avatar"
                    ) {
                        showEditProfile = true
                    }
                }

                // ── 4. About ──────────────────────────────────────────────
                settingsGroup(title: "ABOUT") {
                    chevronRow(
                        icon: "info.circle.fill",
                        iconColor: .blue,
                        title: "About Patente Learning",
                        subtitle: nil
                    ) {
                        showAbout = true
                    }

                    Divider().padding(.leading, 56)

                    infoRow(
                        icon: "car.fill",
                        iconColor: .secondary,
                        title: "Version",
                        value: "1.0.0"
                    )
                }

                // ── 5. Danger Zone ────────────────────────────────────────
                settingsGroup(title: "DATA") {
                    Button {
                        showResetAlert = true
                    } label: {
                        HStack(spacing: 12) {
                            iconBadge("arrow.counterclockwise.circle.fill", color: .red)
                            Text("Reset All Progress")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(Color.appBackground.ignoresSafeArea())
        // ── Sheets & Alerts ───────────────────────────────────────────────
        .sheet(isPresented: $showTimePicker) {
            reminderTimePicker
                .presentationDetents([.height(320)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .alert("Reset All Progress?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                ProgressManager.shared.resetAllProgress()
                XPManager.shared.resetXP()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will erase all learned words, XP, streaks, and progress. This action cannot be undone.")
        }
    }

    // MARK: - Reminder Time Picker Sheet

    private var reminderTimePicker: some View {
        VStack(spacing: 20) {
            Text("Daily Reminder Time")
                .font(.headline)
                .padding(.top, 20)

            Picker("Hour", selection: $reminderHour) {
                ForEach(0..<24, id: \.self) { hour in
                    let formatted = Calendar.current.date(
                        bySettingHour: hour, minute: 0, second: 0, of: Date()
                    ).map { hourFormatter.string(from: $0) } ?? "\(hour):00"
                    Text(formatted).tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: reminderHour) { _ in
                if notificationsEnabled { scheduleNotification() }
            }

            Button("Done") { showTimePicker = false }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundColor(.secondary)
                .tracking(1)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func toggleRow(icon: String, iconColor: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon, color: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func timeRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        Button { showTimePicker = true } label: {
            HStack(spacing: 12) {
                iconBadge(icon, color: iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(formattedReminderTime)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chevronRow(icon: String, iconColor: Color, title: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                iconBadge(icon, color: iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func infoRow(icon: String, iconColor: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(icon, color: iconColor)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func iconBadge(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(color == .secondary ? 0.12 : 1.0))
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color == .secondary ? .secondary : .white)
        }
    }

    // MARK: - Helpers

    private var formattedReminderTime: String {
        let date = Calendar.current.date(
            bySettingHour: reminderHour, minute: 0, second: 0, of: Date()
        ) ?? Date()
        return hourFormatter.string(from: date)
    }

    private var hourFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "hh:00 a"
        return f
    }

    // MARK: - Notification Helpers

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "🚗 Patente Reminder"
            content.body  = "Review a few words today to keep your streak alive!"
            content.sound = .default

            var components = DateComponents()
            components.hour   = reminderHour
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "dailyReminder", content: content, trigger: trigger)
            center.removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
            center.add(request)
        }
    }

    private func removePendingNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["dailyReminder"])
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
    }
}
