//
//  WorkoutLiveActivityWidget.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 19/09/2025.
//

import Foundation
import SwiftUI
import ActivityKit
import WidgetKit

struct WorkoutLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutLiveAttributes.self) { context in
            // LOCK SCREEN / BANNERS
            WorkoutLockScreenView(s: context.state)

        } dynamicIsland: { context in
            DynamicIsland {
                // Leading : Icône d'état
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isResting ? "timer" : "figure.strengthtraining.traditional")
                        .foregroundStyle(context.state.isResting ? .orange : .accentColor)
                        .font(.title2)
                }
                
                // Trailing : Pourcentage et indicateur visuel
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .center, spacing: 2) {
                        Text("\(Int(context.state.progress * 100))%")
                            .monospacedDigit()
                            .font(.caption.bold())
                        
                        // Petit indicateur circulaire
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            Circle()
                                .trim(from: 0, to: context.state.progress)
                                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        }
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(-90))
                    }
                }
                
                // Center : Informations principales sur l'exercice
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(LocalizedStringKey(context.state.exerciseName))
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text("Série \(context.state.setIndex) sur \(context.state.totalSets)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Bottom : Actions interactives stylisées
            } compactLeading: {
                IslandCompactLeading(s: context.state)
            } compactTrailing: {
                IslandCompactTrailing(s: context.state)
            } minimal: {
                IslandMinimal(s: context.state)
            }
            .keylineTint(.accentColor)
        }
    }
}


#if DEBUG
extension WorkoutLiveAttributes {
    // Les "attributes" sont fixes et n’ont qu’un workoutId
    static var preview: Self {
        .init(workoutId: "WO-PREVIEW")
    }
}

extension WorkoutLiveAttributes.ContentState {
    // Un état "en cours"
    static var running: Self {
        .init(
            workoutTitle: "Push Day",
            exerciseName: "Développé couché",
            setIndex: 2,
            totalSets: 4,
            nextReps: 8,
            nextWeight: 60,
            progress: 0.42,
            isResting: false,
            restEndsAt: nil
        )
    }

    // Un état "repos"
    static var rest: Self {
        .init(
            workoutTitle: "Push Day",
            exerciseName: "Développé couché",
            setIndex: 3,
            totalSets: 4,
            nextReps: 8,
            nextWeight: 60,
            progress: 0.5,
            isResting: true,
            restEndsAt: Date().addingTimeInterval(45)
        )
    }
}
#endif


@available(iOSApplicationExtension 16.1, *)
#Preview("Lock Screen – Running", as: .content, using: WorkoutLiveAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutLiveAttributes.ContentState.running
}

@available(iOSApplicationExtension 16.1, *)
#Preview("Lock Screen – Rest", as: .content, using: WorkoutLiveAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutLiveAttributes.ContentState.rest
}

@available(iOSApplicationExtension 16.1, *)
#Preview("Island – Expanded", as: .dynamicIsland(.expanded), using: WorkoutLiveAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutLiveAttributes.ContentState.running
}

@available(iOSApplicationExtension 16.1, *)
#Preview("Island – Compact", as: .dynamicIsland(.compact), using: WorkoutLiveAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutLiveAttributes.ContentState.running
}

@available(iOSApplicationExtension 16.1, *)
#Preview("Island – Minimal", as: .dynamicIsland(.minimal), using: WorkoutLiveAttributes.preview) {
    WorkoutLiveActivityWidget()
} contentStates: {
    WorkoutLiveAttributes.ContentState.rest
}
