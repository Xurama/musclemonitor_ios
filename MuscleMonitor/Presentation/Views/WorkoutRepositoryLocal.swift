//
//  WorkoutRepositoryLocal.swift
//  MuscleMonitor
//
//  Created by AI Assistant on 18/09/2025
//

// WorkoutRepositoryLocal.swift
import Foundation

final class WorkoutRepositoryLocal: WorkoutRepository {
    private let fileURL: URL
    private let queue = DispatchQueue(label: "WorkoutRepositoryLocal")

    init(userId: String, filename: String = "workouts.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = docs.appendingPathComponent("users/\(userId)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        self.fileURL = folder.appendingPathComponent(filename)
        print("[MM][Workouts] file url:", fileURL.path)
    }

    func list() async throws -> [Workout] {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
                        print("[MM][Workouts] file missing -> []")
                        cont.resume(returning: [])
                        return
                    }
                    let data = try Data(contentsOf: self.fileURL)

                    // 1) Tentative avec un décodeur tolérant
                    let decoder = Self.makeTolerantDecoder()
                    do {
                        let items = try decoder.decode([Workout].self, from: data)
                        print("[MM][Workouts] decoded items:", items.count)
                        cont.resume(returning: items)
                    } catch {
                        // 2) Deuxième tentative (fallback Foundation “deferredToDate”)
                        print("[MM][Workouts] tolerant decode failed:", error)
                        let fallback = JSONDecoder() // deferredToDate par défaut
                        do {
                            let items = try fallback.decode([Workout].self, from: data)
                            print("[MM][Workouts] fallback decoded items:", items.count)
                            cont.resume(returning: items)
                        } catch {
                            print("[MM][Workouts] decode ERROR (fallback):", error)
                            cont.resume(throwing: error)
                        }
                    }
                } catch {
                    print("[MM][Workouts] read ERROR:", error)
                    cont.resume(throwing: error)
                }
            }
        }
    }

    func add(_ workout: Workout) async throws {
        var all = try await list()
        all.append(workout)
        try await persist(all)
    }

    func update(_ workout: Workout) async throws {
        var all = try await list()
        if let idx = all.firstIndex(where: { $0.id == workout.id }) {
            all[idx] = workout
        }
        try await persist(all)
    }

    func delete(id: String) async throws {
        var all = try await list()
        all.removeAll { $0.id == id }
        try await persist(all)
    }

    // MARK: - Persist
    private func persist(_ list: [Workout]) async throws {
        try await withCheckedThrowingContinuation { cont in
            queue.async {
                do {
                    let enc = JSONEncoder()
                    enc.outputFormatting = [.prettyPrinted, .sortedKeys]
                    // Choisis un format unique pour l’avenir (ISO-8601 lisible)
                    enc.dateEncodingStrategy = .iso8601
                    let data = try enc.encode(list)
                    try data.write(to: self.fileURL, options: [.atomic])
                    cont.resume()
                } catch {
                    print("[MM][Workouts] persist ERROR:", error)
                    cont.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers
    private static func makeTolerantDecoder() -> JSONDecoder {
        let dec = JSONDecoder()
        // Essaye d’abord ISO-8601 (très courant si tu as déjà switché un jour)
        dec.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            // 1) try ISO-8601 string
            if let str = try? container.decode(String.self) {
                // essaye ISO8601DateFormatter d’abord
                let iso = ISO8601DateFormatter()
                if let d = iso.date(from: str) { return d }
                // essaye quelques formats usuels (si tu avais custom)
                let fmts = [
                    "yyyy-MM-dd'T'HH:mm:ssXXXXX",
                    "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX",
                    "yyyy-MM-dd"
                ]
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                for f in fmts {
                    df.dateFormat = f
                    if let d = df.date(from: str) { return d }
                }
                // si c'est une string mais pas une date -> on laisse tomber plus bas
            }
            // 2) fallback: nombre (timestamp)
            if let ts = try? container.decode(Double.self) {
                // Foundation encode par défaut des secondes depuis 2001 (reference date)
                // Impossible de détecter à 100%, on suppose "since 2001" si la valeur est “petite”
                // Si tu sais que tu utilisais "since 1970", adapte la logique ici.
                // Heuristique simple: si > 200_000_000_000 alors ms depuis 1970
                if ts > 200_000_000_000 {
                    return Date(timeIntervalSince1970: ts / 1000.0)
                } else if ts > 10_000_000_000 {
                    return Date(timeIntervalSince1970: ts)
                } else {
                    return Date(timeIntervalSinceReferenceDate: ts)
                }
            }
            // 3) si rien ne marche, laisse le décodage par défaut
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported date format")
        }
        return dec
        // NB: on n’active pas keyDecodingStrategy ici, on garde les clés exactes
    }
}
