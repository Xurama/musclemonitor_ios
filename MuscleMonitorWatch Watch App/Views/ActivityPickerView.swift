import SwiftUI

struct ActivityPickerView: View {
    @EnvironmentObject var cardioManager: CardioSessionManager

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "figure.run.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.title3)
                    Text("MuscleMonitor")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .padding(.top, 4)

                if cardioManager.isStarting {
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(Color.accentColor)
                        Text("Connexion à HealthKit…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ForEach(CardioActivityType.allCases) { activity in
                        ActivityButton(activity: activity) {
                            cardioManager.configure(activityType: activity)
                            cardioManager.start()
                        }
                    }
                }
            }
            .padding(.horizontal, 6)
        }
    }
}

// MARK: - Bouton d'activité
private struct ActivityButton: View {
    let activity: CardioActivityType
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icone dans un cercle coloré
                ZStack {
                    Circle()
                        .fill(activity.color.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: activity.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(activity.color)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(activity.displayName)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text(activity.subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
