//
//  WeeklyProgressCard.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//


import SwiftUI

struct WeeklyProgressCard: View {
    let completed: Int
    let target: Int

    private var ratio: Double {
        guard target > 0 else { return 0 }
        return min(1.0, Double(completed) / Double(target))
    }

    var body: some View {
        CardView() {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("workouts \(completed) \(target)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: ratio)
                        .progressViewStyle(.linear)
                }
                Spacer()
                ZStack {
                    Circle().stroke(lineWidth: 6).opacity(0.2)
                    Circle()
                        .trim(from: 0, to: ratio)
                        .stroke(style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: ratio)
                    Text("\(Int(ratio*100))%").font(.caption)
                }
                .frame(width: 54, height: 54)
            }
        }
    }
}
