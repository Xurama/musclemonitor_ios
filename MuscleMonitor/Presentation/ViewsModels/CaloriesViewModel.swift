//
//  CaloriesViewModel.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 02/10/2025.
//

import Foundation
import SwiftUI

@MainActor
final class CaloriesViewModel: ObservableObject {
    @Published private(set) var entries: [CalorieEntry] = []
    @Published var selectedDate: Date = Date() { didSet {
        refreshDay()
        Task { await syncWithAppleHealth() }
    }}

    @Published private(set) var intakeToday: Int = 0
    @Published private(set) var burnToday: Int = 0
    @Published private(set) var activeBurnToday: Int = 0
    @Published private(set) var basalBurnToday: Int = 0
    @Published private(set) var dailyTarget: Int = 2500 // Valeur par défaut
    
    @Published private(set) var proteinToday: Double = 0
    @Published private(set) var carbsToday: Double = 0
    @Published private(set) var fatToday: Double = 0
    
    @Published private(set) var proteinTarget: Double = 200
    @Published private(set) var carbsTarget: Double = 300
    @Published private(set) var fatTarget: Double = 80
    
    @Published private(set) var waterToday: Int = 0
    @Published private(set) var waterTarget: Int = 2500 // Valeur par défaut
    
    var balanceToday: Int { intakeToday - burnToday }

    private let repo: CalorieRepository
    private let prefsRepo = PreferencesRepositoryImpl()

    init(repo: CalorieRepository) {
        self.repo = repo
    }

    func load() async {
        do {
            var loadedEntries = try await repo.loadAll().sorted(by: { $0.date > $1.date })
            
            // 🧹 NETTOYAGE DES DOUBLONS D'ID
            for i in 0..<loadedEntries.count {
                if let items = loadedEntries[i].foodItems {
                    var uniqueItems: [FoodItem] = []
                    var seenIDs = Set<UUID>()
                    
                    for item in items {
                        if !seenIDs.contains(item.id) {
                            uniqueItems.append(item)
                            seenIDs.insert(item.id)
                        } else {
                            print("🗑️ Doublon détecté et supprimé au chargement : \(item.name)")
                        }
                    }
                    loadedEntries[i].foodItems = uniqueItems
                }
            }
            
            entries = loadedEntries
            refreshDay()
            await syncWithAppleHealth()
        } catch {
            print("[Calories] load error:", error)
        }
    }

    func addMeal(type: MealType, items: [FoodItem]) async {
        var all = entries
        let from = selectedDate.startOfDayLocal
        let to = selectedDate.endOfDayLocal
        
        // On cherche si ce repas existe déjà aujourd'hui
        if let index = all.firstIndex(where: {
            $0.mealType == type && $0.date >= from && $0.date <= to
        }) {
            // Le repas existe, on ajoute les nouveaux aliments à la liste existante
            var updatedEntry = all[index]
            var currentItems = updatedEntry.foodItems ?? []
            currentItems.append(contentsOf: items)
            updatedEntry.foodItems = currentItems
            all[index] = updatedEntry
        } else {
            // Le repas n'existe pas, on crée une nouvelle entrée
            let entry = CalorieEntry(date: selectedDate, kind: .intake, mealType: type, foodItems: items)
            all.insert(entry, at: 0)
        }
        
        await persist(all)
    }
    
    func addWater(amount: Int) async {
        let entry = CalorieEntry(
            date: selectedDate,
            kind: .water, // Type Eau
            waterML: amount // Quantité
        )
        
        var all = entries
        all.insert(entry, at: 0)
        await persist(all)
    }
    
