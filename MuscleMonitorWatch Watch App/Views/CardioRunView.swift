import SwiftUI

struct CardioRunView: View {
    @EnvironmentObject var cardioManager: CardioSessionManager
    @EnvironmentObject var gpsManager: GPSManager
    @State private var showEndConfirm = false

    private var activityColor: Color { cardioManager.activityType.color }

    /// Allure en min:ss aux 100 mètres (natation)
    private var swimPacePer100m: String {
        guard cardioManager.distanceMeters > 5 else { return "--:--" }
        let secPer100m = Double(cardioManager.elapsedSeconds) / (cardioManager.distanceMeters / 100)
        return String(format: "%d:%02d", Int(secPer100m) / 60, Int(secPer100m) % 60)
    }

    var body: some View {
        TabView {
            metricsPage
            if cardioManager.activityType.isOutdoor { pacePage }
        }
        .tabViewStyle(.page)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    cardioManager.isPaused ? cardioManager.resume() : cardioManager.pause()
                } label: {
                    Image(systemName: cardioManager.isPaused ? "play.fill" : "pause.fill")
                        .foregroundStyle(cardioManager.isPaused ? .orange : .primary)
                }
            }
        }
        .navigationTitle("")  // Titre masqué : l'icône + nom est dans le contenu
        .onTapGesture(count: 2) { showEndConfirm = true }
        .confirmationDialog("Terminer ?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("Terminer", role: .destructive) { cardioManager.end() }
            Button("Annuler", role: .cancel) {}
        }
    }

    // MARK: - Page métriques
    private var metricsPage: some View {
        VStack(spacing: 8) {

            // Chrono + icône de l'activité
            VStack(spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: cardioManager.activityType.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(activityColor)
                    Text(cardioManager.formattedElapsed)
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(cardioManager.isPaused ? .orange : .primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }

                // Indicateur d'activité
                Capsule()
                    .fill(cardioManager.isPaused ? .orange : activityColor)
                    .frame(width: cardioManager.isPaused ? 24 : 40, height: 3)
                    .animation(.spring(duration: 0.3), value: cardioManager.isPaused)
            }

            // Grille 2×2
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
                // Distance : mètres pour la natation, km pour les autres
                if cardioManager.activityType == .swimming {
                    MetricTile(
                        value: "\(Int(cardioManager.distanceMeters))",
                        unit: "mètres",
                        icon: "arrow.left.and.right",
                        color: activityColor
                    )
                } else {
                    MetricTile(
                        value: String(format: "%.2f", cardioManager.distanceKm),
                        unit: "km",
                        icon: "mappin.and.ellipse",
                        color: activityColor
                    )
                }

                MetricTile(
                    value: cardioManager.heartRate > 0 ? "\(Int(cardioManager.heartRate))" : "--",
                    unit: "bpm",
                    icon: "heart.fill",
                    color: .red
                )
                MetricTile(
                    value: "\(Int(cardioManager.activeCalories))",
                    unit: "kcal",
                    icon: "flame.fill",
                    color: .orange
                )

                // Allure : /100m pour natation, /km pour outdoor
                if cardioManager.activityType.isOutdoor {
                    MetricTile(
                        value: gpsManager.paceFormatted,
                        unit: "/ km",
                        icon: "speedometer",
                        color: .green
                    )
                } else {
                    MetricTile(
                        value: swimPacePer100m,
                        unit: "/ 100m",
                        icon: "speedometer",
                        color: .cyan
                    )
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Page allure (outdoor)
    private var pacePage: some View {
        VStack(spacing: 12) {
            // Vitesse principale
            VStack(spacing: 2) {
                Image(systemName: "speedometer")
                    .font(.caption)
                    .foregroundStyle(activityColor)
                Text(gpsManager.paceFormatted)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("allure")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Vitesse + Altitude
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f", gpsManager.currentSpeedMs * 3.6))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    Text("km/h")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 30)

                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.green)
                        Text(String(format: "%.0f", gpsManager.currentAltitude))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                    }
                    Text("m alt.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Tuile métrique réutilisable
private struct MetricTile: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(unit)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.25), lineWidth: 0.5)
        )
    }
}
