//
//  WorkoutSessionRepositoryLocal.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 23/09/2025.
//


import Foundation

final class WorkoutSessionRepositoryLocal: WorkoutSessionRepository {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "WorkoutSessionRepositoryLocal")

    init(filename: String = "workout_sessions.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent(filename)
    }

    func add(_ session: WorkoutSession) async throws {
        var all = try await list()
        all.append(session)
        try await persist(all)
    }

    func list() async throws -> [WorkoutSession] {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
                        cont.resume(returning: [])
                        return
                    }
                    let data = try Data(contentsOf: self.fileURL)
                    let items = try JSONDecoder().decode([WorkoutSession].self, from: data)
                    cont.resume(returning: items)
                } catch {
                    print("[MM] decode ERROR:", error)
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func delete(id: String) async throws {
        var all = try await list()
        all.removeAll { $0.id == id }
        try await persist(all)
    }

    func clearAll() async throws {
        try await persist([])
    }

    // MARK: - Persist
    private func persist(_ list: [WorkoutSession]) async throws {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    let data = try JSONEncoder().encode(list)
                    try data.write(to: self.fileURL, options: [.atomic])
                    cont.resume()
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
}