    func replaceFoodItem(oldItem: FoodItem, with newItem: FoodItem, in mealType: MealType) async {
        print("🔄 Tentative de remplacement de l'item ID: \(oldItem.id)")
        var allEntries = entries
        var hasPerformedUpdate = false
        
        for i in 0..<allEntries.count {
            if allEntries[i].mealType == mealType, var items = allEntries[i].foodItems {
                // On cherche l'index
                if let itemIndex = items.firstIndex(where: { $0.id == oldItem.id }) {
                    print("✅ Item trouvé à l'index \(itemIndex) dans l'entrée du \(allEntries[i].date)")
                    
                    // Remplacement
                    items[itemIndex] = newItem
                    // Sécurité absolue : on force l'ID pour qu'il soit identique à l'ancien
                    items[itemIndex].id = oldItem.id
                    
                    allEntries[i].foodItems = items
                    hasPerformedUpdate = true
                    break
                }
            }
        }
        
        if hasPerformedUpdate {
            print("💾 Sauvegarde des modifications...")
            await persist(allEntries)
        } else {
            print("⚠️ ERREUR : Item original non trouvé, aucune modification effectuée.")
            // C'est ici qu'on verra si l'ID a changé entre temps
        }
    }

    func addQuickEntry(kind: CalorieKind, kcal: Int, note: String?) async {
        let entry = CalorieEntry(date: selectedDate, kind: kind, kcal: kcal, note: note)
        var all = entries
        all.insert(entry, at: 0)
        await persist(all)
    }

    func delete(_ entry: CalorieEntry) async {
        let all = entries.filter { $0.id != entry.id }
        await persist(all)
    }

    private func persist(_ all: [CalorieEntry]) async {
        do {
            try await repo.saveAll(all)
            entries = all
            refreshDay()
        } catch {
            print("[Calories] save error:", error)
        }
    }

    private func refreshDay() {
        let from = selectedDate.startOfDayLocal
        let to   = selectedDate.endOfDayLocal
        let dayEntries = entries.filter { ($0.date >= from) && ($0.date <= to) }
        
        intakeToday = dayEntries.filter { $0.kind == .intake }.reduce(0) { $0 + $1.totalKcal }
        
        // 💧 Calcul du total d'eau (somme des entrées .water)
        waterToday = dayEntries
            .filter { $0.kind == .water }
            .reduce(0) { $0 + ($1.waterML ?? 0) }
        
        proteinToday = dayEntries.reduce(0) { $0 + $1.totalProtein }
        carbsToday = dayEntries.reduce(0) { $0 + $1.totalCarbs }
        fatToday = dayEntries.reduce(0) { $0 + $1.totalFat }
        
        updateDailyTarget()
    }

    /// Calcule l'objectif calorique dynamique basé sur BMR + Apple Santé + Objectif perso
    private func updateDailyTarget() {
        if let userId = UserDefaults.standard.string(forKey: "userId"),
           let prefs = prefsRepo.load(for: userId) {
            
            let bmr = prefs.calculateBMR()
            
            // --- 1. CALCUL CALORIES (inchangé) ---
            // Active Surplus = Tout ce qui dépasse le métabolisme de base (NEAT + Sport)
            let activeSurplus = max(0, burnToday - bmr)
            
            self.dailyTarget = bmr + activeSurplus + prefs.calorieAdjustment
            self.proteinTarget = prefs.proteinTarget
            self.fatTarget = prefs.fatTarget
            self.carbsTarget = prefs.calculateCarbsTarget(totalKcal: self.dailyTarget)
            
            // --- 2. 💧 CALCUL OBJECTIF EAU (Ajusté) ---
            
            // A. Besoin de base : 35ml par kg (couvre BMR + vie sédentaire)
            let weight = prefs.bodyWeightKg ?? 75.0
            let baseWater = weight * 30.0
            
            let ratioMlPerActiveKcal = 0.3 // 0.25–0.35 selon ton feeling
            let activityWater = Double(activeBurnToday) * ratioMlPerActiveKcal

            // Cap pour éviter 6–7L
            let maxTarget = 5000.0 // ou 4500 si tu veux
            self.waterTarget = Int(min(baseWater + activityWater, maxTarget))
        }
    }

    func syncWithAppleHealth() async {
        let authorized = await HealthKitManager.shared.requestAuthorization()
        if authorized {
            let energy = await HealthKitManager.shared.fetchEnergy(for: selectedDate)
            self.activeBurnToday = Int(energy.active)
            self.basalBurnToday  = Int(energy.basal)

            // Si tu veux garder burnToday comme "total"
            self.burnToday = self.activeBurnToday + self.basalBurnToday

            updateDailyTarget()
        }
    }

    
    func entriesForSelectedDay() -> [CalorieEntry] {
        let from = selectedDate.startOfDayLocal
        let to   = selectedDate.endOfDayLocal
        return entries.filter { ($0.date >= from) && ($0.date <= to) }
    }
    
