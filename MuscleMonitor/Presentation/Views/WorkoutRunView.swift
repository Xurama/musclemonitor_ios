//
//  WorkoutRunView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 13/09/2025.
//

// WorkoutRunView.swift

import SwiftUI
import PhotosUI
import UIKit

struct WorkoutRunView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var session: SessionViewModel
    @StateObject var vm: WorkoutRunViewModel
    
    @State private var showQuitConfirm   = false
    @State private var showFinishConfirm = false
    @State private var showAddExerciseSheet = false
    
    @State private var showSharePrompt: Bool = false
    @State private var showBackgroundPrompt: Bool = false
    @State private var showPhotoPickerModal: Bool = false
    @State private var isShareFlowActive: Bool = false
    @State private var waitingForBackground: Bool = false
    
    @State private var shareBackgroundImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 16) {
                    // ✅ BARRE DE PROGRESSION DISCRETE
                    ProgressView(value: vm.sessionProgress)
                        .tint(.accentColor)
                        .scaleEffect(x: 1, y: 0.5, anchor: .center)
                        .padding(.top, -8)
                    
                    globalTimerHeader
                    
                    if vm.isResting { restBlock }
                    
                    Divider().padding(.vertical, 4)
                    
                    if let ex = vm.currentExercise {
                        // ✅ HISTORIQUE (Dernière fois)
                        if let history = vm.lastSessionValue {
                            Text(history)
                                .font(.caption.italic())
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                        
                        exerciseDetails(ex)
                    }
                    
                    navControls
                        .padding(.top, 8)

                }
                .padding()
                    .blur(radius: vm.showPRCelebration ? 3 : 0)
                    .animation(.easeInOut, value: vm.showPRCelebration)

                    // ✅ Animation de Célébration améliorée
                    if vm.showPRCelebration {
                        Color.black.opacity(0.2)
                            .ignoresSafeArea()
                            .onTapGesture { withAnimation { vm.showPRCelebration = false } }

                        PRCelebrationView()
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.5).combined(with: .opacity),
                                removal: .opacity
                            ))
                            .zIndex(99) // S'assure qu'il est au dessus de TOUT
                    }
            }
            .navigationTitle("session")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showQuitConfirm = true }) {
                        Image(systemName: "chevron.backward")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Image(systemName: "photo").imageScale(.medium)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("end") {
                        Task {
                            await vm.finishAndPersist()
                            showSharePrompt = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    let img = renderRunShareImage()
                    ShareLink(item: img, preview: SharePreview("my_workout", image: img)) {
                        Image(systemName: "square.and.arrow.up")
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
                        await vm.finishAndPersist()
                        showSharePrompt = true
                    }
                }
            } message: {
                Text("save_session_complete")
            }
            .confirmationDialog("share_instagram_story", isPresented: $showSharePrompt, titleVisibility: .visible) {
                Button("share") {
                    showBackgroundPrompt = true
                }
                Button("not_now", role: .cancel) {
                    session.endRun()
                }
            } message: {
                Text("Souhaitez-vous partager cette séance en story Instagram ?")
            }
            .confirmationDialog("add_background_photo", isPresented: $showBackgroundPrompt, titleVisibility: .visible) {
                Button("yes") {
                    isShareFlowActive = true
                    waitingForBackground = true
                    showPhotoPickerModal = true
                }
                Button("no") {
                    isShareFlowActive = true
                    waitingForBackground = false
                    shareToInstagramNow()
                    session.endRun()
                }
            } message: {
                Text("Ajouter une photo de fond à la carte de partage ?")
            }
            .sheet(isPresented: $showPhotoPickerModal) {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo").imageScale(.large)
                        Text("choose_a_photo")
                    }
                    .padding()
                }
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
                    // Insert just after current and jump to it
                    vm.addExerciseAfterCurrent(newExercise)
                }
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
        
        // ✅ Détection de l'Overtime : Muscu/Gainage dont le chrono est passé sous 0
        let isOvertime = !ex.isCardio && vm.activeExerciseSeconds < 0 && !isFinished
        
        // Valeur brute à afficher (on utilise la valeur absolue pour éviter le signe "-" natif)
        let displaySeconds = isFinished ? vm.getRecordedTime(for: ex) : abs(vm.activeExerciseSeconds)

        return VStack(spacing: 12) {
            HStack(spacing: 20) {
                // --- SECTION TEXTE (Label + Chrono) ---
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
                
                // --- SECTION BOUTONS ---
                if isFinished {
                    // État terminé
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
                        // 1. Bouton Reset (Flèche qui tourne)
                        Button(action: { vm.resetExerciseTimer(for: ex) }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: 36)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Circle())
                        }

                        // 2. Bouton Play / Pause
                        Button(action: { vm.toggleExerciseTimer(for: ex) }) {
                            Image(systemName: vm.isExerciseTimerRunning ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 44))
                                .foregroundColor(isOvertime ? .red : (ex.isCardio ? .blue : .orange))
                        }

                        // 3. Bouton Stop (Bouton Rouge de validation)
                        // On ne l'affiche que si le chrono a commencé à bouger
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
            
            // --- SECTION DISTANCE (Uniquement pour le Cardio) ---
            if ex.isCardio {
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

            if ex.isTimeBased {
                exerciseTimerOverlay(ex)
            }

            if !ex.isCardio {
                HStack {
                    Text("\(vm.getSetsDone(for: ex))/\(vm.currentSetCount(ex)) sets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("copy_reps") { vm.applySameReps(vm.reps(for: ex, setIndex: 0), for: ex) }
                        Button("copy_weight") { vm.applySameWeight(vm.weight(for: ex, setIndex: 0), for: ex) }
                    } label: {
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .foregroundStyle(.secondary)
                    }
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<vm.currentSetCount(ex), id: \.self) { idx in
                            SetRowView(ex: ex, idx: idx, vm: vm)
                                .id("\(ex.id)-set-\(idx)")
                                .background(Color(.systemBackground))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        // ✅ Correction ici : Accès explicite via self.vm
                                        withAnimation {
                                            self.vm.removeSet(ex, at: idx)
                                        }
                                    } label: {
                                        Label("delete", systemImage: "trash")
                                    }
                                }
                            
                            Divider()
                        }

                        Button { vm.addSet(ex) } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("add_a_set")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .padding(.vertical, 8)
                    }
                }
                .frame(maxHeight: 320)
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
            Button { vm.previousExercise() } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("previous").frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .buttonStyle(.bordered)
            .disabled(vm.currentPosition == 1)
            .frame(maxWidth: .infinity)

            Button { vm.nextExercise(withRest: false) } label: {
                HStack {
                    Text("next").frame(maxWidth: .infinity, alignment: .center)
                    Image(systemName: "chevron.right")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.currentPosition == vm.totalExercises)
            .frame(maxWidth: .infinity)
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
    
    @MainActor private func renderRunShareImage() -> Image {
        let h = computeHighlights()
        let card = WorkoutShareCardView(
            title: vm.workout.displayTitle,
            durationText: timeString(vm.elapsed),
            totalExercises: vm.totalExercises,
            currentDate: Date(),
            background: shareBackgroundImage,
            bestRM: h.bestRM,
            totalVolume: h.totalVolume,
            starExerciseName: h.star
        )
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0
        return Image(uiImage: renderer.uiImage ?? UIImage())
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

private struct SetRowView: View {
    let ex: Workout.Exercise
    let idx: Int
    @ObservedObject var vm: WorkoutRunViewModel

    @State private var repsText: String = ""
    @State private var weightText: String = ""
    @FocusState private var repsFocused: Bool
    @FocusState private var weightFocused: Bool

    var isDone: Bool { (idx + 1) <= vm.getSetsDone(for: ex) }
    
    // ✅ Correction du label pour éviter le conflit 'reps' (Int vs Enum)
    var effortLabel: String {
        let type = ex.effort
        switch type {
        case .reps: return "Reps"
        case .time: return "Sec"
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

            // MARK: - Ligne 1 (Header)
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Set \(idx + 1)")
                        .font(.headline)

                    Button {
                        vm.toggleWarmup(for: ex, setIndex: idx)
                    } label: {
                        Text(vm.isWarmup(for: ex, setIndex: idx) ? "Échauffement" : "Série")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                vm.isWarmup(for: ex, setIndex: idx)
                                ? Color.orange.opacity(0.22)
                                : Color.secondary.opacity(0.12)
                            )
                            .foregroundStyle(
                                vm.isWarmup(for: ex, setIndex: idx) ? .orange : .secondary
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isDone)
                }

                Spacer()

                // ✅ Checkbox toujours visible + hitbox confortable
                Button {
                    vm.toggleSetDone(ex, setNumber: idx + 1)
                } label: {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(isDone ? Color.accentColor : Color.secondary)
                    
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 44, height: 44) // ✅ hit area
                }
                .buttonStyle(.plain)
            }

            // MARK: - Ligne 2 (Inputs)
            HStack(spacing: 16) {

                metricBlock(
                    title: effortLabel,
                    valueText: "\(vm.reps(for: ex, setIndex: idx))",
                    minusAction: { vm.bumpReps(-1, for: ex, setIndex: idx) },
                    plusAction:  { vm.bumpReps(+1, for: ex, setIndex: idx) },
                    footer: {
                        if isDone, let diff = vm.getDiff(for: ex, setIndex: idx), diff.repsDiff != 0 {
                            diffBadge(value: Double(diff.repsDiff), unit: "")
                        }
                    }
                )
                .disabled(isDone)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Poids")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Button(action: {
                            vm.bumpWeight(-2.5, for: ex, setIndex: idx)
                            updateLocalFields()
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        HStack(spacing: 6) {
                            TextField("—", text: $weightText)
                                .keyboardType(.decimalPad)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .multilineTextAlignment(.leading)
                                .frame(minWidth: 44, alignment: .leading)
                                .focused($weightFocused)
                                .submitLabel(.done)
                                .onSubmit { commitWeight() }

                            Text("kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            DispatchQueue.main.async {
                                weightFocused = true
                            }
                        }

                        Button(action: {
                            vm.bumpWeight(+2.5, for: ex, setIndex: idx)
                            updateLocalFields()
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
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

            // (Optionnel) delete inline -> je te conseille de le virer et garder swipeActions only
        }
        .onAppear { updateLocalFields() }
        .onChange(of: vm.weight(for: ex, setIndex: idx)) { _ in
            if !weightFocused { updateLocalFields() }
        }
        .onChange(of: weightFocused) { focused in
            if !focused { commitWeight() }
        }
        .toolbar {
            if weightFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        commitWeight()
                        weightFocused = false
                    }
                }
            }
        }
        .padding(14)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isDone ? Color.accentColor.opacity(0.20) : Color.clear, lineWidth: 1)
        )
    }


    private func updateLocalFields() {
        let r = vm.reps(for: ex, setIndex: idx)
        repsText = String(r)
        let w = vm.weight(for: ex, setIndex: idx)
        weightText = w == 0 ? "" : (w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(w))
    }

    private func commitWeight() {
        let t = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            vm.setWeight(0, for: ex, setIndex: idx)
            return
        }
        let normalized = t.replacingOccurrences(of: ",", with: ".")
        if let v = Double(normalized) {
            let clamped = max(0, min(1000, v))
            vm.setWeight(clamped, for: ex, setIndex: idx)
        }
    }
    
    private func diffBadge(value: Double, unit: String) -> some View {
        let isPositive = value > 0
        let formattedValue = value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
        let text = (isPositive ? "+" : "") + formattedValue + unit
        
        return Text(text)
            .font(.system(size: 9, weight: .black, design: .rounded))
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
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
        Text(title)
            .font(.caption)
            .foregroundStyle(.secondary)

        HStack(spacing: 12) {
            Button(action: minusAction) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Text(valueText)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .frame(minWidth: 44, alignment: .leading)

                if let suffix {
                    Text(suffix).font(.caption).foregroundStyle(.secondary)
                }
            }

            Button(action: plusAction) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }

        footer()
            .frame(height: 16, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}


