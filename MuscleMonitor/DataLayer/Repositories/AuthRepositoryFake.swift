//
//  AuthRepositoryFake.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import Foundation

final class AuthRepositoryFake: AuthRepository {

    private var usersByName: [String: (id: String, password: String)] = [:]
    private var current: User? = nil

    func currentUser() -> User? { current }

    func login(name: String, password: String) async throws -> User {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let entry = usersByName[key], entry.password == password else {
            throw NSError(domain: "auth", code: 401,
                          userInfo: [NSLocalizedDescriptionKey: "Identifiants invalides"])
        }
        let user = User(id: entry.id, name: name)
        current = user
        try? await Task.sleep(nanoseconds: 300_000_000) // latence simulée
        return user
    }

    func register(name: String, password: String) async throws -> User {
        let key = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if usersByName[key] != nil {
            throw NSError(domain: "auth", code: 409,
                          userInfo: [NSLocalizedDescriptionKey: "Nom déjà utilisé"])
        }
        let id = UUID().uuidString
        usersByName[key] = (id: id, password: password)
        let user = User(id: id, name: name)
        current = user
        try? await Task.sleep(nanoseconds: 300_000_000)
        return user
    }

    func logout() async {
        current = nil
        try? await Task.sleep(nanoseconds: 150_000_000)
    }
}
