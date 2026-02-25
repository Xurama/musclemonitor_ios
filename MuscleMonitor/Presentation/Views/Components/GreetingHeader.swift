//
//  GreetingHeader.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//


import SwiftUI

struct GreetingHeader: View {
    let name: String
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("hi \(name)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Spacer()
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .accessibilityLabel("add_a_workout")
        }
    }
}
