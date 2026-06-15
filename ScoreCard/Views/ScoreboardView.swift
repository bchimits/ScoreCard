import SwiftUI

struct ScoreboardView: View {
    @EnvironmentObject var vm: RoundViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var round: Round? { vm.round }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let round {
                    // Join code banner
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Join Code")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(round.joinCode)
                                .font(.title2.bold().monospaced())
                                .foregroundStyle(.green)
                        }
                        Spacer()
                        ShareLink(item: "Join my golf round in ScoreCard! Code: \(round.joinCode)") {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.callout)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))

                    Picker("View", selection: $selectedTab) {
                        Text("Leaderboard").tag(0)
                        Text("Scorecard").tag(1)
                        if round.format != .strokePlay {
                            Text("Match Results").tag(2)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if selectedTab == 0 { leaderboardTab }
                    else if selectedTab == 1 { fullScorecardTab }
                    else { matchResultsTab }
                }
            }
            .navigationTitle("Scoreboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.refreshPlayersAndScores() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { vm.startPolling() }
            .onDisappear { vm.stopPolling() }
        }
    }

    // MARK: - Leaderboard Tab

    private var leaderboardTab: some View {
        List {
            ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { idx, entry in
                HStack(spacing: 12) {
                    // Position
                    Text("\(idx + 1)")
                        .font(.title3.bold())
                        .frame(width: 28)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.player.name).font(.headline)
                        HStack(spacing: 8) {
                            Text("Hdcp \(entry.player.handicapIndex, specifier: "%.1f")")
                            Text("•")
                            Text("\(entry.holesPlayed) holes")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatToPar(entry.toPar))
                            .font(.title2.bold())
                            .foregroundStyle(toParColor(entry.toPar))
                        Text("Gross \(entry.totalGross)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Full Scorecard Tab

    private var fullScorecardTab: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    Text("Player")
                        .font(.caption.bold())
                        .frame(width: 90, alignment: .leading)
                        .padding(.horizontal, 6)

                    ForEach(vm.round?.holeList ?? []) { hole in
                        VStack(spacing: 1) {
                            Text("\(hole.number)")
                                .font(.caption2.bold())
                            Text("P\(hole.par)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: 34)
                    }

                    Text("TOT")
                        .font(.caption.bold())
                        .frame(width: 40)
                }
                .padding(.vertical, 6)
                .background(Color(.secondarySystemGroupedBackground))

                Divider()

                // Player rows
                ForEach(vm.players) { player in
                    playerRow(player)
                    Divider()
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func playerRow(_ player: Player) -> some View {
        HStack(spacing: 0) {
            Text(player.name)
                .font(.caption.bold())
                .lineLimit(1)
                .frame(width: 90, alignment: .leading)
                .padding(.horizontal, 6)

            ForEach(vm.round?.holeList ?? []) { hole in
                let gross = vm.grossScore(playerID: player.id, hole: hole.number)
                let strokes = player.strokesOnHole(hole)
                scoreCellView(gross: gross, par: hole.par, strokes: strokes)
            }

            let entry = vm.leaderboard.first { $0.id == player.id }
            Text(entry.map { formatToPar($0.toPar) } ?? "-")
                .font(.caption.bold())
                .frame(width: 40)
                .foregroundStyle(entry.map { toParColor($0.toPar) } ?? .primary)
        }
        .padding(.vertical, 8)
    }

    private func scoreCellView(gross: Int?, par: Int, strokes: Int) -> some View {
        ZStack {
            if let gross {
                let net = gross - strokes
                let diff = net - par
                RoundedRectangle(cornerRadius: 4)
                    .fill(scoreBg(diff: diff))
                    .frame(width: 30, height: 26)
                Text("\(gross)")
                    .font(.caption.bold())
                    .foregroundStyle(scoreTextColor(diff: diff))
            } else {
                Text("-")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 26)
            }
        }
        .frame(width: 34)
    }

    private func scoreBg(diff: Int) -> Color {
        switch diff {
        case ...(-2): return .yellow
        case -1:      return .red
        case 0:       return .clear
        case 1:       return Color.blue.opacity(0.15)
        default:      return Color.gray.opacity(0.2)
        }
    }

    private func scoreTextColor(diff: Int) -> Color {
        switch diff {
        case ...(-1): return .white
        default:      return .primary
        }
    }

    // MARK: - Match Results Tab

    private var matchResultsTab: some View {
        List {
            Section("Results") {
                ForEach(Array(vm.matchResults.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key).font(.headline)
                        Spacer()
                        Text(vm.matchResults[key] ?? "").font(.headline).foregroundStyle(.green)
                    }
                }
            }

            if let round = vm.round {
                Section("Format") {
                    Text(round.format.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func formatToPar(_ toPar: Int) -> String {
        if toPar == 0 { return "E" }
        return toPar > 0 ? "+\(toPar)" : "\(toPar)"
    }

    private func toParColor(_ toPar: Int) -> Color {
        if toPar < 0 { return .red }
        if toPar > 0 { return .blue }
        return .primary
    }
}
