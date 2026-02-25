//
//  RegisterViewModel.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

@MainActor
final class RegisterViewModel: ObservableObject {
    @Published var name = ""
    @Published var password = ""
    @Published var confirm = ""
    @Published var isLoading = false
    @Published var error: String?

    private let auth: AuthRepository
    private let onRegistered: (User) -> Void

    init(auth: AuthRepository, onRegistered: @escaping (User) -> Void) {
        self.auth = auth
        self.onRegistered = onRegistered
    }

    func register() {
        error = nil
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { error = "Nom requis"; return }
        guard password.count >= 6 else { error = "Mot de passe ≥ 6 caractères"; return }
        guard password == confirm else { error = "Les mots de passe ne correspondent pas"; return }

        isLoading = true
        Task {
            do {
                let user = try await auth.register(name: name, password: password)
                onRegistered(user)
            } catch {
                self.error = error.localizedDescription
            }
            isLoading = false
        }
    }
}
