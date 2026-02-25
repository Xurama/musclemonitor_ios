//
//  CreateWorkoutView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 12/09/2025.
//

import SwiftUI

private enum FocusTarget: Hashable {
    case sets(String)  // exercise.id
    case reps(String)
    case rest(String)
}

struct CreateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss

    // 👉 Si le VM est injecté depuis le parent, préfère ObservedObject :
    @ObservedObject var vm: CreateWorkoutViewModel
    // (Alternative: garder @StateObject mais avec un init qui wrappe le vm : _vm = StateObject(wrappedValue: vm))

    let onSaved: (Workout) -> Void

    // (Optionnel) tri alphabétique si besoin
    private var sortedExercises: [Workout.Exercise] {
        vm.configs.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var title: String {
        switch vm.step {
        case .tags:      return "Groupes musculaires"
        case .select:    return "Sélection d’exercices"
        case .configure: return "Configurer"
        }
    }

    var body: some View {
        NavigationStack {
            stepContent
                .navigationTitle(title)
                .navigationBarBackButtonHidden(vm.step == .configure || vm.step == .select)
                .toolbar {
                    if vm.step == .configure {
                        if !vm.isEditing {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: { vm.step = .select }) {
                                    Image(systemName: "chevron.backward")
                                }
                            }
                        }
                        
                        ToolbarItem(placement: .confirmationAction) {
                            Button("save") { onSaved(vm.buildWorkout()) }
                                .disabled(vm.orderedExercises.isEmpty)
                        }
                    }
                    else if vm.step == .select {
                        if !vm.isEditing {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button(action: { vm.step = .tags }) {
                                    Image(systemName: "chevron.backward")
                                }
                            }
                        } else {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("done") { vm.step = .configure }
                            }
                        }
                    }
                }
        }
        .onAppear { vm.loadCatalog() }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch vm.step {
        case .tags:
            SelectTagsView(selected: $vm.selectedTags) {
                vm.goToSelect()
            }
        case .select:
            SelectExercisesView(
                all: vm.filteredExercises,
                isSelected: { vm.selectedNames.contains($0) },
                onToggle: { vm.toggleSelection($0) },
                onContinue: { vm.goToConfigure() }
            )
        case .configure:
            ConfigureExercisesView(
                workoutName: $vm.workoutName,
                exercises: vm.orderedExercises,
                onChange: vm.update,
                onMove: vm.reorder(fromOffsets:toOffset:),
                onDeleteExercise: { ex in vm.removeExercise(ex) },
                onAddExerciseTapped: { vm.step = .select }
            )
        }
    }
}

// MARK: - Subviews

private struct SelectTagsView: View {
    @Binding var selected: Set<MuscleTag>
    let onContinue: () -> Void
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 16) {
            Text("choose_target_groups")
                .font(.headline)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(MuscleTag.allCases) { tag in
                    TagChip(tag: tag,
                            isSelected: selected.contains(tag),
                            onTap: {
                                if selected.contains(tag) { selected.remove(tag) }
                                else { selected.insert(tag) }
                            })
                }
            }
            .padding(.horizontal)
            Button("next", action: onContinue)
                .buttonStyle(.borderedProminent)
                .disabled(selected.isEmpty)
        }
        .padding()
    }
}

private struct TagChip: View {
    let tag: MuscleTag
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(tag.displayName)
                .font(.subheadline)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

private struct SelectExercisesView: View {
    let all: [String]
    let isSelected: (String) -> Bool
    let onToggle: (String) -> Void
    let onContinue: () -> Void
    @State private var searchText = ""

    private var filtered: [String] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return q.isEmpty ? all : all.filter { $0.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("search_exercise", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered.indices, id: \.self) { i in
                        let name = filtered[i]
                        ExerciseRow(
                            name: name,
                            isSelected: isSelected(name),
                            onToggle: { onToggle(name) }
                        )
                        Divider().padding(.leading)
                    }
                }
            }
            Button(action: onContinue) {
                // Astuce : si tu veux le total sélectionné, passe vm.selectedNames.count via la closure
                Text("continue (\(filtered.filter { isSelected($0) }.count))")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .disabled(filtered.allSatisfy { !isSelected($0) })
        }
    }
}

private struct ExerciseRow: View {
    let name: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Text(LocalizedStringKey(name))
                .frame(maxWidth: .infinity, alignment: .leading)
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}

private struct ConfigureExercisesView: View {
    @Binding var workoutName: String
    var exercises: [Workout.Exercise]
    let onChange: (Workout.Exercise) -> Void
    let onMove: (IndexSet, Int) -> Void
    let onDeleteExercise: (Workout.Exercise) -> Void
    let onAddExerciseTapped: () -> Void

    @FocusState private var focused: FocusTarget?

    private var focusOrder: [FocusTarget] {
        exercises.flatMap { ex in
            [.sets(ex.id), .reps(ex.id), .rest(ex.id)]
        }
    }

    private func move(_ delta: Int) {
        guard let current = focused,
              let idx = focusOrder.firstIndex(of: current) else {
            focused = focusOrder.first
            return
        }
        let newIndex = max(0, min(focusOrder.count - 1, idx + delta))
        focused = focusOrder[newIndex]
    }

    var body: some View {
        List {
            Section("workout_name") {
                TextField("ex_push_day", text: $workoutName)
                    .submitLabel(.done)
            }
            Section("exercises") {
                ForEach(exercises, id: \.id) { ex in
                    ConfigureExerciseRow(exercise: ex) { updated in
                        onChange(updated)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) { onDeleteExercise(ex) } label: {
                            Label("delete", systemImage: "trash")
                        }
                    }
                }
                .onMove(perform: onMove)

                Button {
                    onAddExerciseTapped()
                } label: {
                    Label("add_exercise", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }

        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                let isFirst = focused == focusOrder.first || focusOrder.isEmpty
                let isLast  = focused == focusOrder.last  || focusOrder.isEmpty

                if isFirst {
                    Button("close") { focused = nil }
                        .accessibilityLabel("close_keyboard")
                } else {
                    Button { move(-1) } label: { Image(systemName: "chevron.left") }
                        .accessibilityLabel("previous")
                }

                Spacer()

                if isLast {
                    Button("close") { focused = nil }
                        .accessibilityLabel("close_keyboard")
                } else {
                    Button { move(1) } label: { Image(systemName: "chevron.right") }
                        .accessibilityLabel("next")
                }
            }
        }
    }
}
