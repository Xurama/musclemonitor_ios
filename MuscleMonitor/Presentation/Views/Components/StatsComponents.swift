//
//  StatsComponents.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 07/01/2026.
//

import SwiftUI
import Charts
import Foundation // Important pour le formattingContext

struct SurchargeProgressiveSection: View {
    @ObservedObject var vm: StatsViewModel
    
    var body: some View {
        let metrics = vm.currentProgressionMetrics
        VStack(alignment: .leading, spacing: 16) {
            Text("overload_analysis_\(vm.selectedRange.rawValue)").font(.headline)
            HStack(spacing: 12) {
                MetricTrendCard(title: "Tonnage total", value: "\(Int(metrics.currentWeekVolume)) kg", evolution: metrics.volumeEvolution)
                MetricTrendCard(title: "Intensité Moy.", value: String(format: "%.1f kg", metrics.averageIntensity), evolution: metrics.intensityEvolution)
            }
        }
        .padding(.horizontal)
    }
}

struct MetricTrendCard: View {
    let title: String
    let value: String
    let evolution: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold()
            HStack(spacing: 4) {
                Image(systemName: evolution >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(String(format: "%.1f%%", evolution))
            }
            .font(.caption).bold()
            .foregroundStyle(evolution >= 0 ? .green : .red)
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground)).cornerRadius(16)
    }
}

// MARK: - Heatmap Section
// MARK: - Heatmap Section
struct HeatmapSection: View {
    @ObservedObject var vm: StatsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("attendance_calendar").font(.headline)
            
            GitHubHeatmapView(vm: vm, data: vm.currentHeatmapData, range: vm.selectedRange)
            
            VStack(alignment: .leading, spacing: 10) {
                // ✅ LEGENDE DYNAMIQUE SYNCHRONISÉE
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        // On boucle sur les VRAIS noms présents dans tes séances
                        ForEach(vm.uniqueWorkoutNames, id: \.self) { name in
                            MuscleLegendView(color: vm.color(for: name), label: name)
                        }
                        
                        // Optionnel : Ajouter "Autres" si tu as des séances sans titre
                        if vm.uniqueWorkoutNames.isEmpty {
                            MuscleLegendView(color: .gray, label: "Autres")
                        }
                    }
                }
                
                Divider()
                
                // Légende des symboles
                HStack(spacing: 12) {
                    Label("new_record", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Spacer()
                    Text("color_session_type")
                        .font(.caption2)
                        .italic()
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct HeatmapCell: View {
    @ObservedObject var vm: StatsViewModel // ✅ Ajout du VM pour accéder aux couleurs dynamiques
    let activity: StatsViewModel.DayActivity?
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(cellColor)
                .frame(width: 14, height: 14)
            
            if activity?.hasPR == true {
                Image(systemName: "star.fill")
                    .font(.system(size: 6))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var cellColor: Color {
        guard let activity = activity, activity.volume > 0, let title = activity.dominantMuscle else {
            return Color(.systemGray5).opacity(0.5)
        }
        
        // ✅ On utilise ta logique de couleur dynamique basée sur le nom du workout
        return vm.color(for: title)
    }
}

// MARK: - Correlation Section
struct CorrelationSection: View {
    let correlation: [StatsViewModel.CorrelationData]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("nutrition_vs_training").font(.headline)
            Chart(correlation) { item in
                BarMark(x: .value("day", item.day), y: .value("Kcal", item.calories))
                    .foregroundStyle(.orange.opacity(0.3))
                LineMark(x: .value("day", item.day), y: .value("Vol", item.volume / 10))
                    .foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 3)).symbol(Circle())
            }
            .frame(height: 180)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct GitHubHeatmapView: View {
    @ObservedObject var vm: StatsViewModel
    let data: [Date: StatsViewModel.DayActivity]
    let range: StatsRange
    
    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Force le Lundi comme premier jour (1=Dim, 2=Lun)
        return cal
    }()
    
    // On change l'ordre : Lundi est 0, Dimanche est 6
    private let dayLabels = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"]

    private var weeksCount: Int {
        switch range {
        case .m1: return 6
        case .m3: return 13
        case .m6: return 26
        case .m9: return 39
        case .y1: return 52
        default: return 52
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // AXE Y : Jours (Alignés sur Lundi = 0)
            VStack(spacing: 3) {
                Color.clear.frame(height: 12) // Espace pour le nom du mois
                
                ForEach(0..<7, id: \.self) { i in
                    let dayLabel: String = {
                        switch i {
                        case 0: return "Lun"
                        case 2: return "Mer"
                        case 4: return "Ven"
                        case 6: return "Dim"
                        default: return ""
                        }
                    }()
                    
                    Text(dayLabel)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(height: 14)
                }
            }
            .frame(width: 25)

            // AXE X : Grille
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 3) {
                    ForEach((0..<weeksCount).reversed(), id: \.self) { weekIdx in
                        let dateOfFirstDayOfWeek = dateFor(week: weekIdx, day: 0)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(isFirstWeekOfMonth(dateOfFirstDayOfWeek) ? monthName(from: dateOfFirstDayOfWeek) : "")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .frame(height: 12)

                            ForEach(0..<7, id: \.self) { dayIdx in
                                let date = dateFor(week: weekIdx, day: dayIdx)
                                let activity = data[calendar.startOfDay(for: date)]
                                HeatmapCell(vm: vm, activity: activity)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dateFor(week: Int, day: Int) -> Date {
        // Trouve le début de la semaine ISO (Lundi)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let startOfThisWeek = calendar.date(from: components)!
        
        // Recule du nombre de semaines
        let targetWeek = calendar.date(byAdding: .weekOfYear, value: -week, to: startOfThisWeek)!
        
        // Ajoute le jour (0 = Lundi, 6 = Dimanche)
        return calendar.date(byAdding: .day, value: day, to: targetWeek)!
    }

    private func monthName(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.formattingContext = .beginningOfSentence
        fmt.dateFormat = "MMM"
        return fmt.string(from: date)
    }

    private func isFirstWeekOfMonth(_ date: Date) -> Bool {
        let day = calendar.component(.day, from: date)
        return day <= 7
    }
}

struct MuscleSetsDonutChart: View {
    let data: [StatsViewModel.MuscleDistribution]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("workload_series").font(.headline)
            Chart(data) { item in
                SectorMark(
                    angle: .value("sets", item.sets),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .foregroundStyle(by: .value("muscle", item.group))
                .cornerRadius(5)
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct MuscleLegendView: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

// Ajoutez ce composant dans StatsTabView.swift ou StatsComponents.swift

struct StrengthProgressBar: View {
    let progress: StatsViewModel.ForceProgress
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(progress.currentLevel)
                    .font(.caption).bold()
                Spacer()
                if let next = progress.nextLevel {
                    Text(next)
                        .font(.caption).bold()
                        .foregroundColor(.secondary)
                } else {
                    Text("level_max").font(.caption).bold()
                }
            }
            
            // La Barre de progression
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(progress.progress), height: 12)
                }
            }
            .frame(height: 12)
            
            if let weight = progress.weightToNextLevel, let next = progress.nextLevel {
                Text("next_level_when \(String(format: "%.1f", weight)) \(next)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
