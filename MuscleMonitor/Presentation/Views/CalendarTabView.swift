//
//  CalendarTabView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

struct CalendarTabView: View {
    @StateObject private var vm: CalendarViewModel

    // combien de mois avant/après afficher (ex: 12 = -12..+12)
    private let monthsSpan: Int = 12

    init(sessionRepo: WorkoutSessionRepository) {
        _vm = StateObject(wrappedValue: CalendarViewModel(repo: sessionRepo))
    }

    var body: some View {
        mainContent
    }

    private var mainContent: some View {
        ScrollViewReader { proxy in
            calendarScrollView
                .task { await onAppear(proxy: proxy) }
                .sheet(item: selectedDateItemBinding) { item in
                    daySessionsNavigation(for: item)
                }
        }
    }

    private var calendarScrollView: some View {
        ScrollView(.vertical) {
            MonthList(vm: vm, monthsSpan: monthsSpan)
                .padding(.horizontal)
                .padding(.top, 12)
        }
    }

    @MainActor
    private func onAppear(proxy: ScrollViewProxy) async {
        await vm.load()
        if let currentStart = Calendar.current.dateInterval(of: .month, for: Date())?.start {
            withAnimation { proxy.scrollTo(currentStart, anchor: .top) }
        }
    }

    private func daySessionsNavigation(for item: IdentifiedDate) -> some View {
        NavigationStack {
            DaySessionsSheet(date: item.date)
                .environmentObject(vm)
                .navigationTitle(Text(item.date, style: .date))
                .toolbar { shareToolbar(for: item.date) }
        }
    }

    @ToolbarContentBuilder
    private func shareToolbar(for date: Date) -> some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { shareForDate(date) }) {
                Image(systemName: "camera.circle")
            }
            .accessibilityLabel("Instagram Story")
        }
    }

    private func shareForDate(_ date: Date) {
            let sessions = vm.sessions(on: date)
            
            // 1. Déterminer le titre
            let title = sessions.count == 1 ? (sessions.first?.title ?? "Séance") : "Séances du jour"

            // 2. Calculer la durée
            let durationTotal: Int = sessions.reduce(0) { $0 + Int($1.endedAt.timeIntervalSince($1.startedAt)) }

            // 3. Calculer le volume et l'exercice star manuellement
            var calculatedTotalVolume: Double = 0
            var bestExerciseVolume: Double = 0
            var starName: String? = nil

            for session in sessions {
                for exercise in session.exercises {
                    // REPRODUCTION DE LA LOGIQUE DE VOLUME
                    var vol: Double = 0
                    
                    // On vérifie si c'est du cardio (basé sur le nom ou le mapping)
                    let isCardio = Workout.Exercise.muscleMapping[exercise.name]?.contains(.cardio) ?? false
                    
                    if isCardio {
                        let totalSeconds = exercise.sets.reduce(0) { $0 + Double($1.reps) }
                        vol = totalSeconds / 60.0 // Volume en minutes pour le cardio
                    } else {
                        let multiplier = (exercise.equipment == .halteres) ? 2.0 : 1.0
                        vol = exercise.sets.reduce(0) { $0 + (Double($1.reps) * $1.weight) } * multiplier
                    }

                    calculatedTotalVolume += vol
                    
                    if vol > bestExerciseVolume {
                        bestExerciseVolume = vol
                        starName = exercise.name
                    }
                }
            }

            // 4. Créer la carte
            let card = WorkoutShareCardView(
                title: title,
                durationText: timeString(durationTotal),
                totalExercises: sessions.reduce(0) { $0 + $1.exercises.count },
                currentDate: date,
                background: nil,
                bestRM: 0.0,
                totalVolume: calculatedTotalVolume,
                starExerciseName: starName
            )

        // 5. Rendu de l'image
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3.0 // Pour une bonne qualité Instagram
        
        if let uiImage = renderer.uiImage {
            if InstagramStorySharing.canShareToStories() {
                InstagramStorySharing.share(
                    sticker: uiImage,
                    backgroundColor: UIColor.black,
                    backgroundImage: nil,
                    attributionURL: URL(string: "https://musclemonitor.app")
                )
            } else {
                let av = UIActivityViewController(activityItems: [uiImage], applicationActivities: nil)
                // Utilisation d'une méthode plus moderne pour récupérer le VC
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = windowScene.windows.first?.rootViewController {
                    rootVC.present(av, animated: true)
                }
            }
        }
    }

    // MARK: - Helpers (déplacés ici pour soulager le type-checker)

    private var selectedDateItemBinding: Binding<IdentifiedDate?> {
        Binding<IdentifiedDate?>(
            get: { vm.selectedDate.map { IdentifiedDate(date: $0) } },
            set: { vm.selectedDate = $0?.date }
        )
    }

    private var deletePresented: Binding<Bool> {
        Binding(
            get: { vm.toConfirmDelete != nil },
            set: { if !$0 { vm.toConfirmDelete = nil } }
        )
    }

    private var deleteMessage: Text {
        if let s = vm.toConfirmDelete {
            let f = DateFormatter()
            f.locale = .current
            f.dateStyle = .medium
            f.timeStyle = .short
            return Text("\(s.title) – \(f.string(from: s.endedAt))")
        }
        return Text("")
    }

    // helper pour .sheet(item:)
    private struct IdentifiedDate: Identifiable {
        let id = UUID()
        let date: Date
    }

    private func timeString(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, r) }
        return String(format: "%02d:%02d", m, r)
    }
}

