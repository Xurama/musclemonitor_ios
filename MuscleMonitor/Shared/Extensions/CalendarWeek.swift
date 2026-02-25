//
//  CalendarWeek.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import Foundation
 
extension Calendar {
    /// Retourne les 7 jours de la semaine du `anchor` (Lun→Dim selon locale),
    /// et 14 si tu veux gérer `workingDaysOnly: false`.
    func weekDates(for anchor: Date) -> [Date] {
        var cal = self
        cal.locale = .current

        // Début de semaine (selon locale)
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor))!
        return (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }
}
