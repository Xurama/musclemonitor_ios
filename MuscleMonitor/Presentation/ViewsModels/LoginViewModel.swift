//
//  LoginViewModel.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var name = ""
    @Published var password = ""
    @Published var isLoading = false
    @Published var error: String?

    private let auth: AuthRepository
    private let onLoggedIn: (User) -> Void

    init(auth: AuthRepository, onLoggedIn: @escaping (User) -> Void) {
        self.auth = auth
        self.onLoggedIn = onLoggedIn
    }

    func login() {
        error = nil
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            error = "Nom requis."
            return
        }
        guard password.count >= 6 else {
            error = "Mot de passe ≥ 6 caractères."
            return
        }

        isLoading = true
        Task {
            do {
                let user = try await auth.login(name: name, password: password)
                onLoggedIn(user)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
