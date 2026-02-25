//
//  CalorieKind.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 02/10/2025.
//

import Foundation

// MARK: - Enums

public enum CalorieKind: String, Codable, CaseIterable, Identifiable {
    case intake, burn, water
    public var id: String { rawValue }
}

public enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Petit-déjeuner"
    case lunch = "Déjeuner"
    case snack = "Collation / Goûter"
    case dinner = "Dîner"
    
    public var id: String { rawValue }
}

// MARK: - Models

/// Représente un aliment précis avec ses macros
public struct FoodItem: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var kcal: Int
    public var protein: Double
    public var carbs: Double
    public var fat: Double
    
    public var portionName: String? // ex: "œuf", "cuillère à soupe"
    public var portionWeight: Double? // ex: 50.0 (pour un œuf)
    
    public init(id: UUID = UUID(), name: String, kcal: Int, protein: Double, carbs: Double, fat: Double) {
        self.id = id
        self.name = name
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
    }
}

/// Structure globale pour les entrées caloriques (Repas ou Dépense)
public struct CalorieEntry: Identifiable, Codable, Hashable {
    public let id: UUID
    public var date: Date
    public var kind: CalorieKind
    
    // Pour les dépenses (burn) ou entrées simples
    public var kcal: Int
    public var note: String?
    
    // Pour les repas structurés (intake)
    public var mealType: MealType?
    public var foodItems: [FoodItem]?
    
    public var waterML: Int?

    // MARK: - Computed Properties
    
    /// Calcule le total des kcal si c'est un repas avec des aliments, sinon retourne la valeur kcal simple
    public var totalKcal: Int {
        if let items = foodItems, !items.isEmpty {
            return items.reduce(0) { $0 + $1.kcal }
        }
        return kcal
    }
    
    public var totalProtein: Double {
        foodItems?.reduce(0) { $0 + $1.protein } ?? 0.0
    }
    
    public var totalCarbs: Double {
        foodItems?.reduce(0) { $0 + $1.carbs } ?? 0.0
    }
    
    public var totalFat: Double {
        foodItems?.reduce(0) { $0 + $1.fat } ?? 0.0
    }

    // MARK: - Init
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: CalorieKind,
        kcal: Int = 0,
        note: String? = nil,
        mealType: MealType? = nil,
        foodItems: [FoodItem]? = nil,
        waterML: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.kcal = kcal
        self.note = note
        self.mealType = mealType
        self.foodItems = foodItems
        self.waterML = waterML
    }
}

// MARK: - Extensions

extension Date {
    var startOfDayLocal: Date { Calendar.current.startOfDay(for: self) }
    var endOfDayLocal: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDayLocal)!
    }
}
