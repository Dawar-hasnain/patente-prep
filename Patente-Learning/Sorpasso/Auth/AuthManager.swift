//
//  AuthManager.swift
//  Patente-Learning
//
//  Central auth state machine.
//  Manages three sign-in paths:
//    1. Sign in with Apple   → native sheet, Supabase idToken exchange
//    2. Sign in with Google  → Supabase OAuth via ASWebAuthenticationSession
//    3. Skip for Now         → Supabase anonymous session (user still gets a UUID,
//                               enabling future League participation on sign-in)
//
//  Offline resilience: if anonymous sign-in fails due to no connectivity, the app
//  degrades gracefully to .offlineGuest — everything still works via UserDefaults.
//

import Foundation
import Supabase
import AuthenticationServices
import Combine

// MARK: - Auth State

enum AuthState: Equatable {
    /// App just launched; checking for an existing Supabase session.
    case loading
    /// No session at all (fresh install, never opened auth).
    case unauthenticated
    /// Signed in anonymously ("Skip for Now"). Has a Supabase user_id but no identity.
    case anonymous
    /// Fully authenticated with Apple or Google.
    case authenticated
    /// No internet when the user tapped "Skip" — app works locally only.
    case offlineGuest
}

// MARK: - AuthManager

@MainActor
final class AuthManager: ObservableObject {

    // MARK: - Singleton
    static let shared = AuthManager()

    // MARK: - Published state
    @Published private(set) var authState: AuthState = .loading
    @Published private(set) var userID: UUID?
    @Published private(set) var userEmail: String?
    @Published private(set) var displayName: String?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    // MARK: - Private
    private var appleCoordinator: AppleSignInCoordinator?
    private var googleWebSession: ASWebAuthenticationSession?
    private var stateListenerTask: Task<Void, Never>?

    // MARK: - Init
    private init() {
        listenToAuthChanges()
    }

    deinit {
        stateListenerTask?.cancel()
    }

    // MARK: - Computed helpers

    /// True when the user is a guest (anonymous or offline) — used to show "Save Progress" prompts.
    var isGuest: Bool {
        authState == .anonymous || authState == .offlineGuest
    }

    /// True once a session of any kind is established (app can proceed to MainTabView).
    var isSessionReady: Bool {
        authState != .loading && authState != .unauthenticated
    }

    // MARK: - Listen to Supabase auth changes

