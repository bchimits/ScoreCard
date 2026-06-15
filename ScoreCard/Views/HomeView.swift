import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: RoundViewModel
    @State private var joinCode = ""
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                    Text("ScoreCard")
                        .font(.largeTitle.bold())
                    Text("Golf scoring for any group")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 60)
                .padding(.bottom, 48)

                // Buttons
                VStack(spacing: 16) {
                    Button {
                        showCreate = true
                    } label: {
                        Label("Create New Round", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        showJoin = true
                    } label: {
                        Label("Join a Round", systemImage: "person.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreate) {
                RoundSetupView()
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showJoin) {
                JoinRoundView()
                    .environmentObject(vm)
            }
            .alert("Error", isPresented: $vm.showError) {
                Button("OK") {}
            } message: {
                Text(vm.errorMessage ?? "")
            }
        }
    }
}

// MARK: - Join Sheet

struct JoinRoundView: View {
    @EnvironmentObject var vm: RoundViewModel
    @Environment(\.dismiss) var dismiss
    @State private var code = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Enter the 6-character round code") {
                    TextField("e.g. AB12CD", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.title2.monospaced())
                        .multilineTextAlignment(.center)
                }

                Section {
                    Button("Join Round") {
                        Task {
                            await vm.joinRound(code: code)
                            if vm.round != nil { dismiss() }
                        }
                    }
                    .disabled(code.count != 6 || vm.isLoading)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Join a Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if vm.isLoading {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }
}

#Preview {
    HomeView().environmentObject(RoundViewModel())
}
