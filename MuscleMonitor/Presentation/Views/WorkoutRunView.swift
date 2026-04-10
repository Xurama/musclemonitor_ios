//
//  WorkoutRunView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 13/09/2025.
//

import SwiftUI
import PhotosUI
import ActivityKit
import CoreHaptics

fileprivate func simpleHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

struct WorkoutRunView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var session: SessionViewModel
    @StateObject var vm: WorkoutRunViewModel
    
    @State private var showQuitConfirm   = false
    @State private var showFinishConfirm = false
    @State private var showAddExerciseSheet = false
    
    // ✅ Définition de l'état de partage avec Equatable pour l'alerte
    enum ShareStep: Equatable { case none, askShare, askPhoto }
    @State private var shareStep: ShareStep = .none
    
    @State private var showPhotoPickerModal: Bool = false
    @State private var isShareFlowActive: Bool = false
    @State private var waitingForBackground: Bool = false
    
    @State private var shareBackgroundImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil

    // --- Animations & Haptics ---
    @State private var previousButtonPressed = false
    @State private var nextButtonPressed = false

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 16) {
                    ProgressView(value: vm.sessionProgress)
                        .tint(.accentColor)
                        .scaleEffect(x: 1, y: 0.5, anchor: .center)
                        .padding(.top, -8)
                    
                    globalTimerHeader
                    
                    if vm.isResting { restBlock }
                    
                    Divider().padding(.vertical, 4)
                    
                    if let ex = vm.currentExercise {
                        if let history = vm.lastSessionValue {
                            Text(history)
                                .font(.caption.italic())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                        // --- Animations & Haptics ---
                        ZStack {
                            exerciseDetails(ex)
                                .id(ex.id)
                                .transition(.exerciseSwitch(direction: vm.exerciseTransitionDirection))
                        }
                        .animation(.easeInOut, value: ex.id)
                    }
                }
                .padding()
                .frame(maxHeight: .infinity, alignment: .top)
                .blur(radius: vm.showPRCelebration ? 3 : 0)
                .animation(.easeInOut, value: vm.showPRCelebration)

                if vm.showPRCelebration {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture { withAnimation { vm.showPRCelebration = false } }

                    PRCelebrationView()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.5).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .zIndex(99)
                }
            }
            .navigationTitle("session")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .photosPicker(isPresented: $showPhotoPickerModal, selection: $photoItem, matching: .images)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showQuitConfirm = true }) {
                        Image(systemName: "chevron.backward")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("end") {
                        Task {
                            if await vm.finishAndPersist() {
                                shareStep = .askShare
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: { vm.removeCurrentExercise() }) {
                            Label("Supprimer l'exercice", systemImage: "trash")
                        }
                        Button(action: { showAddExerciseSheet = true }) {
                            Label("Ajouter un exercice", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            // ✅ Utilisation de notre nouvelle extension ici !
            .workoutShareAlert(
                step: $shareStep,
                onSharePlain: {
                    isShareFlowActive = true
                    waitingForBackground = false
                    shareToInstagramNow()
                    session.endRun()
                },
                onShareWithPhoto: {
                    isShareFlowActive = true
                    waitingForBackground = true
                    showPhotoPickerModal = true
                },
                onCancel: {
                    session.endRun()
                }
            )
            .alert("leave_session", isPresented: $showQuitConfirm) {
                Button("cancel", role: .cancel) { }
                Button("leave", role: .destructive) {
                    WorkoutLiveActivityManager.shared.end(success: false)
                    session.endRun()
                }
            } message: {
                Text("current_progress_not_saved")
            }
            .alert("end_session", isPresented: $showFinishConfirm) {
                Button("cancel", role: .cancel) { }
                Button("end") {
                    Task {
                        if await vm.finishAndPersist() {
                            shareStep = .askShare
                        }
                    }
                }
            } message: {
                Text("save_session_complete")
            }
            .alert("Erreur de sauvegarde", isPresented: Binding(
                get: { vm.saveError != nil },
                set: { if !$0 { vm.saveError = nil } }
            )) {
                Button("OK") { vm.saveError = nil }
            } message: {
                Text(vm.saveError ?? "")
            }
            .onAppear {
                session.hasActiveWorkout = true
                if let first = vm.currentExercise {
                    WorkoutLiveActivityManager.shared.start(
                        workoutId: vm.workout.id,
                        workoutTitle: vm.workout.displayTitle,
                        firstExerciseName: first.name,
                        totalSets: first.sets,
                        nextReps: first.targetReps,
                        nextWeight: nil
                    )
                }
            }
            .onChange(of: scenePhase) { phase in
                if phase == .active {
                    vm.objectWillChange.send()
                }
            }
            .onChange(of: photoItem) { newItem in
                Task { @MainActor in
                    guard let item = newItem else { return }
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        self.shareBackgroundImage = normalized(img)
                        if isShareFlowActive && waitingForBackground {
                            shareToInstagramNow()
                            waitingForBackground = false
                            isShareFlowActive = false
                            session.endRun()
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddExerciseSheet) {
                AddExerciseSheet { newExercise in
                    vm.addExerciseAfterCurrent(newExercise)
                }
            }
            .safeAreaInset(edge: .bottom) {
                navControls
            }
        }
    }

    // MARK: - Subviews

    private var globalTimerHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(timeString(vm.elapsed))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
            }
            
            Spacer()
            
            Text("\(vm.currentPosition) / \(vm.totalExercises)")
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .foregroundStyle(Color.accentColor)
                .clipShape(Capsule())
        }
    }

    private var restBlock: some View {
        VStack(spacing: 6) {
            Text("rest").font(.subheadline).foregroundStyle(.secondary)
            Text(timeString(vm.restRemaining))
                .font(.title.bold())
                .monospacedDigit()
            Button("skip_rest") { vm.skipRest() }
                .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }
    
    private func exerciseTimerOverlay(_ ex: Workout.Exercise) -> some View {
        let isFinished = vm.isFinished(ex)
        let currentSet = vm.getSetsDone(for: ex) + 1
        let totalSets = vm.currentSetCount(ex)
        
        let isOvertime = !ex.isCardio && vm.activeExerciseSeconds < 0 && !isFinished
        let displaySeconds = isFinished ? vm.getRecordedTime(for: ex) : abs(vm.activeExerciseSeconds)

        return VStack(spacing: 12) {
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(isOvertime ? "OVERTIME" : (ex.isCardio ? "CHRONOMÈTRE" : "SÉRIE \(currentSet)/\(totalSets)"))
                        .font(.system(size: 10, weight: .black))
                        .foregroundStyle(isOvertime ? .red : .secondary)
                    
                    HStack(spacing: 2) {
                        if isOvertime {
                            Text("+")
                                .font(.system(size: 30, weight: .light, design: .monospaced))
                                .foregroundColor(.red)
                        }
                        
                        Text(timeString(displaySeconds))
                            .font(.system(size: 38, weight: .light, design: .monospaced))
                            .foregroundColor(isFinished ? .green : (isOvertime ? .red : (ex.isCardio ? .blue : .orange)))
                    }
                }
                
                Spacer()
                
                if isFinished {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("\(timeString(vm.getRecordedTime(for: ex))) enregistré")
                    }
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 12) {
                        Button(action: { vm.resetExerciseTimer(for: ex) }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }

                        Button(action: { vm.toggleExerciseTimer(for: ex) }) {
                            Image(systemName: vm.isExerciseTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(isOvertime ? .red : (ex.isCardio ? .blue : .orange))
                        }

                        if vm.activeExerciseSeconds != (ex.isCardio ? 0 : ex.targetSeconds) {
                            Button(action: {
                                withAnimation { vm.stopAndSaveExercise(for: ex) }
                            }) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            if ex.isCardio || ex.isDistanceBased {
                HStack {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .foregroundStyle(.blue)
                    TextField("Distance (m ou km)", text: Binding(
                        get: { vm.getDistance(for: ex) },
                        set: { vm.setDistance($0, for: ex) }
                    ))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                }
                .padding(10)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isFinished ? Color.green.opacity(0.3) : (isOvertime ? Color.red.opacity(0.3) : Color.clear), lineWidth: 2)
        )
    }

    private func exerciseDetails(_ ex: Workout.Exercise) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey(ex.name)).font(.title2.bold())

            if ex.isTimeBased || ex.isDistanceBased || ex.isCardio {
                exerciseTimerOverlay(ex)
            }

            if !ex.isCardio {
                List {
                    ForEach(0..<vm.currentSetCount(ex), id: \.self) { idx in
                        // --- Animations & Haptics ---
                        ZStack(alignment: .bottom) {
                            SetRowView(ex: ex, idx: idx, vm: vm)
                                .id("\(ex.id)-set-\(idx)")
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        // --- Animations & Haptics ---
                                        withAnimation {
                                            simpleHaptic(.light)
                                            self.vm.removeSet(ex, at: idx)
                                        }
                                    } label: {
                                        Label("delete", systemImage: "trash")
                                    }
                                }

                            Divider()
                                .padding(.leading, 0)
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color(.systemBackground))
                        .transition(.move(edge: .bottom))
                    }

                    Button {
                        // --- Animations & Haptics ---
                        withAnimation {
                            simpleHaptic(.light)
                            vm.addSet(ex)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("add_a_set")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemBackground))
                    .listRowInsets(EdgeInsets())
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.never)
                .frame(maxHeight: .infinity)
            } else {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: "figure.run")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                    Text("Le temps est automatiquement enregistré à la fin de l'exercice.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }

    private var navControls: some View {
        HStack(spacing: 12) {
            // --- Animations & Haptics ---
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    previousButtonPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        previousButtonPressed = false
                    }
                }
                vm.previousExercise()
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("previous").frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .buttonStyle(.bordered)
            .disabled(vm.currentPosition == 1)
            .frame(maxWidth: .infinity)
            .scaleEffect(previousButtonPressed ? 0.9 : 1.0)

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    nextButtonPressed = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        nextButtonPressed = false
                    }
                }
                vm.nextExercise(withRest: false)
            } label: {
                HStack {
                    Text("next").frame(maxWidth: .infinity, alignment: .center)
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.currentPosition == vm.totalExercises)
            .frame(maxWidth: .infinity)
            .scaleEffect(nextButtonPressed ? 0.9 : 1.0)
        }
        .padding(.horizontal)
    }

    private func timeString(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, r) }
        return String(format: "%02d:%02d", m, r)
    }
    
    private func normalized(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalizedImage ?? image
    }
    
    private func computeHighlights() -> (bestRM: Double, totalVolume: Double, star: String?) {
        var bestRM: Double = 0
        var totalVolume: Double = 0
        var perExerciseVolume: [(name: String, vol: Double)] = []

        for ex in vm.workout.exercises {
            var exVol: Double = 0
            let setCount = vm.currentSetCount(ex)
            for i in 0..<setCount {
                let reps = vm.reps(for: ex, setIndex: i)
                let weight = vm.weight(for: ex, setIndex: i)
                if vm.isWarmup(for: ex, setIndex: i) { continue }
                exVol += Double(reps) * weight
                let rm = weight * (1 + Double(reps)/30.0)
                if rm > bestRM { bestRM = rm }
            }
            totalVolume += exVol
            perExerciseVolume.append((ex.name, exVol))
        }
        let star = perExerciseVolume.max(by: { $0.vol < $1.vol })?.name
        return (bestRM, totalVolume, star)
    }

    private func shareToInstagramNow() {
        let highlights = computeHighlights()
        let card = WorkoutShareCardView(
            title: vm.workout.displayTitle,
            durationText: timeString(vm.elapsed),
            totalExercises: vm.totalExercises,
            currentDate: Date(),
            background: shareBackgroundImage,
            bestRM: highlights.bestRM,
            totalVolume: highlights.totalVolume,
            starExerciseName: highlights.star
        )
        // Share as background (full-frame) story
        ShareService.shareInstagramStory(background: card, topColorHex: "#000000", bottomColorHex: "#000000")
    }
}

