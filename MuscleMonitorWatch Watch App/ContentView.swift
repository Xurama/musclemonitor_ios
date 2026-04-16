//
//  ContentView.swift
//  MuscleMonitorWatch Watch App
//
//  Created by Lucas Philippe on 10/04/2026.
//

import SwiftUI

/// Racine de l'app Watch : orchestre picker → séance → résumé
struct RootWatchView: View {
    @EnvironmentObject var cardioManager: CardioSessionManager
    @State private var sessionResult: CardioSessionResult? = nil

    var body: some View {
        NavigationStack {
            if let result = sessionResult {
                // Résumé post-séance
                CardioSummaryView(result: result) {
                    sessionResult = nil
                }
            } else if cardioManager.isRunning || cardioManager.isStarting {
                // Séance en cours (ou démarrage en attente d'auth)
                CardioRunView()
            } else {
                // Choix de l'activité
                ActivityPickerView()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: .cardioSessionDidEnd)
        ) { note in
            if let result = note.object as? CardioSessionResult {
                sessionResult = result
            }
        }
    }
}
