import SwiftUI

struct CardioSummaryView: View {
    let result: CardioSessionResult
    let onDismiss: () -> Void

    private var avgBpm: Double {
        guard !result.heartRateSamples.isEmpty else { return 0 }
        return result.heartRateSamples.map(\.bpm).reduce(0, +) / Double(result.heartRateSamples.count)
    }

    private var avgPace: String {
        guard result.activityType.isOutdoor, result.distanceKm > 0 else { return "" }
        let pace = Double(result.durationSec) / result.distanceKm
        return String(format: "%d:%02d /km", Int(pace) / 60, Int(pace) % 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {

                // Header activité
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(result.activityType.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                        Image(systemName: result.activityType.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(result.activityType.color)
                    }
                    Text(result.activityType.displayName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Séance terminée")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 4)

                // Métriques clés
                VStack(spacing: 6) {
                    // Durée — mise en avant
                    HStack {
                        Label("Durée", systemImage: "timer")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formattedDuration(result.durationSec))
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                    // Distance
                    summaryRow(
                        icon: "mappin.and.ellipse",
                        label: "Distance",
                        value: String(format: "%.2f km", result.distanceKm),
                        color: result.activityType.color
                    )

                    // Calories
                    summaryRow(
                        icon: "flame.fill",
                        label: "Calories",
                        value: "\(Int(result.activeCalories)) kcal",
                        color: .orange
                    )

                    // FC moyenne
                    if avgBpm > 0 {
                        summaryRow(
                            icon: "heart.fill",
                            label: "FC moy.",
                            value: "\(Int(avgBpm)) bpm",
                            color: .red
                        )
                    }

                    // Allure (outdoor)
                    if !avgPace.isEmpty {
                        summaryRow(
                            icon: "speedometer",
                            label: "Allure moy.",
                            value: avgPace,
                            color: .green
                        )
                    }
                }

                // Bouton fermer
                Button(action: onDismiss) {
                    Text("Fermer")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(result.activityType.color, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func summaryRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }

    private func formattedDuration(_ s: Int) -> String {
        let h = s / 3600
        let m = (s % 3600) / 60
        let r = s % 60
        if h > 0 { return String(format: "%dh%02dm", h, m) }
        return String(format: "%dm%02ds", m, r)
    }
}
