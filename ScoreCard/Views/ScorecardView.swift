import SwiftUI

struct ScorecardView: View {
    @EnvironmentObject var vm: RoundViewModel
    @State private var selectedHole: Int = 1
    @State private var showScoreboard = false
    @State private var showCompletionConfirmation = false
    @State private var showRoundReview = false
    @State private var didPromptForCompletion = false

    var round: Round { vm.round! }
    var holes: [Hole] { round.holeList }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                holeSelector
                    .padding(.vertical, 8)
                    .background(Color(.systemGroupedBackground))

                if let hole = holes.first(where: { $0.number == selectedHole }) {
                    holeCard(hole)
                }

                Spacer()

                // Summary footer
                summaryFooter
            }
            .navigationTitle(round.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showScoreboard = true
                    } label: {
                        Image(systemName: "list.number")
                    }
                }
            }
            .sheet(isPresented: $showScoreboard) {
                ScoreboardView()
                    .environmentObject(vm)
            }
            .sheet(isPresented: $showRoundReview) {
                RoundReviewView()
                    .environmentObject(vm)
            }
            .alert("Complete Round?", isPresented: $showCompletionConfirmation) {
                Button("Keep Scoring", role: .cancel) { }
                Button("Complete Round") {
                    Task {
                        await vm.finishRound()
                        if vm.round?.isFinished == true {
                            showRoundReview = true
                        }
                    }
                }
            } message: {
                Text("All scores are entered for the final hole. Review the results and finish this round?")
            }
            .onChange(of: vm.scores.count) { _, _ in
                promptForCompletionIfNeeded()
            }
            .onAppear {
                vm.startPolling()
                promptForCompletionIfNeeded()
            }
            .onDisappear {
                vm.stopPolling()
            }
        }
    }

    // MARK: - Hole Selector

    private var holeSelector: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(holes) { hole in
                        let isSelected = hole.number == selectedHole
                        let isComplete = vm.players.allSatisfy {
                            vm.grossScore(playerID: $0.id, hole: hole.number) != nil
                        }
                        Button {
                            withAnimation { selectedHole = hole.number }
                        } label: {
                            VStack(spacing: 2) {
                                Text("\(hole.number)")
                                    .font(.callout.bold())
                                Text("P\(hole.par)")
                                    .font(.caption2)
                            }
                            .frame(width: 44, height: 44)
                            .background(
                                isSelected ? Color.green :
                                isComplete ? Color.green.opacity(0.25) :
                                Color(.secondarySystemGroupedBackground)
                            )
                            .foregroundStyle(isSelected ? .white : .primary)
                            .clipShape(Circle())
                        }
                        .id(hole.number)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: selectedHole) { _, new in
                withAnimation { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    // MARK: - Hole Card

    private func holeCard(_ hole: Hole) -> some View {
        VStack(spacing: 0) {
            // Hole header
            HStack {
                VStack(alignment: .leading) {
                    Text("Hole \(hole.number)")
                        .font(.title2.bold())
                    Text("Par \(hole.par)  •  Stroke Index \(hole.strokeIndex)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 16) {
                    if selectedHole > 1 {
                        Button { selectedHole -= 1 } label: {
                            Image(systemName: "chevron.left")
                        }
                    }
                    if selectedHole < holes.count {
                        Button { selectedHole += 1 } label: {
                            Image(systemName: "chevron.right")
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))

            // Score entry per player
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.players) { player in
                        PlayerHoleScoreRow(player: player, hole: hole)
                            .environmentObject(vm)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Summary Footer

    private var summaryFooter: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(vm.players) { player in
                        let entry = vm.leaderboard.first { $0.id == player.id }
                        VStack(spacing: 2) {
                            Text(player.name)
                                .font(.caption.bold())
                                .lineLimit(1)
                            Text(entry.map { formatToPar($0.toPar) } ?? "-")
                                .font(.headline)
                                .foregroundStyle(toParColor(entry?.toPar))
                            Text(entry.map { "\($0.holesPlayed) holes" } ?? "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 60)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
    }

    private func formatToPar(_ toPar: Int) -> String {
        if toPar == 0 { return "E" }
        return toPar > 0 ? "+\(toPar)" : "\(toPar)"
    }

    private func toParColor(_ toPar: Int?) -> Color {
        guard let toPar else { return .primary }
        if toPar < 0 { return .red }
        if toPar > 0 { return .blue }
        return .primary
    }

    private func promptForCompletionIfNeeded() {
        guard !didPromptForCompletion,
              round.isFinished == false,
              !vm.players.isEmpty,
              isRoundFullyScored else { return }

        didPromptForCompletion = true
        showCompletionConfirmation = true
    }

    private var isRoundFullyScored: Bool {
        holes.allSatisfy { hole in
            vm.players.allSatisfy { player in
                vm.grossScore(playerID: player.id, hole: hole.number) != nil
            }
        }
    }
}

// MARK: - Player Hole Score Row

struct PlayerHoleScoreRow: View {
    @EnvironmentObject var vm: RoundViewModel
    let player: Player
    let hole: Hole

    @State private var inputScore: Int = 0
    @State private var isEditing = false

    var currentGross: Int? { vm.grossScore(playerID: player.id, hole: hole.number) }
    var strokes: Int { player.strokesOnHole(hole) }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(player.name)
                        .font(.headline)
                    if strokes > 0 {
                        // Dot indicator for handicap stroke(s)
                        ForEach(0..<strokes, id: \.self) { _ in
                            Circle().fill(Color.red).frame(width: 6, height: 6)
                        }
                    }
                }
                Text("CH: \(player.courseHandicap)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Score stepper
            HStack(spacing: 12) {
                Button {
                    let cur = currentGross ?? hole.par
                    let newVal = max(1, cur - 1)
                    Task { await vm.enterScore(playerID: player.id, holeNumber: hole.number, grossStrokes: newVal) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 1) {
                    if let gross = currentGross {
                        Text("\(gross)")
                            .font(.title.bold())
                            .frame(width: 44)
                            .foregroundStyle(scoreColor(gross: gross, par: hole.par, strokes: strokes))
                        let net = gross - strokes
                        Text("net \(net)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("-")
                            .font(.title.bold())
                            .frame(width: 44)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    let cur = currentGross ?? (hole.par - 1)
                    Task { await vm.enterScore(playerID: player.id, holeNumber: hole.number, grossStrokes: cur + 1) }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func scoreColor(gross: Int, par: Int, strokes: Int) -> Color {
        let net = gross - strokes
        switch net - par {
        case ...(-2): return .yellow  // Eagle or better
        case -1:      return .red     // Birdie
        case 0:       return .primary // Par
        case 1:       return .blue    // Bogey
        default:      return .gray    // Double+
        }
    }
}
