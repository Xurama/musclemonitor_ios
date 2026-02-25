import SwiftUI

// RootView.swift — MISE À JOUR

import SwiftUI

struct RootView: View {
    @ObservedObject var session: SessionViewModel
    let authRepo: AuthRepository
    let workoutsRepo: WorkoutRepository
    let exercisesRepo: ExerciseCatalogRepository
    let sessionRepo: WorkoutSessionRepository
    let calorieRepo: CalorieRepository

    @AppStorage("username") private var storedName: String?
    @AppStorage("userId")   private var storedId: String?
    private let prefsRepo = PreferencesRepositoryImpl()

    @State private var pendingUserForBody: User? = nil

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(item: $pendingUserForBody) { user in
                    BodyProfileOnboardingView(user: user, repo: prefsRepo) {
                        session.user = user
                        pendingUserForBody = nil
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if session.user != nil {
            WorkoutsHomeView(
                session: session,
                workoutsRepo: workoutsRepo,
                exercisesRepo: exercisesRepo,
                sessionRepo: sessionRepo,
                calorieRepo: calorieRepo,
                prefsRepo: prefsRepo
            )
        } else if let name = storedName {
            // Auto-login soft + route vers home
            WorkoutsHomeView(
                session: session,
                workoutsRepo: workoutsRepo,
                exercisesRepo: exercisesRepo,
                sessionRepo: sessionRepo,
                calorieRepo: calorieRepo,
                prefsRepo: prefsRepo
            )
            .task { @MainActor in
                if session.user == nil {
                    let id = storedId ?? UUID().uuidString
                    if storedId == nil { storedId = id }
                    session.user = User(id: id, name: name)
                }
            }
        } else {
            OnboardingNameView { user in
                storedName = user.name
                storedId   = user.id
                // 👉 Nouvelle étape après le nom
                pendingUserForBody = user
            }
        }
    }

    // inchangé
    private struct OnboardingNameView: View {
        @State private var name: String = ""
        let onDone: (User) -> Void
        var body: some View {
            VStack(spacing: 20) {
                Text("welcome").font(.largeTitle).bold()
                TextField("your_name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit { saveIfValid() }
                Button("next") { saveIfValid() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        private func saveIfValid() {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let normalized = String(trimmed.prefix(32))
            let user = User(id: UUID().uuidString, name: normalized)
            UserDefaults.standard.set(normalized, forKey: "username")
            UserDefaults.standard.set(user.id, forKey: "userId")
            onDone(user)
        }
    }
}