// MARK: - Extension d'Alerte Native
private extension View {
    func workoutShareAlert(
        step: Binding<WorkoutRunView.ShareStep>,
        onSharePlain: @escaping () -> Void,
        onShareWithPhoto: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) -> some View {
        self.alert(
            step.wrappedValue == .askShare ? "Séance terminée ! 🎉" : "Ajouter une photo ?",
            isPresented: Binding(
                get: { step.wrappedValue != .none },
                set: { isPresenting in
                    if !isPresenting {
                        // S'assure que si l'alerte est fermée (ex: clic en dehors, bien que non supporté sur iOS par défaut), l'état se réinitialise
                        step.wrappedValue = .none
                    }
                }
            ),
            presenting: step.wrappedValue
        ) { currentStep in
            switch currentStep {
            case .askShare:
                Button("Non", role: .cancel) {
                    step.wrappedValue = .none
                    onCancel()
                }
                Button("Partager") {
                    step.wrappedValue = .none
                    // Délai nécessaire pour laisser SwiftUI fermer la 1ère alerte et rendre la 2ème de façon fluide
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        step.wrappedValue = .askPhoto
                    }
                }
            case .askPhoto:
                Button("Non, fond classique") {
                    step.wrappedValue = .none
                    onSharePlain()
                }
                Button("Oui, choisir") {
                    step.wrappedValue = .none
                    onShareWithPhoto()
                }
                Button("Annuler", role: .cancel) {
                    step.wrappedValue = .none
                    onCancel()
                }
            case .none:
                EmptyView()
            }
        } message: { currentStep in
            switch currentStep {
            case .askShare:
                Text("Souhaites-vous partager cette séance en story Instagram ?")
            case .askPhoto:
                Text("Veux-tu ajouter une photo de fond à ta carte de partage ?")
            case .none:
                EmptyView()
            }
        }
    }
}

