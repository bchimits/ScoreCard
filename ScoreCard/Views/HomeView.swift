import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: RoundViewModel
    @State private var joinCode = ""
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScoreCardTheme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        VStack(spacing: 18) {
                            ScoreCardLogo()
                                .frame(maxWidth: 380)
                                .padding(.top, 46)

                            VStack(spacing: 8) {
                                Text("Golf scoring for every group")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)

                                Text("Create a round, invite players, and keep the leaderboard clear from the first tee to the clubhouse.")
                                    .font(.subheadline)
                                    .foregroundStyle(ScoreCardTheme.mutedText)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(3)
                                    .padding(.horizontal, 12)
                            }
                        }

                        VStack(spacing: 14) {
                            Button {
                                showCreate = true
                            } label: {
                                HomeActionLabel(
                                    title: "Create New Round",
                                    subtitle: "Set course, format, and players",
                                    systemImage: "plus.circle.fill"
                                )
                            }
                            .buttonStyle(PrimaryHomeButtonStyle())

                            Button {
                                showJoin = true
                            } label: {
                                HomeActionLabel(
                                    title: "Join a Round",
                                    subtitle: "Use a shared 6-character code",
                                    systemImage: "person.badge.plus"
                                )
                            }
                            .buttonStyle(SecondaryHomeButtonStyle())

                            HStack(spacing: 10) {
                                Image(systemName: "icloud.fill")
                                    .imageScale(.small)
                                Text("Live scoring syncs with your group")
                                    .font(.footnote.weight(.medium))
                            }
                            .foregroundStyle(ScoreCardTheme.mutedText)
                            .padding(.top, 4)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 36)
                    }
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                }
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

// MARK: - Home Styling

private enum ScoreCardTheme {
    static let navy = Color(red: 0.018, green: 0.055, blue: 0.095)
    static let surface = Color(red: 0.055, green: 0.105, blue: 0.165)
    static let surfaceStroke = Color.white.opacity(0.12)
    static let green = Color(red: 0.45, green: 0.78, blue: 0.09)
    static let greenDark = Color(red: 0.24, green: 0.50, blue: 0.04)
    static let mutedText = Color(red: 0.72, green: 0.78, blue: 0.84)

    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.01, green: 0.025, blue: 0.045),
                navy,
                Color(red: 0.025, green: 0.09, blue: 0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct ScoreCardLogo: View {
    var body: some View {
        Image("ScoreCardLogo")
            .resizable()
            .scaledToFit()
            .shadow(color: .black.opacity(0.28), radius: 18, x: 0, y: 12)
            .padding(.horizontal, 24)
    }
}

private struct HomeActionLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .opacity(0.72)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

private struct PrimaryHomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(18)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        ScoreCardTheme.green,
                        ScoreCardTheme.greenDark
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .shadow(color: ScoreCardTheme.green.opacity(configuration.isPressed ? 0.08 : 0.28), radius: 16, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct SecondaryHomeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(18)
            .foregroundStyle(.white)
            .background(ScoreCardTheme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(ScoreCardTheme.surfaceStroke, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

// MARK: - Join Sheet

struct JoinRoundView: View {
    @EnvironmentObject var vm: RoundViewModel
    @Environment(\.dismiss) var dismiss
    @State private var code = ""
    @State private var playerName = ""
    @State private var handicapIndex = 0

    private var canJoin: Bool {
        code.count == 6 && !playerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isLoading
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. AB12CD", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.title2.monospaced())
                        .multilineTextAlignment(.center)
                } header: {
                    Text("Round Code")
                } footer: {
                    Text("Ask the round creator for the 6-character code.")
                }

                Section {
                    TextField("Name", text: $playerName)
                        .textContentType(.name)

                    Picker("Handicap Index", selection: $handicapIndex) {
                        ForEach(0...32, id: \.self) { index in
                            Text("\(index)").tag(index)
                        }
                    }
                } header: {
                    Text("Your Player Info")
                } footer: {
                    Text("For team games, join first. The group can assign team colors after players are in the round.")
                }

                Section {
                    Button("Join Round") {
                        Task {
                            await vm.joinRound(
                                code: code,
                                playerName: playerName,
                                handicapIndex: Double(handicapIndex)
                            )
                            if vm.round != nil { dismiss() }
                        }
                    }
                    .disabled(!canJoin)
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