private func formatWeight(_ w: Double) -> String {
    if w == 0 { return "—" }
    return w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : String(format: "%.1f", w)
}

struct PRCelebrationView: View {
    @State private var animateTrophy = false
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                // Effet de halo derrière le trophée
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .scaleEffect(animateTrophy ? 1.5 : 0.8)
                    .opacity(animateTrophy ? 0 : 1)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.yellow)
                    .scaleEffect(animateTrophy ? 1.2 : 0.9)
                    .rotationEffect(.degrees(animateTrophy ? 10 : -10))
            }
            
            VStack {
                Text("NOUVEAU RECORD !")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.black)
                    .foregroundStyle(.yellow)
                
                Text("Tu viens de dépasser tes limites.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .scaleEffect(animateTrophy ? 1.0 : 0.8)
        }
        .padding(40)
        .background(.ultraThinMaterial)
        .cornerRadius(30)
        .shadow(radius: 20)
        .onAppear {
            withAnimation(.interpolatingSpring(stiffness: 50, damping: 5).repeatForever(autoreverses: true)) {
                animateTrophy = true
            }
        }
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
            // Background photo or fallback gradient
            if let bg = background {
                GeometryReader { proxy in
                    Image(uiImage: bg)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }
            } else {
                LinearGradient(colors: [.orange.opacity(0.3), .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }

            // Bottom fade to ensure readability
            VStack { Spacer() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.black.opacity(0.75), .black.opacity(0.0)]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .opacity(0.9)
                )
                .allowsHitTesting(false)

            // Bottom content
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 12) {
                    Label(durationText, systemImage: "clock.fill")
                    Text("·")
                    Label("\(totalExercises) exos", systemImage: "dumbbell.fill")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .opacity(0.95)

                // Highlights
                HStack(spacing: 12) {
                    if let vol = totalVolume {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Volume total").font(.caption).foregroundStyle(.secondary)
                            Text("\(Int(vol)) kg").bold()
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if let rm = bestRM, rm > 0 {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Meilleur 1RM est.").font(.caption).foregroundStyle(.secondary)
                            Text(String(format: "%.1f kg", rm)).bold()
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if let star = starExerciseName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exo star").font(.caption).foregroundStyle(.secondary)
                            Text(LocalizedStringKey(star)).bold()
                                .lineLimit(1)
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                HStack {
                    Text("MuscleMonitor")
                        .font(.caption).bold()
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    Spacer()
                    Text(currentDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(width: 1080/3, height: 1920/3) // story 9:16 (renderer scale = 3)
        .clipped()
    }
}

struct AddExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Workout.Exercise) -> Void

    // Catalog from the central mapping
    private let allNames: [String] = Workout.Exercise.muscleMapping.keys.sorted()

    @State private var searchText: String = ""
    @State private var selectedName: String = Workout.Exercise.muscleMapping.keys.sorted().first ?? ""
    @State private var equipment: Workout.Equipment? = nil

    // Quick config
    @State private var sets: Int = 3
    @State private var restSec: Int = 90
    @State private var effortMode: Int = 0 // 0 = reps, 1 = time
    @State private var targetReps: Int = 10
    @State private var targetSeconds: Int = 60

    private var filteredNames: [String] {
        guard !searchText.isEmpty else { return allNames }
        return allNames.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private var isTimeBasedDefault: Bool {
        // Time/cardio defaults
        let tags = Workout.Exercise.muscleMapping[selectedName] ?? []
        if tags.contains(.cardio) { return true }
        let timeBasedNames: Set<String> = [
            "plank", "dynamic_plank", "hollow_body_hold", "running",
            "rowing_machine", "stationary_bike", "elliptical_bike",
            "side_plank", "mountain_climbers"
        ]
        return timeBasedNames.contains(selectedName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("exercise") {
                    Picker("name", selection: $selectedName) {
                        ForEach(allNames, id: \.self) { key in
                            Text(LocalizedStringKey(key)).tag(key)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    Picker("equipment", selection: Binding<Workout.Equipment?>(
                        get: { equipment },
                        set: { equipment = $0 }
                    )) {
                        Text("none").tag(Optional<Workout.Equipment>.none)
                        ForEach(Workout.Equipment.allCases) { eq in
                            Text(eq.display).tag(Optional(eq))
                        }
                    }
                }

                Section("settings") {
                    Stepper("Séries : \(sets)", value: $sets, in: 1...10)
                    Stepper("Repos : \(restSec)s", value: $restSec, in: 0...300, step: 15)

                    Picker("type_of_effort", selection: $effortMode) {
                        Text("reps").tag(0)
                        Text("time").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if effortMode == 0 {
                        Stepper("Répétitions : \(targetReps)", value: $targetReps, in: 1...100)
                    } else {
                        Stepper("Durée : \(targetSeconds)s", value: $targetSeconds, in: 5...600, step: 5)
                    }
                }
            }
            .navigationTitle("add_exercise")
            .onAppear {
                // Initialize effort mode sensibly on first appear
                effortMode = isTimeBasedDefault ? 1 : 0
            }
            .onChange(of: selectedName) { _ in
                effortMode = isTimeBasedDefault ? 1 : 0
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("add") {
                        // Build the exercise from current selections
                        let tags = Workout.Exercise.muscleMapping[selectedName] ?? [.dos]
                        let mainTag = tags.first ?? .dos
                        let effort: Workout.Effort = (effortMode == 0) ? .reps(targetReps) : .time(seconds: targetSeconds)
                        let ex = Workout.Exercise(
                            name: selectedName,
                            muscleGroup: mainTag,
                            equipment: equipment,
                            sets: sets,
                            effort: effort,
                            restSec: restSec
                        )
                        onAdd(ex)
                        dismiss()
                    }
                }
            }
        }
    }
}