// Les structures SetRowView, metricBlock, PRCelebrationView, WorkoutShareCardView et AddExerciseSheet
// restent les mêmes que dans ton code précédent (copiées/collées telles quelles).

private struct SetRowView: View {
    let ex: Workout.Exercise
    let idx: Int
    @ObservedObject var vm: WorkoutRunViewModel

    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @FocusState private var repsFocused: Bool
    @FocusState private var weightFocused: Bool

    var isDone: Bool { (idx + 1) <= vm.getSetsDone(for: ex) }
    
    var effortLabel: String {
        switch ex.effort {
        case .reps: return "Reps"
        case .time: return "Sec"
        case .distance: return "m"
        @unknown default: return "Effort"
        }
    }
    
    private var rowBackground: some View {
        let wu = vm.isWarmup(for: ex, setIndex: idx)
        let doneBg = Color(.secondarySystemBackground).opacity(0.5)
        let wuBg = Color.orange.opacity(0.06)

        if isDone { return AnyView(doneBg) }
        if wu { return AnyView(wuBg) }
        return AnyView(Color.clear)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set \(idx + 1)").font(.headline)

                    Button {
                        vm.toggleWarmup(for: ex, setIndex: idx)
                    } label: {
                        Text(vm.isWarmup(for: ex, setIndex: idx) ? "Échauffement" : "Série")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(vm.isWarmup(for: ex, setIndex: idx) ? Color.orange.opacity(0.22) : Color.secondary.opacity(0.12))
                            .foregroundStyle(vm.isWarmup(for: ex, setIndex: idx) ? .orange : .secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDone)
                }
                Spacer()
                Button {
                    // --- Animations & Haptics ---
                    simpleHaptic(.medium)
                    vm.toggleSetDone(ex, setNumber: idx + 1)
                } label: {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(isDone ? Color.accentColor : Color.secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 16) {
                metricBlock(
                    title: effortLabel,
                    valueText: "\(vm.reps(for: ex, setIndex: idx))",
                    minusAction: {
                        // --- Animations & Haptics ---
                        withAnimation {
                            simpleHaptic(.light)
                            vm.bumpReps(-1, for: ex, setIndex: idx)
                        }
                    },
                    plusAction: {
                        // --- Animations & Haptics ---
                        withAnimation {
                            simpleHaptic(.light)
                            vm.bumpReps(+1, for: ex, setIndex: idx)
                        }
                    },
                    footer: {
                        if isDone, let diff = vm.getDiff(for: ex, setIndex: idx), diff.repsDiff != 0 {
                            diffBadge(value: Double(diff.repsDiff), unit: "")
                        }
                    }
                )
                .disabled(isDone)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Poids").font(.caption).foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button(action: {
                            // --- Animations & Haptics ---
                            withAnimation {
                                simpleHaptic(.light)
                                vm.bumpWeight(-2.5, for: ex, setIndex: idx)
                                updateLocalFields()
                            }
                        }) {
                            Image(systemName: "minus.circle.fill").font(.title3)
                        }.buttonStyle(.plain)

                        HStack(spacing: 6) {
                            TextField("—", text: $weightText)
                                .keyboardType(.decimalPad)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .multilineTextAlignment(.leading)
                                .frame(minWidth: 44, alignment: .leading)
                                .focused($weightFocused)
                        }

                        Button(action: {
                            // --- Animations & Haptics ---
                            withAnimation {
                                simpleHaptic(.light)
                                vm.bumpWeight(+2.5, for: ex, setIndex: idx)
                                updateLocalFields()
                            }
                        }) {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }.buttonStyle(.plain)
                    }

