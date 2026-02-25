//
//  AppTab.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 02/10/2025.
//


// TabRouter.swift
import SwiftUI

enum AppTab: Hashable {
    case home, stats, calendar, calories, settings
}

final class TabRouter: ObservableObject {
    @Published var selected: AppTab = .home
}
