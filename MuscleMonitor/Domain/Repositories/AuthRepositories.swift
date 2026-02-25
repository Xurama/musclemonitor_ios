//
//  AuthRepositories.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

public protocol AuthRepository {
    func currentUser() -> User?
    func login(name: String, password: String) async throws -> User
    func register(name: String, password: String) async throws -> User
    func logout() async
}

