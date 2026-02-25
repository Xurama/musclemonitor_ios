//
//  LoginView.swift
//  MuscleMonitor
//
//  Created by Lucas Philippe on 11/09/2025.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var vm: LoginViewModel

    init(vm: LoginViewModel) {
        _vm = StateObject(wrappedValue: vm)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("connexion").font(.largeTitle).bold()

            TextField("username", text: $vm.name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textFieldStyle(.roundedBorder)

            SecureField("password", text: $vm.password)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.go)
                .onSubmit { vm.login() }

            if let e = vm.error {
                Text(e).foregroundStyle(.red).font(.footnote)
            }

            Button {
                vm.login()
            } label: {
                if vm.isLoading { ProgressView() }
                else { Text("login").frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.isLoading)

            NavigationLink("create_account") { EmptyView() } // placeholder (toolbar dans AuthFlow)
                .opacity(0)
        }
        .padding()
        .navigationTitle("login")
    }
}
