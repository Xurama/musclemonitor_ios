//
//  HomeTabView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI
import ActivityKit

struct HomeTabView: View {
    @EnvironmentObject var session: SessionViewModel
    let workoutsRepo: WorkoutRepository
    let exercisesRepo: ExerciseCatalogRepository
    let sessionRepo: WorkoutSessionRepository
    
    @StateObject private var vm: HomeViewModel
    @State private var selectedDate: Date = Date()
    
    // états alerte démarrage
    @State private var draftToStart: Workout? = nil
    @State private var showStartAlert: Bool = false
    
    @State private var showAddSheet = false
    @State private var showAddMenu  = false
    
    // colonnes pour le grid (évite la recréation et aide l’inférence)
    private let gridCols: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]
    
    init(workoutsRepo: WorkoutRepository,
         exercisesRepo: ExerciseCatalogRepository,
         sessionRepo: WorkoutSessionRepository, prefsRepo: PreferencesRepository, userId: String)
    {
        self.workoutsRepo = workoutsRepo
        self.exercisesRepo = exercisesRepo
        self.sessionRepo = sessionRepo
        
        let vm = HomeViewModel(workoutsRepo: workoutsRepo, sessionRepo: sessionRepo, prefsRepo: prefsRepo, userId: userId)
        _vm = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    weekStrip
                    progressCard
                    workoutsGrid
                }
                .padding(.top, 12)
                .padding(.horizontal)
            }
            .navigationBarTitleDisplayMode(.inline)
            .task { await vm.load() }
            .startRunAlert(isPresented: $showStartAlert, workout: $draftToStart) { workout in
                session.startRun(workout: workout, repo: sessionRepo)
            }
            .deleteWorkoutAlert(vm: vm)
            .createDestination(exercisesRepo: exercisesRepo, vm: vm)
            .editDestination(exercisesRepo: exercisesRepo, vm: vm)
            .navigationDestination(isPresented: $vm.isPresentingManual) {
                AddManualSessionView(
                    workouts: vm.workouts,
                    defaultDate: selectedDate,
                    onCancel: { vm.isPresentingManual = false },
                    onSave: { draft in vm.didAddManual(draft) }
                )
            }
            .confirmationDialog("add", isPresented: $showAddMenu, titleVisibility: .visible) {
                Button("create_a_workout") { vm.isPresentingCreate = true }
                Button("add_a_session") { // Note: évite les parenthèses dans la clé technique si possible
                    vm.defaultManualDate = selectedDate
                    vm.isPresentingManual = true
                }
                Button("cancel", role: .cancel) { }
            }
        }
    }
}

// MARK: - Sections (sous-vues légères)

private extension HomeTabView {
    private var header: some View {
        GreetingHeader(
            name: session.user?.name ?? "athlete",
            onAdd: { vm.isPresentingCreate = true } // plus de menu
        )
    }

    var weekStrip: some View {
        WeekStrip(
            selectedDate: $selectedDate,
            workingDaysOnly: true,
            marker: { (date: Date) -> Bool in vm.hasSession(on: date) } // type explicite = inférence plus facile
        )
    }

    var progressCard: some View {
        WeeklyProgressCard(completed: vm.weekCompleted, target: vm.weekTarget)
    }

    var workoutsGrid: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: gridCols, spacing: 12) {
                ForEach(vm.workouts) { w in
                    WorkoutTile(
                        title: w.displayTitle,
                        subtitle: String(localized: "exercise_count \(w.exercises.count)")
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        draftToStart = w
                        showStartAlert = true
                    }
                    .contextMenu {
                        Button("edit", systemImage: "pencil") { vm.requestEdit(w) }
                        Button("delete", systemImage: "trash", role: .destructive) { vm.requestDelete(w) }
                    }
                }
            }

            // --- CARD plein-largeur pour l'ajout manuel ---
            Button {
                vm.defaultManualDate = selectedDate
                vm.isPresentingManual = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus.app")
                        .imageScale(.large)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("add_a_session")
                            .font(.headline)
                        Text("change_model")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(14)
            }
            .buttonStyle(.plain)
            // --- fin card ---
        }
    }
}


private struct WorkoutTile: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(subtitle).font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(14)
    }
}

// MARK: - Alerts helpers

private extension View {
    func startRunAlert(
        isPresented: Binding<Bool>,
        workout: Binding<Workout?>,
        onConfirm: @escaping (Workout) -> Void
    ) -> some View {
        self.alert(
            "apple_watch_ready",
            isPresented: isPresented,
            presenting: workout.wrappedValue
        ) { w in
            Button("not_yet", role: .cancel) { workout.wrappedValue = nil }
            Button("yes_start") {
                onConfirm(w)
                workout.wrappedValue = nil
            }
        } message: { _ in
            Text("activity_apple_watch")
        }
    }

    func deleteWorkoutAlert(vm: HomeViewModel) -> some View {
        self.alert(
            "delete_this_workout",
            isPresented: Binding(
                get: { vm.toConfirmDelete != nil },
                set: { if !$0 { vm.toConfirmDelete = nil } }
            ),
            actions: {
                Button("cancel", role: .cancel) { vm.toConfirmDelete = nil }
                Button("delete", role: .destructive) { vm.confirmDelete() }
            },
            message: {
                if let w = vm.toConfirmDelete {
                    Text("\(w.displayTitle)")
                }
            }
        )
    }
}

// MARK: - Navigation destinations helpers

private extension View {
    func createDestination(exercisesRepo: ExerciseCatalogRepository, vm: HomeViewModel) -> some View {
        self.navigationDestination(isPresented: vmBinding(vm, keyPath: \.isPresentingCreate)) {
            CreateWorkoutView(
                vm: CreateWorkoutViewModel(catalogRepo: exercisesRepo)
            ) { newWorkout in
                vm.didCreate(newWorkout)
            }
        }
    }

    func editDestination(exercisesRepo: ExerciseCatalogRepository, vm: HomeViewModel) -> some View {
        self.navigationDestination(isPresented: vmBinding(vm, keyPath: \.isPresentingEdit)) {
            if let w = vm.editingWorkout {
                CreateWorkoutView(
                    vm: CreateWorkoutViewModel(catalogRepo: exercisesRepo, prefilled: w)
                ) { edited in
                    vm.didEdit(edited)
                }
            }
        }
    }

    // petite aide pour obtenir un Binding<Bool> sur @StateObject vm
    private func vmBinding(_ vm: HomeViewModel, keyPath: ReferenceWritableKeyPath<HomeViewModel, Bool>) -> Binding<Bool> {
        Binding(
            get: { vm[keyPath: keyPath] },
            set: { vm[keyPath: keyPath] = $0 }
        )
    }
}
