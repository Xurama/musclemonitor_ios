//
//  LiveActivityContent.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 19/09/2025.
//

import SwiftUI
import WidgetKit

// Vue Lock Screen / Banners
struct WorkoutLockScreenView: View {
    let s: WorkoutLiveAttributes.ContentState

    var body: some View {
        VStack(spacing: 12) {
            // Header : Nom du Workout
            HStack {
                Text(s.workoutTitle.uppercased())
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                Spacer()
                // Petit indicateur de progression circulaire
                CircleProgressView(progress: s.progress)
                    .frame(width: 20, height: 20)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    // L'exercice actuel est l'info principale
                    Text(LocalizedStringKey(s.exerciseName))
                        .font(.title3).bold()
                    
                    // Badges de série et prochaines reps
                    HStack(spacing: 6) {
                        Text("Set \(s.setIndex)/\(s.totalSets)")
                            .font(.caption2).bold()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(6)
                        
                        if let r = s.nextReps {
                            Text("\(r) reps @ \(Int(s.nextWeight ?? 0))kg")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()

                // Chrono de repos massif si actif
                if s.isResting, let until = s.restEndsAt {
                    VStack(alignment: .trailing) {
                        Text(timerInterval: Date.now...until, countsDown: true)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                        Text("REPOS")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            }
        }
        .padding(16)
    }
}

// Petites vues island
struct IslandCompactLeading: View {
    let s: WorkoutLiveAttributes.ContentState
    var body: some View {
        Image(systemName: s.isResting ? "pause.circle" : "figure.strengthtraining.traditional")
    }
}
struct IslandCompactTrailing: View {
    let s: WorkoutLiveAttributes.ContentState
    var body: some View {
        if s.isResting, let until = s.restEndsAt, until > Date()  {
            Text(timerInterval: Date.now...until, countsDown: true)
                .monospacedDigit()
        } else {
            Text("S\(s.setIndex)").monospacedDigit()
        }
    }
}
struct IslandMinimal: View {
    let s: WorkoutLiveAttributes.ContentState
    var body: some View {
        Image(systemName: s.isResting ? "pause.circle.fill" : "figure.strengthtraining.traditional")
    }
}

// Zone centrale en mode étendu
struct IslandExpandedCenter: View {
    let s: WorkoutLiveAttributes.ContentState
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            Text(s.exerciseName)
                .font(.subheadline).bold().lineLimit(1)

            Text("Série \(s.setIndex)/\(s.totalSets)")
                .font(.caption)

            if let r = s.nextReps {
                let w = s.nextWeight
                Text("Prochaine : \(r) reps\(w != nil ? " × \(Int(w!)) kg" : "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: max(0, min(1, s.progress)))
                .progressViewStyle(.linear)

            if s.isResting, let until = s.restEndsAt, until > Date() {
                HStack(spacing: 6) {
                    Image(systemName: "bed.double.fill")
                    Text(timerInterval: Date.now...until, countsDown: true)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
    }
}

struct CircleProgressView: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
