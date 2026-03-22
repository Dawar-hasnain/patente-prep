//
//  AuthView.swift
//  Patente-Learning
//
//  Duolingo-inspired onboarding / sign-in screen.
//  Works both as the initial full-screen launch gate and as a sheet
//  presented from SaveProgressPromptView.
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {

    // MARK: - Environment
    @EnvironmentObject private var auth: AuthManager

    // MARK: - State
    @State private var animateHero     = false
    @State private var animateButtons  = false
    @State private var showErrorBanner = false

    /// When true this view was presented as a sheet (from the "Save Progress" prompt),
    /// so we show an X dismiss button and slightly different copy.
    var isPresentedAsSheet: Bool = false
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────────
            LinearGradient(
                colors: [Color.blue.opacity(0.85), Color.blue.opacity(0.55), Color.appBackground],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            Color.appBackground
                .ignoresSafeArea(edges: .bottom)

            // ── Content ─────────────────────────────────────────────────────
            VStack(spacing: 0) {

                // Dismiss button (sheet mode only)
                if isPresentedAsSheet {
                    HStack {
                        Spacer()
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 16)
                    }
                }

                heroSection
                    .padding(.top, isPresentedAsSheet ? 8 : 52)

                Spacer(minLength: 24)

                featureList
                    .padding(.horizontal, 28)
                    .offset(y: animateButtons ? 0 : 30)
                    .opacity(animateButtons ? 1 : 0)

                Spacer(minLength: 20)

                buttonStack
                    .padding(.horizontal, 24)
                    .offset(y: animateButtons ? 0 : 40)
                    .opacity(animateButtons ? 1 : 0)

                skipButton
                    .padding(.bottom, 36)
                    .opacity(animateButtons ? 1 : 0)
            }

            // ── Error banner ─────────────────────────────────────────────────
            if showErrorBanner, let msg = auth.errorMessage {
                VStack {
                    errorBanner(msg)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.1)) {
                animateHero = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                animateButtons = true
            }
        }
        .onChange(of: auth.errorMessage) { msg in
            guard msg != nil else { return }
            withAnimation(.spring()) { showErrorBanner = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                withAnimation { showErrorBanner = false }
                auth.errorMessage = nil
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 14) {
            // App logo / mascot placeholder — swap for your real asset
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "car.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
            }
            .scaleEffect(animateHero ? 1.0 : 0.6)
            .opacity(animateHero ? 1.0 : 0.0)

            Text(isPresentedAsSheet ? "Save Your Progress" : "Sorpasso")
                .font(.system(.title, design: .rounded).weight(.black))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                .scaleEffect(animateHero ? 1.0 : 0.85)
                .opacity(animateHero ? 1.0 : 0.0)

            Text(isPresentedAsSheet
                 ? "Sign in so you never lose your streak or chapter progress."
                 : "Master Italian road rules.\nPass the Patente exam with confidence.")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(animateHero ? 1.0 : 0.0)
        }
    }

    // MARK: - Feature bullets

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow(icon: "arrow.triangle.2.circlepath",
                       color: .green,
                       text: "Sync progress across all your devices")
            featureRow(icon: "trophy.fill",
                       color: .yellow,
                       text: "Compete in the League leaderboard")
            featureRow(icon: "flame.fill",
                       color: .orange,
                       text: "Never lose your learning streak")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .cornerRadius(18)
    }

    private func featureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3.weight(.semibold))
                .frame(width: 28)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Buttons

    private var buttonStack: some View {
        VStack(spacing: 12) {

            // ── Apple ────────────────────────────────────────────────────────
            Button {
                Task { await auth.signInWithApple() }
            } label: {
                HStack(spacing: 10) {
                    if auth.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(width: 20, height: 20)
                    } else {
                        Image(systemName: "apple.logo")
                            .font(.body.weight(.semibold))
                    }
                    Text("Continue with Apple")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.black)
                .cornerRadius(14)
            }
            .disabled(auth.isLoading)

            // ── Google ───────────────────────────────────────────────────────
            Button {
                Task { await auth.signInWithGoogle() }
            } label: {
                HStack(spacing: 10) {
                    if auth.isLoading {
                        ProgressView()
                            .tint(.primary)
                            .frame(width: 20, height: 20)
                    } else {
                        Image("googleIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    Text("Continue with Google")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                )
            }
            .disabled(auth.isLoading)
        }
    }

    // MARK: - Skip button

    private var skipButton: some View {
        Button {
            Task { await auth.continueAsGuest() }
        } label: {
            HStack(spacing: 4) {
                Text("Skip for now")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 12)
        }
        .disabled(auth.isLoading)
        .padding(.top, 4)
    }

    // MARK: - Error banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)
            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.red.opacity(0.9))
        .padding(.top, 1) // avoids safe-area clip
    }
}

// MARK: - Preview

#Preview {
    AuthView()
        .environmentObject(AuthManager.shared)
}