                    if isDone, let diff = vm.getDiff(for: ex, setIndex: idx), diff.weightDiff != 0 {
                        diffBadge(value: diff.weightDiff, unit: "kg")
                    } else {
                        EmptyView().frame(height: 16, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(isDone)
            }
        }
        .onAppear { updateLocalFields() }
        .onChange(of: vm.weight(for: ex, setIndex: idx)) { _ in
            if !weightFocused { updateLocalFields() }
        }
        .toolbar {
            if weightFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        commitWeight()
                        DispatchQueue.main.async { weightFocused = false }
                    }
                }
            }
        }
        // --- Animations & Haptics ---
        .padding(14)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isDone ? Color.accentColor.opacity(0.20) : Color.clear, lineWidth: 1)
        )
        .transition(.move(edge: .bottom))
    }

    private func updateLocalFields() {
        let r = vm.reps(for: ex, setIndex: idx)
        repsText = String(r)
        let w = vm.weight(for: ex, setIndex: idx)
        weightText = w == 0 ? "" : (w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w))
    }

    private func commitWeight() {
        let t = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { vm.setWeight(0, for: ex, setIndex: idx); return }
        let normalized = t.replacingOccurrences(of: ",", with: ".")
        if let v = Double(normalized) {
            vm.setWeight(max(0, min(1000, v)), for: ex, setIndex: idx)
        }
    }
    
    private func diffBadge(value: Double, unit: String) -> some View {
        let isPositive = value > 0
        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
        let text = (isPositive ? "+" : "") + formattedValue + unit
        return Text(text)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(isPositive ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
            .foregroundStyle(isPositive ? .green : .red)
            .cornerRadius(4)
    }
}

