//
//  OpenFoodFactsService.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 31/12/2025.
//


import Foundation
import OpenFoodFactsSDK

class OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    
    func fetchProduct(barcode: String) async -> FoodItem? {
        let client = URLSession.shared
        // On utilise l'API de test ou de prod d'OpenFoodFacts
        let urlString = "https://world.openfoodfacts.org/api/v2/product/\(barcode).json"
        
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let (data, _) = try await client.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let product = json?["product"] as? [String: Any] else { return nil }
            
            let name = product["product_name"] as? String ?? "Produit inconnu"
            let nutriments = product["nutriments"] as? [String: Any]
            
            // OFF donne les valeurs pour 100g par défaut
            return FoodItem(
                name: name,
                kcal: Int(nutriments?["energy-kcal_100g"] as? Double ?? 0),
                protein: nutriments?["proteins_100g"] as? Double ?? 0,
                carbs: nutriments?["carbohydrates_100g"] as? Double ?? 0,
                fat: nutriments?["fat_100g"] as? Double ?? 0
            )
        } catch {
            print("Erreur OFF: \(error)")
            return nil
        }
    }
}
