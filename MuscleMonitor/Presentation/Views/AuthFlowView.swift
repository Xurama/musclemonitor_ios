//
//  AuthFlowView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

struct AuthFlowView: View {
    @ObservedObject var session: SessionViewModel
    private let authRepo: AuthRepository
    private let prefsRepo = PreferencesRepositoryImpl()

    @State private var pendingUser: User? = nil

    init(session: SessionViewModel, auth: AuthRepository) {
        self.session = session
        self.authRepo = auth
    }

    var body: some View {
        NavigationStack {
            LoginView(
                vm: LoginViewModel(auth: authRepo) { user in
                    // Si l'utilisateur a déjà des prefs -> direct home
                    if prefsRepo.load(for: user.id) != nil {
                        session.setAuthenticated(user)
                    } else {
                        pendingUser = user
                    }
                }
            )
            .toolbar {
                NavigationLink("create_account") {
                    RegisterView(
                        vm: RegisterViewModel(auth: authRepo) { user in
                            // Après register, on force le passage par préférences
                            pendingUser = user
                        }
                    )
                }
            }
            .navigationDestination(item: $pendingUser) { user in
                UserPreferencesView(user: user, repo: prefsRepo) {
                    // après save -> connecter et revenir à Home
                    session.setAuthenticated(user)
                    pendingUser = nil
                }
            }
        }
    }
}


