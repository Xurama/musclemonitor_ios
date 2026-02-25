//
//  CalorieRepository.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 02/10/2025.
//

import Foundation

public protocol CalorieRepository {
    func loadAll() async throws -> [CalorieEntry]
    func saveAll(_ entries: [CalorieEntry]) async throws
}

// MARK: - Local JSON impl

public final class CalorieRepositoryLocal: CalorieRepository {
    private let fileURL: URL

    public init(filename: String = "calories.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent(filename)
    }

    public func loadAll() async throws -> [CalorieEntry] {
        // Si le fichier n'existe pas, retourne un tableau vide
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            // Fichier vide -> []
            if data.isEmpty { return [] }
            return try JSONDecoder().decode([CalorieEntry].self, from: data)
        } catch {
            // En cas de JSON corrompu, on choisit de repartir propre
            // (tu peux remonter l'erreur si tu préfères)
            print("[Calories] decode error: \(error)")
            return []
        }
    }

    public func saveAll(_ entries: [CalorieEntry]) async throws {
        // S'assure que le dossier existe
        try ensureParentDirectoryExists(for: fileURL)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys] // <- OptionSet clair
        let data = try encoder.encode(entries)
        try data.write(to: fileURL, options: .atomic) // Data.WritingOptions.atomic
    }

    // MARK: - Helpers

    private func ensureParentDirectoryExists(for url: URL) throws {
        let dir = url.deletingLastPathComponent()
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(atPath: dir.path, isDirectory: &isDir) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
