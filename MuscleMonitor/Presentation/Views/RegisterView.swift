//
//  RegisterView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

struct RegisterView: View {
    @StateObject private var vm: RegisterViewModel

    init(vm: RegisterViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("choose_name").font(.largeTitle).bold()

            TextField("username", text: $vm.name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textFieldStyle(.roundedBorder)

            if let e = vm.error {
                Text(e).foregroundStyle(.red).font(.footnote)
            }

            Button {
                vm.register()
            } label: {
                if vm.isLoading { ProgressView() }
                else { Text("next").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)
        }
        .padding()
        .navigationTitle("on_boarding")
    }
}
