//
//  CalendarViewModel.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 26/09/2025.
//

import SwiftUI

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var monthAnchor: Date              // 1er jour du mois affiché
    @Published var selectedDate: Date? = nil
    @Published var sessions: [WorkoutSession] = []
    @Published private(set) var grouped: [Date: [WorkoutSession]] = [:] // startOfDay -> sessions

    private let repo: WorkoutSessionRepository
    private var cal: Calendar { Calendar.current }

    init(repo: WorkoutSessionRepository, initialMonth: Date = Date()) {
        self.repo = repo
        self.monthAnchor = Calendar.current.date(from:
            Calendar.current.dateComponents([.year, .month], from: initialMonth)
        )!
    }

    func load() async {
        do {
            let all = try await repo.list()
            self.sessions = all
            regroup()
        } catch {
            self.sessions = []
            self.grouped = [:]
        }
    }

    private func regroup() {
        let c = cal
        grouped = Dictionary(grouping: sessions) { s in
            c.startOfDay(for: s.endedAt)
        }
    }

    func hasSessions(on date: Date) -> Bool {
        grouped[cal.startOfDay(for: date)] != nil
    }

    func sessions(on date: Date) -> [WorkoutSession] {
        grouped[cal.startOfDay(for: date)] ?? []
    }

    // MARK: - Month navigation
    func previousMonth() {
        monthAnchor = cal.date(byAdding: .month, value: -1, to: monthAnchor)!
    }
    func nextMonth() {
        monthAnchor = cal.date(byAdding: .month, value: 1, to: monthAnchor)!
    }

    // MARK: - Grid building
    struct DayCell: Identifiable {
        let id = UUID()
        let date: Date
        let inCurrentMonth: Bool
    }

    var monthTitle: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "LLLL yyyy"
        return f.string(from: monthAnchor).capitalized
    }

    var weekdaySymbols: [String] {
        var f = DateFormatter()
        f.locale = .current
        f.dateFormat = "EEEEE" // 1 lettre
        return f.shortWeekdaySymbols // peut préférer f.veryShortWeekdaySymbols selon locale
    }

    var gridDays: [DayCell] {
        let c = cal
        let startOfMonth = monthAnchor
        let range = c.range(of: .day, in: .month, for: startOfMonth)!
        let firstWeekdayIndex = c.component(.weekday, from: startOfMonth) // 1..7

        // nombre de cases vides avant le 1
        let leading = (firstWeekdayIndex - c.firstWeekday + 7) % 7

        var days: [DayCell] = []

        // jours du mois précédent (gris)
        if leading > 0 {
            let prevStart = c.date(byAdding: DateComponents(day: -leading), to: startOfMonth)!
            for i in 0..<leading {
                let d = c.date(byAdding: .day, value: i, to: prevStart)!
                days.append(.init(date: d, inCurrentMonth: false))
            }
        }

        // jours du mois courant
        for day in 0..<range.count {
            let d = c.date(byAdding: .day, value: day, to: startOfMonth)!
            days.append(.init(date: d, inCurrentMonth: true))
        }

        // compléter à 6 lignes (42 cases)
        while days.count % 7 != 0 { // compléter la dernière ligne si besoin
            let last = days.last!.date
            let d = c.date(byAdding: .day, value: 1, to: last)!
            days.append(.init(date: d, inCurrentMonth: false))
        }
        while days.count < 42 {
            let last = days.last!.date
            let d = c.date(byAdding: .day, value: 1, to: last)!
            days.append(.init(date: d, inCurrentMonth: false))
        }

        return days
    }
    
    // MARK: - Edit / Delete state
    @Published var toConfirmDelete: WorkoutSession? = nil
    @Published var editingSession: WorkoutSession? = nil

    func requestDelete(_ s: WorkoutSession) { toConfirmDelete = s }

    func confirmDelete() {
        guard let s = toConfirmDelete else { return }
        print("[CAL] Try delete id=", s.id) // 👈

        toConfirmDelete = nil
        sessions.removeAll { $0.id == s.id }
        regroup()

        Task { @MainActor in
            do {
                try await repo.delete(id: s.id)
                print("[CAL] repo.delete OK")
            } catch {
                print("[CAL] repo.delete ERROR:", error)
            }
            await load()
            print("[CAL] after load, sessions:", sessions.count)
        }
    }
    
    func requestEdit(_ s: WorkoutSession) { editingSession = s }

    func applyEdit(_ newValue: WorkoutSession) {
        Task { @MainActor in
            // 🔹 Remplacement simple : delete + add avec le MÊME id
            do { try await repo.delete(id: newValue.id) } catch { /* ok si absent */ }
            do { try await repo.add(newValue) } catch { /* log si besoin */ }

            editingSession = nil
            await load()
        }
    }

}
