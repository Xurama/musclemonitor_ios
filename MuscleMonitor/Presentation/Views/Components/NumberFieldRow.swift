//
//  NumberFieldRow.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//


import SwiftUI

struct NumberFieldRow: View {
    let title: String
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
            Spacer()
            TextField("", value: $value, format: .number)
                .multilineTextAlignment(.center)
                .frame(width: 64)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: value) { _, newVal in
                    value = min(max(newVal, range.lowerBound), range.upperBound)
                }
        }
    }
}

