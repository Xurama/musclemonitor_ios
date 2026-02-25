//
//  CardView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//


import SwiftUI

struct CardView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("weekly_progress").font(.headline)
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}
