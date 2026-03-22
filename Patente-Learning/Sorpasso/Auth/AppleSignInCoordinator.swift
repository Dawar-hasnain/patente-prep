//
//  AppleSignInCoordinator.swift
//  Patente-Learning
//
//  Handles the ASAuthorizationController delegate callbacks for Sign in with Apple.
//  Generates and manages the cryptographic nonce required by Supabase to verify the
//  Apple identity token hasn't been tampered with.
//

import Foundation
import AuthenticationServices
import CryptoKit

// MARK: - Result type
struct AppleSignInResult {
    let idToken: String
    let rawNonce: String
    let fullName: PersonNameComponents?
    let email: String?
}

// MARK: - Coordinator
/// Bridges UIKit-style ASAuthorizationController delegates into async/await.
/// Keep a strong reference to this object for the duration of the sign-in flow.
@MainActor
final class AppleSignInCoordinator: NSObject {

    // Stored completion so the delegate callbacks can resume the continuation
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var currentRawNonce: String?

    // MARK: - Public entry point
    /// Kicks off the native Apple Sign-In sheet and returns the result asynchronously.
    func signIn() async throws -> AppleSignInResult {
        let rawNonce   = randomNonceString()
        let hashedNonce = sha256(rawNonce)
        currentRawNonce = rawNonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate                  = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    // MARK: - Nonce helpers
    /// Generates a random URL-safe nonce string of the given length.
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            for random in randoms {
                if remainingLength == 0 { break }
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        return result
    }

    /// SHA-256 hashes the raw nonce — sent to Apple, not to Supabase.
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed    = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData  = credential.identityToken,
            let idToken    = String(data: tokenData, encoding: .utf8),
            let rawNonce   = currentRawNonce
        else {
            continuation?.resume(throwing: AppleSignInError.missingToken)
            continuation = nil
            return
        }

        let result = AppleSignInResult(
            idToken:  idToken,
            rawNonce: rawNonce,
            fullName: credential.fullName,
            email:    credential.email
        )
        continuation?.resume(returning: result)
        continuation = nil
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? UIWindow()
    }
}

// MARK: - Errors
enum AppleSignInError: LocalizedError {
    case missingToken
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingToken: return "Apple sign-in did not return a valid identity token."
        case .cancelled:    return "Apple sign-in was cancelled."
        }
    }
}