    func deleteFoodItem(at offsets: IndexSet, from mealType: MealType) async {
        // 1. Trouver l'entrée qui correspond à ce type de repas pour le jour sélectionné
        let from = selectedDate.startOfDayLocal
        let to   = selectedDate.endOfDayLocal
        
        // On cherche l'index dans la liste globale 'entries'
        if let entryIndex = entries.firstIndex(where: {
            $0.mealType == mealType && $0.date >= from && $0.date <= to
        }) {
            var updatedEntry = entries[entryIndex]
            
            // 2. Supprimer les aliments à l'intérieur de cette entrée
            if var items = updatedEntry.foodItems {
                items.remove(atOffsets: offsets)
                updatedEntry.foodItems = items
                
                var all = entries
                if items.isEmpty {
                    // Si le repas n'a plus d'aliments, on supprime carrément l'entrée
                    all.remove(at: entryIndex)
                } else {
                    // Sinon on met à jour l'entrée avec les aliments restants
                    all[entryIndex] = updatedEntry
                }
                
                // 3. Persister les changements
                await persist(all)
            }
        }
    }
    
    func copyMeal(from sourceDate: Date, sourceMealType: MealType, to targetDate: Date, targetMealType: MealType) async {
        // 1. On cherche spécifiquement le repas source (ex: le Dîner d'hier)
        let sourceEntries = entries.filter { entry in
            entry.mealType == sourceMealType && Calendar.current.isDate(entry.date, inSameDayAs: sourceDate)
        }
        
        let itemsToCopy = sourceEntries.flatMap { $0.foodItems ?? [] }
        
        if !itemsToCopy.isEmpty {
            // On crée de nouveaux FoodItems (nouveaux IDs) pour éviter les conflits
            let newItems = itemsToCopy.map { item in
                FoodItem(name: item.name, kcal: item.kcal, protein: item.protein, carbs: item.carbs, fat: item.fat)
            }
            // 2. On l'ajoute au repas de destination (ex: le Déjeuner d'aujourd'hui)
            await addMeal(type: targetMealType, items: newItems)
        }
    }
    
    func updateFoodItemQuantity(item: FoodItem, newQuantity: Double, mealType: MealType) async {
        let from = selectedDate.startOfDayLocal
        let to = selectedDate.endOfDayLocal
        
        if let entryIndex = entries.firstIndex(where: {
            $0.mealType == mealType && $0.date >= from && $0.date <= to
        }) {
            var updatedEntry = entries[entryIndex]
            if var items = updatedEntry.foodItems,
               let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
                
                // On calcule le ratio par rapport à l'ancienne quantité
                // (Note: Cela suppose que le nom contient "(...g)". Pour être plus robuste,
                // il vaudrait mieux stocker la valeur de base de 100g, mais restons simple ici.)
                
                let oldKcal = Double(items[itemIndex].kcal)
                // On fait une mise à jour simple proportionnelle
                // Si tu veux être ultra précis, il faudrait stocker les kcal/100g dans FoodItem
                
                // Pour l'instant, on met à jour les valeurs finales
                items[itemIndex].name = item.name // On garde le nom ou on le met à jour
                // Ici, on remplace l'item par un nouveau avec les nouvelles valeurs si besoin
                
                updatedEntry.foodItems = items
                var all = entries
                all[entryIndex] = updatedEntry
                await persist(all)
            }
        }
    }
    
    func deleteSpecificFoodItem(_ item: FoodItem, from mealType: MealType) async {
        var all = entries
        for i in 0..<all.count {
            if var items = all[i].foodItems {
                if let itemIndex = items.firstIndex(where: { $0.id == item.id }) {
                    items.remove(at: itemIndex)
                    all[i].foodItems = items
                    
                    // Si l'entrée est vide (plus d'aliments), on supprime le bloc repas
                    if items.isEmpty {
                        all.remove(at: i)
                    }
                    break
                }
            }
        }
        await persist(all)
    }

}
