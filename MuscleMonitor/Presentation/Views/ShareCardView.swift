//
//  ShareCardView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 29/09/2025.
//

import SwiftUI

struct ShareCardView: View {
    let session: WorkoutSession
    
    var body: some View {
        ZStack {
            Color.black // Fond noir pur
            
            VStack(alignment: .leading, spacing: 0) {
                // --- LOGO + NOM (Discret en haut à gauche) ---
                HStack(spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 24))
                    Text("MUSCLE MONITOR")
                        .font(.system(size: 18, weight: .black))
                        .tracking(2)
                }
                .foregroundColor(.white)
                .padding(.top, 80)
                
                // --- TITRE DE SÉANCE & TEMPS (Écrit en GROS) ---
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title.uppercased())
                        .font(.system(size: 72, weight: .black))
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                    
                    HStack {
                        Image(systemName: "clock.fill")
                        Text(timeString(session.durationSec))
                        Text("•")
                        Text(dateTitle(session.endedAt))
                    }
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                }
                .foregroundColor(.white)
                .padding(.top, 60)
                
                // --- LIGNE DE SÉPARATION ---
                Rectangle()
                    .fill(Color.white)
                    .frame(height: 8)
                    .padding(.vertical, 40)

                // --- LISTE DES EXOS (Taille imposante) ---
                VStack(alignment: .leading, spacing: 35) {
                    // On affiche les 6-7 premiers pour garder de la place et de la lisibilité
                    ForEach(session.exercises.prefix(7)) { ex in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ex.name.uppercased())
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(.white)
                            
                            // Détails technique (ex: 4 sets • 12 reps @ 80kg)
                            Text(formatSets(ex.sets))
                                .font(.system(size: 20, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.white) // Badge inversé pour le contraste
                        }
                    }
                }
                
                Spacer()
                
                // --- FOOTER ---
                Text("DONE WITH MUSCLE MONITOR")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, 50)
        }
        .frame(width: 1080, height: 1920) // Résolution Story standard
    }

    // Formate les séries de manière lisible
    private func formatSets(_ sets: [WorkoutSession.SetResult]) -> String {
        let count = sets.count
        guard let bestSet = sets.max(by: { $0.weight < $1.weight }) else { return "" }
        
        // Si toutes les séries sont identiques
        let allSame = sets.allSatisfy { $0.reps == bestSet.reps && $0.weight == bestSet.weight }
        
        if allSame {
            return "\(count) SETS × \(bestSet.reps) @ \(Int(bestSet.weight))KG"
        } else {
            return "\(count) SETS • MAX: \(bestSet.reps) @ \(Int(bestSet.weight))KG"
        }
    }

    private func dateTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM"
        return f.string(from: d)
    }

    private func timeString(_ sec: Int) -> String {
        let m = sec / 60
        return "\(m)MIN"
    }
}