@ViewBuilder
private func metricBlock(
    title: String,
    valueText: String,
    suffix: String? = nil,
    minusAction: @escaping () -> Void,
    plusAction: @escaping () -> Void,
    @ViewBuilder footer: () -> some View = { EmptyView() }
) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.caption).foregroundStyle(.secondary)
        HStack(spacing: 12) {
            Button(action: minusAction) { Image(systemName: "minus.circle.fill").font(.title3) }.buttonStyle(.plain)
            HStack(spacing: 6) {
                Text(valueText).font(.system(.title3, design: .rounded).weight(.bold)).monospacedDigit().frame(minWidth: 44, alignment: .leading)
                if let suffix { Text(suffix).font(.caption).foregroundStyle(.secondary) }
            }
            Button(action: plusAction) { Image(systemName: "plus.circle.fill").font(.title3) }.buttonStyle(.plain)
        }
        footer().frame(height: 16, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

struct PRCelebrationView: View {
    @State private var animateTrophy = false
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.yellow.opacity(0.2)).frame(width: 200, height: 200).scaleEffect(animateTrophy ? 1.5 : 0.8).opacity(animateTrophy ? 0 : 1)
                Image(systemName: "trophy.fill").font(.system(size: 80)).foregroundStyle(.yellow).scaleEffect(animateTrophy ? 1.2 : 0.9).rotationEffect(.degrees(animateTrophy ? 10 : -10))
            }
            VStack {
                Text("NOUVEAU RECORD !").font(.system(.title, design: .rounded)).fontWeight(.black).foregroundStyle(.yellow)
                Text("Tu viens de dépasser tes limites.").font(.subheadline).foregroundStyle(.secondary)
            }.scaleEffect(animateTrophy ? 1.0 : 0.8)
        }
        .padding(40).background(.ultraThinMaterial).cornerRadius(30).shadow(radius: 20)
        .onAppear { withAnimation(.interpolatingSpring(stiffness: 50, damping: 5).repeatForever(autoreverses: true)) { animateTrophy = true } }
    }
}

struct WorkoutShareCardView: View {
    let title: String
    let durationText: String
    let totalExercises: Int
    let currentDate: Date
    let background: UIImage?
    let bestRM: Double?
    let totalVolume: Double?
    let starExerciseName: String?

