//
//  FoodRepository.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 31/12/2025.
//


import Foundation

public protocol FoodRepository {
    func loadCatalog() async throws -> [FoodItem]
    func addToCatalog(_ item: FoodItem) async throws
}

public final class FoodRepositoryLocal: FoodRepository {
    private let fileURL: URL

    public init(filename: String = "food_catalog.json") {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent(filename)
    }

    public func loadCatalog() async throws -> [FoodItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([FoodItem].self, from: data)
    }

    public func addToCatalog(_ item: FoodItem) async throws {
        var catalog = try await loadCatalog()
        // On évite les doublons par nom
        if !catalog.contains(where: { $0.name == item.name }) {
            catalog.append(item)
            let data = try JSONEncoder().encode(catalog)
            try data.write(to: fileURL, options: .atomic)
        }
    }
}