//
//  MuscleMonitorWatchApp.swift
//  MuscleMonitorWatch Watch App
//
//  Created by Lucas Philippe on 10/04/2026.
//

import SwiftUI

@main
struct MuscleMonitorWatch_Watch_AppApp: App {
    @StateObject private var cardioManager = CardioSessionManager()
    @StateObject private var gpsManager    = GPSManager()

    var body: some Scene {
        WindowGroup {
            RootWatchView()
                .environmentObject(cardioManager)
                .environmentObject(gpsManager)
                .task {
                    // Injecte le GPS dans le manager de session
                    cardioManager.gpsManager = gpsManager
                    // La localisation est rapide et non-bloquante
                    gpsManager.requestAuthorization()
                    // HealthKit est demandé au démarrage d'une séance (startSession)
                    // pour ne pas bloquer le lancement de l'app
                }
        }
    }
}
