//
//  WeekStrip.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

struct WeekStrip: View {
    @Binding var selectedDate: Date
    var workingDaysOnly: Bool = true
    var marker: ((Date) -> Bool)? = nil

    private var weekDays: [Date] {
        let all = Calendar.current.weekDates(for: selectedDate)
        return workingDaysOnly ? Array(all.prefix(7)) : all
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(weekDays, id: \.self) { day in              // ⬅️ weekDays
                let isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
                let hasDot = marker?(day) ?? false

                VStack(spacing: 4) {
                    Text(shortWeekday(day))                     // ex: "Lun"
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button {
                        selectedDate = day
                    } label: {
                        Text(dayNumber(day))                    // ex: "23"
                            .font(.headline)
                            .frame(width: 36, height: 36)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : .clear)
                            .clipShape(Circle())
                    }

                    // petit point indicateur s'il y a une séance
                    Circle()
                        .frame(width: 6, height: 6)
                        .opacity(hasDot ? 1 : 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers d'affichage
    private func shortWeekday(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale.current
        fmt.setLocalizedDateFormatFromTemplate("EEE") // lun, mar...
        // En français, "lun." -> on retire le point final si besoin
        return fmt.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private func dayNumber(_ date: Date) -> String {
        let d = Calendar.current.component(.day, from: date)
        return String(d)
    }
}

// MARK: - Extensions utilitaires
