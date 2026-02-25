//
//  AddFoodView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 31/12/2025.
//

//
//  AddFoodView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 31/12/2025.
//

import SwiftUI

struct AddFoodView: View {
    @Environment(\.dismiss) var dismiss
    let mealType: MealType
    
    // Pour le mode édition (optionnel)
    var editingItem: FoodItem? = nil
    let onSave: (FoodItem) -> Void
    
    @State private var name: String = ""
    @State private var quantity: String = "100" // Poids consommé en g
    
    // Valeurs pour 100g (référence étiquette)
    @State private var kcal100: String = ""
    @State private var protein100: String = ""
    @State private var carbs100: String = ""
    @State private var fat100: String = ""
    
    @State private var catalog: [FoodItem] = []
    @State private var searchText: String = ""
    let foodRepo = FoodRepositoryLocal()
    
    @State private var showScanner = false
    @State private var scannedCode: String? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                // SECTION 1 : SCANNER ET RECHERCHE (Uniquement si nouvel ajout)
                if editingItem == nil {
                    Section {
                        Button(action: { showScanner = true }) {
                            HStack {
                                Image(systemName: "barcode.viewfinder")
                                Text("scan_product")
                            }
                        }
                    }
                    
                    Section("search_in_my_food") {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("search_food", text: $searchText)
                        }
                        
                        if !searchText.isEmpty {
                            let suggestions = catalog.filter { $0.name.lowercased().contains(searchText.lowercased()) }
                            
                            if suggestions.isEmpty {
                                Text("no_result").font(.caption).foregroundStyle(.secondary)
                            } else {
                                ForEach(suggestions) { suggestion in
                                    Button {
                                        fillFromCatalog(suggestion)
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(suggestion.name).fontWeight(.medium)
                                                Text("\(suggestion.kcal) kcal / 100g").font(.caption2).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: "arrow.up.left.circle").foregroundStyle(.tint)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // SECTION 2 : ALIMENT ET QUANTITÉ
                Section("food_and_quantity") {
                    TextField("example_name_food", text: $name)
                    
                    HStack {
                        Text("quantity_eaten")
                        Spacer()
                        TextField("100", text: $quantity)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .fontWeight(.bold)
                        Text("g").foregroundStyle(.secondary)
                    }
                }
                
                // SECTION 3 : VALEURS NUTRITIONNELLES (POUR 100G)
                Section {
                    HStack {
                        Text("calories")
                        Spacer()
                        TextField("0", text: $kcal100)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                    
                    macroField(label: "Protéines", value: $protein100, color: .blue)
                    macroField(label: "Glucides", value: $carbs100, color: .orange)
                    macroField(label: "Lipides", value: $fat100, color: .red)
                } header: {
                    Text("values_per_100g")
                } footer: {
                    if let q = Double(quantity.replacingOccurrences(of: ",", with: ".")), q > 0 {
                        Text("app_calculates_values \(Int(q))")
                    }
                }
            }
            .navigationTitle(editingItem == nil ? "Ajouter au \(mealType.rawValue)" : "edit_food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                // Dans AddFoodView.swift
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        let q = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 100.0
                        let k100 = Double(kcal100.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let p100 = Double(protein100.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let c100 = Double(carbs100.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let f100 = Double(fat100.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        
                        let ratio = q / 100.0
                        
                        // ✅ On réutilise l'ID EXACT de l'élément en cours d'édition
                        // Si editingItem est nil, c'est un nouvel aliment (nouvel ID)
                        let finalItem = FoodItem(
                            id: editingItem?.id ?? UUID(),
                            name: "\(name) (\(Int(q))g)",
                            kcal: Int(k100 * ratio),
                            protein: p100 * ratio,
                            carbs: c100 * ratio,
                            fat: f100 * ratio
                        )
                        
                        onSave(finalItem)
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Si on est en mode édition, on pré-remplit les champs
                if let item = editingItem {
                    setupEditingMode(item)
                }
                Task { self.catalog = (try? await foodRepo.loadCatalog()) ?? [] }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerView(scannedCode: $scannedCode)
            }
            .onChange(of: scannedCode) { newCode in
                if let code = newCode {
                    Task {
                        if let fetchedItem = await OpenFoodFactsService.shared.fetchProduct(barcode: code) {
                            self.name = fetchedItem.name
                            self.kcal100 = "\(fetchedItem.kcal)"
                            self.protein100 = String(format: "%.1f", fetchedItem.protein)
                            self.carbs100 = String(format: "%.1f", fetchedItem.carbs)
                            self.fat100 = String(format: "%.1f", fetchedItem.fat)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func setupEditingMode(_ item: FoodItem) {
        // On extrait le nom de base (ex: "Riz" au lieu de "Riz (150g)")
        self.name = item.name.components(separatedBy: " (").first ?? item.name
        
        // On extrait la quantité depuis le nom entre parenthèses
        let qString = item.name.components(separatedBy: "(").last?.replacingOccurrences(of: "g)", with: "") ?? "100"
        let qDouble = Double(qString) ?? 100.0
        self.quantity = qString
        
        // On recalcule les valeurs pour 100g (inverse du ratio) pour l'affichage
        let ratio = 100.0 / qDouble
        self.kcal100 = "\(Int(Double(item.kcal) * ratio))"
        self.protein100 = String(format: "%.1f", item.protein * ratio)
        self.carbs100 = String(format: "%.1f", item.carbs * ratio)
        self.fat100 = String(format: "%.1f", item.fat * ratio)
    }
    
    private func fillFromCatalog(_ item: FoodItem) {
        self.name = item.name
        self.kcal100 = "\(item.kcal)"
        self.protein100 = String(format: "%.1f", item.protein)
        self.carbs100 = String(format: "%.1f", item.carbs)
        self.fat100 = String(format: "%.1f", item.fat)
        self.searchText = ""
    }
    
    private func macroField(label: String, value: Binding<String>, color: Color) -> some View {
        HStack {
            Image(systemName: "circle.fill").font(.caption2).foregroundStyle(color)
            Text(label)
            Spacer()
            TextField("0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text("g").foregroundStyle(.secondary)
        }
    }
    
    private func saveAliment() {
        let q = Double(quantity.replacingOccurrences(of: ",", with: ".")) ?? 100.0
        let k100 = Double(kcal100.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let p100 = Double(protein100.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let c100 = Double(carbs100.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let f100 = Double(fat100.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        
        let ratio = q / 100.0
        
        // ✅ CRUCIAL : On utilise l'ID de l'item en cours d'édition s'il existe !
        let finalItem = FoodItem(
            id: editingItem?.id ?? UUID(), // Si editingItem n'est pas nul, on garde son ID
            name: "\(name) (\(Int(q))g)",
            kcal: Int(k100 * ratio),
            protein: p100 * ratio,
            carbs: c100 * ratio,
            fat: f100 * ratio
        )
        
        Task {
            if editingItem == nil {
                let baseItem = FoodItem(name: name, kcal: Int(k100), protein: p100, carbs: c100, fat: f100)
                try? await foodRepo.addToCatalog(baseItem)
            }
            onSave(finalItem)
            dismiss()
        }
    }
}