// MARK: - Sous-vue pour alléger le body
private struct MonthList: View {
    @ObservedObject var vm: CalendarViewModel
    let monthsSpan: Int

    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(monthsAroundNow(), id: \.self) { monthStart in
                MonthSection(
                    monthStart: monthStart,
                    hasSessions: { (date: Date) -> Bool in vm.hasSessions(on: date) },
                    onSelectDay: { (date: Date) in
                        if vm.hasSessions(on: date) { vm.selectedDate = date }
                    }
                )
                .id(monthStart)
            }
        }
    }

    private func monthsAroundNow() -> [Date] {
        let cal = Calendar.current
        let nowStart = cal.dateInterval(of: .month, for: Date())!.start
        return (-monthsSpan...monthsSpan).compactMap { off in
            cal.date(byAdding: .month, value: off, to: nowStart)
        }
    }
}

// MARK: - Un mois (titre + header jours + grille)

private struct MonthSection: View {
    let monthStart: Date
    let hasSessions: (Date) -> Bool
    let onSelectDay: (Date) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle(monthStart))
                .font(.headline)
                .padding(.top, 4)

            weekdayHeader

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(buildGridDays(for: monthStart).enumerated()), id: \.offset) { _, day in
                    if let day = day {
                        DayCellView(
                            date: day,
                            inMonth: true, // Plus besoin de vérifier, ils sont forcément dans le mois
                            hasDot: hasSessions(day),
                            onTap: { onSelectDay(day) }
                        )
                    } else {
                        // Case vide pour l'alignement
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
    }

    private var weekdayHeader: some View {
        let symbols = weekdaySymbols()
        return HStack {
            ForEach(symbols, id: \.self) { s in
                Text(s.uppercased())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: d).capitalized
    }

    private func weekdaySymbols() -> [String] {
        var cal = Calendar.current
        cal.locale = .current
        let base = DateFormatter().shortWeekdaySymbols ?? ["M","T","W","T","F","S","S"]
        let shift = (cal.firstWeekday - 1 + 7) % 7
        return Array(base[shift...] + base[..<shift])
    }

    private func buildGridDays(for monthStart: Date) -> [Date?] {
        let cal = Calendar.current
        
        // 1. Nombre de jours dans le mois
        let range = cal.range(of: .day, in: .month, for: monthStart)!
        let numDays = range.count
        
        // 2. Jour de la semaine du 1er du mois (ajusté selon firstWeekday de l'utilisateur)
        let firstWeekdayIndex = ((cal.component(.weekday, from: monthStart) - cal.firstWeekday + 7) % 7)
        
        var grid: [Date?] = []
        
        // 3. Ajouter des "nil" pour les cases vides du mois précédent
        for _ in 0..<firstWeekdayIndex {
            grid.append(nil)
        }
        
        // 4. Ajouter les vrais jours du mois
        for day in 0..<numDays {
            if let date = cal.date(byAdding: .day, value: day, to: monthStart) {
                grid.append(date)
            }
        }
        
        return grid
    }
}

private struct DayCellView: View {
    let date: Date
    let inMonth: Bool
    let hasDot: Bool
    let onTap: () -> Void

    var body: some View {
        let cal = Calendar.current
        let day = cal.component(.day, from: date)
        let isToday = cal.isDateInToday(date)

        Button(action: onTap) {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(inMonth ? .primary : .secondary)
                    .frame(width: 28, height: 28)
                    .background(isToday ? Color.accentColor.opacity(0.15) : .clear)
                    .clipShape(Circle())
                Circle()
                    .frame(width: 6, height: 6)
                    .opacity(hasDot ? 1 : 0)
            }
            .frame(height: 40)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!hasDot)
        .accessibilityLabel(labelText)
    }

    private var labelText: Text {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .full
        return Text(f.string(from: date) + (hasDot ? ", séances disponibles" : ""))
    }
}

