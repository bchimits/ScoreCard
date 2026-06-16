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

                if vm.round?.format == .vegas {
                    ForEach(vegasTeamNumbers, id: \.self) { teamNumber in
                        vegasTeamRow(teamNumber: teamNumber)
                        Divider()
                    }
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

    private func vegasTeamRow(teamNumber: Int) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle()
                    .fill(teamColor(for: teamNumber))
                    .frame(width: 7, height: 7)
                Text(teamName(for: teamNumber))
                    .lineLimit(1)
            }
            .font(.caption.bold())
            .frame(width: 90, alignment: .leading)
            .padding(.horizontal, 6)

            ForEach(vm.round?.holeList ?? []) { hole in
                Text(vegasScoreText(teamNumber: teamNumber, holeNumber: hole.number))
                    .font(.caption.bold())
                    .foregroundStyle(vegasScoreColor(teamNumber: teamNumber, holeNumber: hole.number))
                    .frame(width: 34)
            }

            Text(vegasTeamTotalText(teamNumber: teamNumber))
                .font(.caption.bold())
                .foregroundStyle(vegasTeamTotalColor(teamNumber: teamNumber))
                .frame(width: 40)
        }
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.08))
    }

    private func vegasScoreText(teamNumber: Int, holeNumber: Int) -> String {
        guard let score = vegasScoreValue(teamNumber: teamNumber, holeNumber: holeNumber) else { return "-" }
        return "\(score)"
    }

    private func vegasScoreColor(teamNumber: Int, holeNumber: Int) -> Color {
        guard let teamScore = vegasScoreValue(teamNumber: teamNumber, holeNumber: holeNumber),
              let opposingScore = vegasScoreValue(teamNumber: opposingTeamNumber(for: teamNumber), holeNumber: holeNumber) else {
            return .primary
        }

        if teamScore == opposingScore { return .primary }
        return teamScore < opposingScore ? .green : .red
    }

    private func vegasScoreValue(teamNumber: Int, holeNumber: Int) -> Int? {
        let scores = vegasPlayers(teamNumber: teamNumber)
            .compactMap { vm.grossScore(playerID: $0.id, hole: holeNumber) }
            .sorted()

        guard scores.count == 2 else { return nil }
        return scores[0] * 10 + scores[1]
    }

    private func vegasTeamTotalText(teamNumber: Int) -> String {
        guard let total = vegasTeamTotalValue(teamNumber: teamNumber) else { return "-" }
        return "\(total)"
    }

    private func vegasTeamTotalColor(teamNumber: Int) -> Color {
        guard let teamTotal = vegasTeamTotalValue(teamNumber: teamNumber),
              let opposingTotal = vegasTeamTotalValue(teamNumber: opposingTeamNumber(for: teamNumber)) else {
            return .primary
        }

        if teamTotal == opposingTotal { return .primary }
        return teamTotal < opposingTotal ? .green : .red
    }

    private func vegasTeamTotalValue(teamNumber: Int) -> Int? {
        guard let holes = vm.round?.holeList else { return nil }
        let values = holes.compactMap { vegasScoreValue(teamNumber: teamNumber, holeNumber: $0.number) }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private var vegasTeamNumbers: [Int] {
        let assigned = Set(vm.players.compactMap(\.teamNumber)).sorted()
        if assigned.count >= 2 { return Array(assigned.prefix(2)) }
        return [1, 2]
    }

    private func opposingTeamNumber(for teamNumber: Int) -> Int {
        vegasTeamNumbers.first { $0 != teamNumber } ?? (teamNumber == 1 ? 2 : 1)
    }

    private func vegasPlayers(teamNumber: Int) -> [Player] {
        let assignedPlayers = vm.players.filter { $0.teamNumber == teamNumber }
        if assignedPlayers.count == 2 {
            return assignedPlayers
        }

        guard let teamIndex = vegasTeamNumbers.firstIndex(of: teamNumber) else { return assignedPlayers }
        let startIndex = teamIndex * 2
        guard vm.players.count >= startIndex + 2 else { return assignedPlayers }
        return Array(vm.players[startIndex..<(startIndex + 2)])
    }

    private func teamName(for teamNumber: Int) -> String {
        switch teamNumber {
        case 1: return "Red"
        case 2: return "Blue"
        case 3: return "Green"
        case 4: return "Yellow"
        case 5: return "Purple"
        default: return "Team \(teamNumber)"
        }
    }

    private func teamColor(for teamNumber: Int) -> Color {
        switch teamNumber {
        case 1: return .red
        case 2: return .blue
        case 3: return .green
        case 4: return .yellow
        case 5: return .purple
        default: return .secondary
        }
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
