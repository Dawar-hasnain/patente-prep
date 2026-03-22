//
//  Patente_LearningApp.swift
//  Patente-Learning
//
//  Entry point. Routes the user to AuthView or MainTabView based on auth state.
//  AuthManager is injected as an @EnvironmentObject so every downstream view
//  can react to sign-in / sign-out without prop drilling.
//

import SwiftUI
import UserNotifications

@main
struct Sorpasso_App: App {

    // AuthManager is initialised once here and lives for the app's lifetime
    @StateObject private var authManager = AuthManager.shared

    init() {
        // Request notification permission early (unchanged from original)
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    print("✅ Notification permission granted")
                } else if let error {
                    print("❌ Notification error: \(error.localizedDescription)")
                }
            }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .preferredColorScheme(.none)   // respects system mode
                .background(Color.appBackground)
        }
    }
}

// MARK: - RootView
//
// Sits above MainTabView and acts as the routing gate.
//
//  First launch:       .unauthenticated + hasCompletedOnboarding == false
//                      → AuthView (sign-in / skip screen)
//
//  Returning user:     .unauthenticated + hasCompletedOnboarding == true
//                      → MainTabView directly (treated as offlineGuest)
//
//  .anonymous /
//  .offlineGuest /
//  .authenticated      → MainTabView (full app)
//
//  .loading            → Splash screen while Supabase resolves the session
//
// AuthManager sets hasCompletedOnboarding=true on skip, sign-in, or any
// successful session restore — so the gate only fires on a true first launch.

private struct RootView: View {

    @EnvironmentObject private var auth: AuthManager

    /// Persisted flag: true once the user has interacted with the auth screen
    /// (either signed in or tapped "Skip for Now"). Never resets.
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            switch auth.authState {

            case .loading:
                splashScreen

            case .unauthenticated:
                if hasCompletedOnboarding {
                    // Returning user with no active session (e.g. token expired).
                    // Drop them straight into the app as an offline guest —
                    // the "Save Progress" prompt will nudge them to sign in later.
                    MainTabView()
                        .environmentObject(auth)
                        .transition(.opacity)
                } else {
                    // True first launch — show the sign-in / skip screen.
                    AuthView()
                        .environmentObject(auth)
                        .transition(.opacity)
                }

            case .anonymous, .offlineGuest, .authenticated:
                MainTabView()
                    .environmentObject(auth)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: auth.authState)
    }

    // MARK: - Splash

    private var splashScreen: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "car.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.accentColor)

                Text("Sorpasso")
                    .font(.system(.title, design: .rounded).weight(.black))

                ProgressView()
                    .padding(.top, 8)
            }
        }
    }
}
