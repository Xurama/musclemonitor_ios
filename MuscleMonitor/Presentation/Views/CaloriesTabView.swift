//
//  CaloriesTabView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 02/10/2025.
//

import SwiftUI

struct CaloriesTabView: View {
    @StateObject private var vm: CaloriesViewModel
    @State private var selectedMealType: MealType = .breakfast
    @State private var activeSheetItem: FoodItem? = nil
    @State private var isAddingNewItem = false // Pour savoir si c'est un + ou un Edit
    
    @State private var showCopySheet = false
    
    // États pour l'édition
    @State private var editingItem: FoodItem? = nil
    
    @State private var collapsedMeals: Set<MealType> = []

    init(repo: CalorieRepository) {
        _vm = StateObject(wrappedValue: CaloriesViewModel(repo: repo))
    }

    var body: some View {
        NavigationStack {
            List {
                // --- 1. SÉLECTEUR DE DATE & RÉSUMÉ ---
                Section {
                    DatePicker("date", selection: $vm.selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                    
                    macroSummaryCard
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                // --- 2. SECTION DÉPENSE SANTÉ ---
                Section {
                    burnSection
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                
                Section {
                    WaterSection(amount: vm.waterToday, target: vm.waterTarget) { addedAmount in
                        Task {
                            await vm.addWater(amount: addedAmount)
                        }
                    }
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                
                // --- 3. SECTIONS DE REPAS ---
                ForEach(MealType.allCases) { type in
                    let dailyEntries = vm.entriesForSelectedDay().filter { $0.mealType == type }
                    let isCollapsed = collapsedMeals.contains(type)
                    
                    Section(header: mealHeader(for: type, entries: dailyEntries)) {
                        if !isCollapsed {
                            if dailyEntries.isEmpty {
                                Text("no_added_food")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground).opacity(0.5)))
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            } else {
                                ForEach(dailyEntries.flatMap { $0.foodItems ?? [] }) { item in
                                    foodRow(item: item)
                                        .padding()
                                        .background(Color(.secondarySystemBackground).opacity(0.5))
                                        .cornerRadius(12)
                                        .contextMenu { // ✅ Haptic Touch / Appui long
                                            Button {
                                                selectedMealType = type
                                                isAddingNewItem = false
                                                activeSheetItem = item
                                            } label: {
                                                Label("edit", systemImage: "pencil")
                                            }
                                            
                                            Button(role: .destructive) {
                                                print("🔘 Clic détecté sur Supprimer pour: \(item.name)") // Log de test
                                                Task {
                                                    await vm.deleteSpecificFoodItem(item, from: type)
                                                }
                                            } label: {
                                                Label("delete", systemImage: "trash")
                                            }
                                        }
                                }
                                .onDelete { offsets in
                                    Task { await vm.deleteFoodItem(at: offsets, from: type) }
                                }
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

            }
            .listStyle(.plain)
            .navigationTitle("nutrition")
            .task { await vm.load() }
            .refreshable { await vm.syncWithAppleHealth() }
            .sheet(isPresented: Binding(
                get: { isAddingNewItem || activeSheetItem != nil },
                set: { if !$0 { isAddingNewItem = false; activeSheetItem = nil } }
            )) {
                AddFoodView(mealType: selectedMealType, editingItem: activeSheetItem) { newItem in
                    
                    // 🛑 CRUCIAL : On capture l'état "Edition" MAINTENANT,
                    // avant que le dismiss() ne remette activeSheetItem à nil.
                    let itemBeingEdited = activeSheetItem
                    
                    print("📝 CALLBACK REÇU. Item original détecté ? \(itemBeingEdited != nil)")

                    Task {
                        if let oldItem = itemBeingEdited {
                            print("🔄 Mode Remplacement lancé pour l'ID: \(oldItem.id)")
                            await vm.replaceFoodItem(oldItem: oldItem, with: newItem, in: selectedMealType)
                        } else {
                            print("➕ Mode Ajout lancé")
                            await vm.addMeal(type: selectedMealType, items: [newItem])
                        }
                        
                        // On nettoie l'état après avoir lancé l'action
                        activeSheetItem = nil
                        isAddingNewItem = false
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCopySheet) {
                CopyMealSheet(vm: vm, targetType: selectedMealType)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // --- Fonctions d'aide pour l'UI ---

    private func mealHeader(for type: MealType, entries: [CalorieEntry]) -> some View {
        let totalKcal = entries.reduce(0) { $0 + $1.totalKcal }
        let isCollapsed = collapsedMeals.contains(type)
        
        return HStack(alignment: .center, spacing: 10) {
            // --- Bouton de bascule (Flèche) ---
            Button {
                withAnimation(.spring()) {
                    if isCollapsed {
                        collapsedMeals.remove(type)
                    } else {
                        collapsedMeals.insert(type)
                    }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90)) // Rotation fluide
            }
            .buttonStyle(.plain)

            Text(type.rawValue).font(.headline).foregroundColor(.primary)
            
            if totalKcal > 0 {
                Text("\(totalKcal) kcal")
                    .font(.subheadline).foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Tes boutons existants (Copie et Ajout)
            Button {
                selectedMealType = type
                showCopySheet = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }

            Button {
                selectedMealType = type
                activeSheetItem = nil
                isAddingNewItem = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
        .textCase(nil)
    }
    
    private func foodRow(item: FoodItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.subheadline).fontWeight(.medium)
                Text("P: \(String(format: "%.1f", item.protein))g | G: \(String(format: "%.1f", item.carbs))g | L: \(String(format: "%.1f", item.fat))g")
                    .font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(Int(item.kcal)) kcal").font(.footnote).foregroundColor(.secondary)
        }
    }

    private var macroSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("calories").font(.headline).foregroundStyle(.secondary)
                    Text("\(vm.intakeToday) / \(vm.dailyTarget)").font(.title.bold())
                }
                Spacer()
                CircularProgressView(progress: Double(vm.intakeToday) / Double(max(1, vm.dailyTarget)), color: .green)
                    .frame(width: 50, height: 50)
            }
            Divider()
            HStack(spacing: 20) {
                MacroIndicator(label: "Protéine", value: vm.proteinToday, target: vm.proteinTarget, color: .blue)
                MacroIndicator(label: "Glucide", value: vm.carbsToday, target: vm.carbsTarget, color: .orange)
                MacroIndicator(label: "Lipide", value: vm.fatToday, target: vm.fatTarget, color: .red)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var burnSection: some View {
        HStack {
            Image(systemName: "flame.fill").foregroundStyle(.orange)
            Text("expenditure_health").font(.headline)
            Spacer()
            Text("\(vm.burnToday) kcal").fontWeight(.bold)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

// --- Components ---

struct MacroIndicator: View {
    let label: String
    let value: Double
    let target: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(label).font(.caption).bold().foregroundStyle(.secondary)
            Text(String(format: "%.1f", value) + " / " + String(format: "%.0f", target) + "g")
                .font(.system(size: 10, weight: .bold, design: .rounded))
            ProgressView(value: value, total: max(1, target))
                .tint(color)
        }
    }
}

struct CircularProgressView: View {
    let progress: Double
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.2), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct CopyMealSheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: CaloriesViewModel
    let targetType: MealType // Le repas où on va coller (ex: Déjeuner)
    
    @State private var sourceDate = Date()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker("date_source", selection: $sourceDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                
                List {
                    ForEach(MealType.allCases) { type in
                        let entriesForType = vm.entries.filter {
                            $0.mealType == type && Calendar.current.isDate($0.date, inSameDayAs: sourceDate)
                        }
                        let items = entriesForType.flatMap { $0.foodItems ?? [] }
                        let totalKcal = items.reduce(0) { $0 + $1.kcal }
                        
                        Button {
                            Task {
                                await vm.copyMeal(from: sourceDate,
                                                 sourceMealType: type,
                                                 to: vm.selectedDate,
                                                 targetMealType: targetType)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(type.rawValue)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    if items.isEmpty {
                                        Text("empty").font(.caption).foregroundColor(.secondary)
                                    } else {
                                        Text("\(items.count) aliments - \(totalKcal) kcal")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                }
                                Spacer()
                                if !items.isEmpty {
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(items.isEmpty)
                    }
                }
            }
            .navigationTitle("copy_to \(targetType.rawValue)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
        }
    }
}

struct EditFoodQuantityView: View {
    @Environment(\.dismiss) var dismiss
    let item: FoodItem
    let onSave: (Double) -> Void
    
    @State private var quantity: String = ""
    
    init(item: FoodItem, onSave: @escaping (Double) -> Void) {
        self.item = item
        self.onSave = onSave
        // On essaie d'extraire la quantité actuelle du nom (ex: "Lardons (150g)")
        let current = item.name.components(separatedBy: "(").last?.replacingOccurrences(of: "g)", with: "") ?? "100"
        _quantity = State(initialValue: current)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("modify_quantity_for \(item.name)") {
                    HStack {
                        TextField("quantity", text: $quantity)
                            .keyboardType(.numberPad)
                        Text("g")
                    }
                }
            }
            .navigationTitle("edition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
                        if let q = Double(quantity) {
                            onSave(q)
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
            }
        }
    }
}

struct WaterSection: View {
    let amount: Int
    let target: Int
    let onAdd: (Int) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                    .font(.title3)
                
                Text("Hydratation")
                    .font(.headline)
                
                Spacer()
                
                Text("\(max(0, amount)) / \(target) ml")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(.secondary)
            }
            
            // Barre de progression
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.cyan.opacity(0.2))
                    
                    let ratio = target > 0 ? min(max(Double(amount) / Double(target), 0), 1.0) : 0
                    
                    Capsule().fill(Color.cyan)
                        .frame(width: max(0, geo.size.width * ratio))
                        .animation(.spring(), value: amount)
                }
            }
            .frame(height: 12)
            
            // Boutons - / +
            HStack(spacing: 20) {
                Button {
                    onAdd(-250)
                } label: {
                    Label("250ml", systemImage: "minus")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless) // ✅ INDISPENSABLE pour séparer le clic dans une List

                Button {
                    onAdd(250)
                } label: {
                    Label("250ml", systemImage: "plus")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.cyan.opacity(0.1))
                        .foregroundStyle(.cyan)
                        .clipShape(Capsule())
                }
                .buttonStyle(.borderless) // ✅ INDISPENSABLE
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}
