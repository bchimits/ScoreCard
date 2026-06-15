import SwiftUI

struct RoundReviewView: View {
    @EnvironmentObject var vm: RoundViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let round = vm.round {
                    Section("Round") {
                        LabeledContent("Course", value: round.courseName)
                        LabeledContent("Format", value: round.format.rawValue)
                        LabeledContent("Holes", value: "\(round.holes)")
                        LabeledContent("Rating / Slope", value: String(format: "%.1f / %d", round.courseRating, round.slopeRating))
                    }

                    if round.format != .strokePlay {
                        gameResultsSection(round: round)
                    }

                    finalLeaderboardSection
                    scorecardSummarySection
                }
            }
            .navigationTitle("Round Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func gameResultsSection(round: Round) -> some View {
        Section(resultSectionTitle(for: round.format)) {
            if vm.matchResults.isEmpty {
                Text("No result available yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(vm.matchResults.keys.sorted()), id: \.self) { key in
                    HStack {
                        Text(key)
                            .font(.headline)
                        Spacer()
                        Text(vm.matchResults[key] ?? "")
                            .font(.headline)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
    }

    private var finalLeaderboardSection: some View {
        Section("Final Leaderboard") {
            ForEach(Array(vm.leaderboard.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.player.name)
                            .font(.headline)
                        Text("Gross \(entry.totalGross)  Net \(entry.totalNet)  \(entry.holesPlayed) holes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(formatToPar(entry.toPar))
                        .font(.title3.bold())
                        .foregroundStyle(toParColor(entry.toPar))
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var scorecardSummarySection: some View {
        Section("Scorecard") {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    scorecardHeader
                    Divider()
                    ForEach(vm.players) { player in
                        scorecardRow(player)
                        Divider()
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var scorecardHeader: some View {
        HStack(spacing: 0) {
            Text("Player")
                .font(.caption.bold())
                .frame(width: 86, alignment: .leading)
                .padding(.horizontal, 4)

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

            Text("NET")
                .font(.caption.bold())
                .frame(width: 42)
        }
    }

    private func scorecardRow(_ player: Player) -> some View {
        HStack(spacing: 0) {
            Text(player.name)
                .font(.caption.bold())
                .lineLimit(1)
                .frame(width: 86, alignment: .leading)
                .padding(.horizontal, 4)

            ForEach(vm.round?.holeList ?? []) { hole in
                Text(vm.grossScore(playerID: player.id, hole: hole.number).map(String.init) ?? "-")
                    .font(.caption)
                    .frame(width: 34)
            }

            let entry = vm.leaderboard.first { $0.id == player.id }
            Text(entry.map { "\($0.totalNet)" } ?? "-")
                .font(.caption.bold())
                .frame(width: 42)
        }
        .padding(.vertical, 6)
    }

    private func resultSectionTitle(for format: GameFormat) -> String {
        switch format {
        case .matchPlay:
            return "Match Result"
        case .bestBall:
            return "Best Ball Result"
        case .vegas:
            return "Vegas Result"
        case .sixes:
            return "Sixes Result"
        case .strokePlay:
            return "Result"
        }
    }

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