    private func listenToAuthChanges() {
        stateListenerTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in await supabaseClient.auth.authStateChanges {
                await MainActor.run {
                    switch event {
                    case .initialSession:
                        if let session {
                            self.applySession(session)
                        } else {
                            self.authState = .unauthenticated
                        }

                    case .signedIn:
                        if let session {
                            self.applySession(session)
                        }

                    case .signedOut:
                        self.authState = .unauthenticated
                        self.userID = nil
                        self.userEmail = nil
                        self.displayName = nil

                    case .userUpdated:
                        if let session {
                            self.applySession(session)
                        }

                    default:
                        break
                    }
                }
            }
        }
    }

    /// Maps a Supabase Session onto local state and marks onboarding complete.
    private func applySession(_ session: Session) {
        let user = session.user
        userID    = user.id
        userEmail = user.email

        // Anonymous users have no email/phone and no linked identities
        let isAnon = user.email == nil && user.phone == nil && (user.identities ?? []).isEmpty
        authState  = isAnon ? .anonymous : .authenticated

        // Try to build a display name from user metadata
        let meta = user.userMetadata
        if let name = meta["full_name"]?.stringValue ?? meta["name"]?.stringValue {
            displayName = name
        }

        // Mark onboarding done — auth screen will never show again after this point
        markOnboardingComplete()
    }

    // MARK: - Skip for Now (anonymous)

    /// Creates an anonymous Supabase session.
    /// Falls back to .offlineGuest if there's no internet connection.
    func continueAsGuest() async {
        isLoading = true
        defer { isLoading = false }

        // Mark onboarding complete immediately — the user made a deliberate choice
        markOnboardingComplete()

        do {
            let session = try await supabaseClient.auth.signInAnonymously()
            applySession(session)
        } catch {
            // Graceful offline degradation — the app still works via UserDefaults
            print("⚠️ Anonymous sign-in failed (no internet?). Running as offline guest: \(error)")
            authState = .offlineGuest
        }
    }

    // MARK: - Onboarding gate

    /// Writes the persistent flag that prevents AuthView from showing on subsequent launches.
    /// Called automatically by applySession(_:) and continueAsGuest().
    private func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Sign in with Apple

    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Keep coordinator alive for the duration of the async flow
        let coordinator = AppleSignInCoordinator()
        appleCoordinator = coordinator

        do {
            let result = try await coordinator.signIn()

            let session = try await supabaseClient.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken:  result.idToken,
                    nonce:    result.rawNonce
                )
            )
            applySession(session)

            // Persist display name if Apple provided one on first sign-in
            if let components = result.fullName {
                let name = PersonNameComponentsFormatter().string(from: components)
                if !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    displayName = name
                    UserDefaults.standard.set(name, forKey: "userName")
                }
            }

        } catch let error as ASAuthorizationError where error.code == .canceled {
            // User dismissed the sheet — not an error we surface
            print("ℹ️ Apple sign-in cancelled by user.")
        } catch {
            errorMessage = "Apple sign-in failed. Please try again."
            print("❌ Apple sign-in error: \(error)")
        }

        appleCoordinator = nil
    }

    // MARK: - Sign in with Google (Supabase OAuth via ASWebAuthenticationSession)
    //
    // Flow:
    //  1. Build the Supabase Google OAuth URL.
    //  2. Open it in ASWebAuthenticationSession (no app-switch, stays in-process).
    //  3. The session catches the patente-learning:// deep-link callback automatically.
    //  4. Pass that callback URL to supabase.auth.session(from:) to exchange tokens.
    //
    // ⚠️ Prerequisite: add URL scheme "patente-learning" in Xcode → Target → Info → URL Types

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // 1. Ask Supabase for the OAuth entry-point URL
            let oauthURL = try await supabaseClient.auth.getOAuthSignInURL(
                provider: .google,
                redirectTo: URL(string: "patente-learning://login-callback")
            )

            // 2. Open in ASWebAuthenticationSession and await the callback URL
            let callbackURL: URL = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(
                    url: oauthURL,
                    callbackURLScheme: "patente-learning"
                ) { callbackURL, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let callbackURL else {
                        continuation.resume(throwing: GoogleSignInError.missingCallbackURL)
                        return
                    }
                    continuation.resume(returning: callbackURL)
                }
                session.prefersEphemeralWebBrowserSession = true
                session.presentationContextProvider       = GoogleSignInContextProvider.shared
                session.start()
                self.googleWebSession = session
            }

            // 3. Exchange the callback URL for a Supabase session
            try await supabaseClient.auth.session(from: callbackURL)

        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            print("ℹ️ Google sign-in cancelled by user.")
        } catch {
            errorMessage = "Google sign-in failed. Please try again."
            print("❌ Google sign-in error: \(error)")
        }

        googleWebSession = nil
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabaseClient.auth.signOut()
        } catch {
            print("❌ Sign-out error: \(error)")
        }
    }
}

// MARK: - Google ASWebAuthenticationSession Context Provider

/// Provides the UIWindow anchor required by ASWebAuthenticationSession.
/// Implemented as a lightweight singleton to avoid coupling AuthManager to UIKit.
private final class GoogleSignInContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = GoogleSignInContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? UIWindow()
    }
}

// MARK: - Errors

enum GoogleSignInError: LocalizedError {
    case missingCallbackURL

    var errorDescription: String? {
        "Google sign-in did not return a valid callback URL."
    }
}

// MARK: - AnyJSON convenience

private extension AnyJSON {
    /// Safely extracts a String value from AnyJSON without crashing.
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }
}