    var body: some View {
        ZStack {
            if let bg = background {
                GeometryReader { proxy in
                    Image(uiImage: bg).resizable().aspectRatio(contentMode: .fill).frame(width: proxy.size.width, height: proxy.size.height).clipped()
                }
            } else {
                LinearGradient(colors: [.orange.opacity(0.3), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            VStack { Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LinearGradient(gradient: Gradient(colors: [.black.opacity(0.75), .black.opacity(0.0)]), startPoint: .bottom, endPoint: .top).opacity(0.9))
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 30) {
                Text(title).font(.system(size: 84, weight: .bold, design: .rounded)).lineLimit(2).multilineTextAlignment(.leading)
                HStack(spacing: 36) {
                    Label(durationText, systemImage: "clock.fill")
                    Text("·")
                    Label("\(totalExercises) exos", systemImage: "dumbbell.fill")
                }.font(.system(size: 50, weight: .semibold)).foregroundStyle(.white).opacity(0.95)

                HStack {
                    Text("MuscleMonitor").font(.system(size: 36, weight: .bold)).padding(.horizontal, 24).padding(.vertical, 12).background(.ultraThinMaterial).clipShape(Capsule())
                    Spacer()
                    Text(currentDate, style: .date).font(.system(size: 36, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                }
            }
            .foregroundStyle(.white).padding(72).frame(maxWidth: .infinity, alignment: .leading).frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Workout.Exercise) -> Void
    private let allNames: [String] = Workout.Exercise.muscleMapping.keys.sorted()
    @State private var searchText: String = ""
    @State private var selectedName: String = Workout.Exercise.muscleMapping.keys.sorted().first ?? ""
    @State private var equipment: Workout.Equipment? = nil
    @State private var sets: Int = 3
    @State private var restSec: Int = 90
    @State private var effortMode: Int = 0
    @State private var targetReps: Int = 10
    @State private var targetSeconds: Int = 60
    @State private var targetMeters: Int = 100

    private var effortModeDefault: Int {
        let name = selectedName
        if Workout.Exercise.distanceBasedNames.contains(name) { return 2 }
        if Workout.Exercise.muscleMapping[name]?.contains(.cardio) ?? false { return 1 }
        if Workout.Exercise.timeBasedNames.contains(name) { return 1 }
        return 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("exercise") {
                    Picker("name", selection: $selectedName) { ForEach(allNames, id: \.self) { key in Text(LocalizedStringKey(key)).tag(key) } }.pickerStyle(.navigationLink)
                    Picker("equipment", selection: Binding<Workout.Equipment?>(get: { equipment }, set: { equipment = $0 })) {
                        Text("none").tag(Optional<Workout.Equipment>.none)
                        ForEach(Workout.Equipment.allCases) { eq in Text(eq.display).tag(Optional(eq)) }
                    }
                }
                Section("settings") {
                    Stepper("Séries : \(sets)", value: $sets, in: 1...10)
                    Stepper("Repos : \(restSec)s", value: $restSec, in: 0...300, step: 15)
                    Picker("type_of_effort", selection: $effortMode) {
                        Text("reps").tag(0)
                        Text("time").tag(1)
                        Text("distance").tag(2)
                    }.pickerStyle(.segmented)
                    if effortMode == 0 { Stepper("Répétitions : \(targetReps)", value: $targetReps, in: 1...100) }
                    else if effortMode == 1 { Stepper("Durée : \(targetSeconds)s", value: $targetSeconds, in: 5...600, step: 5) }
                    else { Stepper("Distance : \(targetMeters)m", value: $targetMeters, in: 10...10000, step: 10) }
                }
            }
            .navigationTitle("add_exercise")
            .onAppear { effortMode = effortModeDefault }
            .onChange(of: selectedName) { _ in effortMode = effortModeDefault }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("add") {
                        let tags = Workout.Exercise.muscleMapping[selectedName] ?? [.dos]
                        let effort: Workout.Effort
                        switch effortMode {
                        case 0: effort = .reps(targetReps)
                        case 1: effort = .time(seconds: targetSeconds)
                        default: effort = .distance(meters: targetMeters)
                        }
                        onAdd(Workout.Exercise(name: selectedName, muscleGroup: tags.first ?? .dos, equipment: equipment, sets: sets, effort: effort, restSec: restSec))
                        dismiss()
                    }
                }
            }
        }
    }
}

// --- TRANSITION PERSONNALISÉE POUR EXERCICES ---
extension AnyTransition {
    static func exerciseSwitch(direction: Int) -> AnyTransition {
        // L'insertion est directionnelle : la vue entrante arrive du bon côté.
        // Le removal est intentionnellement indépendant de la direction :
        // SwiftUI évalue le removal depuis le dernier rendu de la vue sortante,
        // donc si la direction a changé (next→previous ou inverse), la direction
        // stockée sur la vue sortante est l'ancienne valeur et les deux vues
        // s'animent du même côté. Le zoom-out+opacity évite ce problème.
        let insertion: AnyTransition
        if direction == 1 {
            insertion = .move(edge: .trailing)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.12, anchor: .trailing))
        } else {
            insertion = .move(edge: .leading)
                .combined(with: .opacity)
                .combined(with: .scale(scale: 1.12, anchor: .leading))
        }
        let removal = AnyTransition.opacity
            .combined(with: .scale(scale: 0.88))
        return .asymmetric(insertion: insertion, removal: removal)
    }
}
