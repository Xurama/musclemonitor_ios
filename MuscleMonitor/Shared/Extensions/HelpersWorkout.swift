//
//  HelpersWorkout.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 30/09/2025.
//

import Foundation

extension Workout {
    /// Titre d’affichage si `name` est vide
    var displayTitle: String {
        if let n = name?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            return n
        }
        let df = DateFormatter()
        df.locale = .current
        df.dateStyle = .medium
        df.timeStyle = .short
        return "Séance \(df.string(from: date))"
    }
}
