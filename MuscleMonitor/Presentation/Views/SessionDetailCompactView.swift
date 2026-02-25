//
//  SessionDetailCompactView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 26/09/2025.
//


import SwiftUI

struct SessionDetailCompactView: View {
    let session: WorkoutSession
    var tags: [String] = [] // ex: ["Tricep","Core","Shoulders","Chest"]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                if !tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { TagCapsule(text: $0) }
                    }
                    .frame(maxWidth: .infinity, alignment: .center) // centre horizontalement
                    .padding(.top, 6)
                }

                // Date + Titre
                VStack(spacing: 6) {
                    Text(dateTitle(session.endedAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(session.title)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)

                // Stat cards
                HStack(spacing: 12) {
                    StatCard(title: "Durée", value: timeString(session.durationSec))
                    StatCard(title: "Séries", value: "\(totalSets(session))")
                    StatCard(title: "Reps",   value: "\(totalReps(session))")
                }

                // Exercices
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(session.exercises) { ex in
                        ExerciseSection(sessionExercise: ex)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // 1) Construire une carte dédiée pour story
                    let card = ShareCardView(session: session)
                    // 2) Partager en background plein
                    ShareService.shareInstagramStory(background: card,
                                                     topColorHex: "#FFFFFF",
                                                     bottomColorHex: "#FFFFFF")
                    // — ou en sticker :
                    // ShareService.shareInstagramStory(sticker: card)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func dateTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = "MMM d" // "Sept. 16"
        return f.string(from: d)
    }

    private func timeString(_ sec: Int) -> String {
        let m = sec / 60, s = sec % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func totalSets(_ s: WorkoutSession) -> Int {
        s.exercises.reduce(0) { $0 + $1.sets.count }
    }

    private func totalReps(_ s: WorkoutSession) -> Int {
        s.exercises.flatMap { $0.sets }.reduce(0) { $0 + max(0, $1.reps) }
    }
}

// MARK: - Subviews

private struct TagCapsule: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color(.tertiarySystemFill))
            .clipShape(Capsule())
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.footnote).foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ExerciseSection: View {
    let sessionExercise: WorkoutSession.ExerciseResult
    @State private var expanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(sessionExercise.name)
                        .font(.headline)
                    Text(summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if expanded {
                VStack(spacing: 8) {
                    ForEach(Array(sessionExercise.sets.enumerated()), id: \.offset) { i, set in
                        HStack {
                            Text("Set \(i + 1)")
                            Spacer()
                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Text(formatKg(set.weight)).monospacedDigit()
                                    Text("Kg").foregroundStyle(.secondary)
                                }
                                HStack(spacing: 4) {
                                    Text("\(set.reps)").monospacedDigit()
                                    Text("reps").foregroundStyle(.secondary)
                                }
                            }
                        }
                        .font(.body)
                        .padding(.vertical, 4)

                        if i < sessionExercise.sets.count - 1 {
                            Divider().opacity(0.2)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var summaryLine: String {
        let sets = sessionExercise.sets.count
        // si tu as le type d’équipement, concatène-le ici
        return "\(sets) séries"
    }

    private func formatKg(_ w: Double) -> String {
        w.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(w)) : String(format: "%.1f", w)
    }
}

// MARK: - Simple wrap layout (tags)

private struct WrapHStack<Content: View>: View {
    let spacing: CGFloat
    let runSpacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 8, runSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.runSpacing = runSpacing
        self.content = content()
    }

    var body: some View {
        var width: CGFloat = 0
        var height: CGFloat = 0

        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                content
                    .fixedSize()
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0
                            height -= d.height + runSpacing
                        }
                        let result = width
                        width += d.width + spacing
                        return result
                    }
                    .alignmentGuide(.top) { _ in height }
            }
        }
        .frame(height: intrinsicHeight)
    }

    private var intrinsicHeight: CGFloat {
        // hauteur approximative ; comme c’est du contenu court (capsules), ça marche bien
        32
    }
}
