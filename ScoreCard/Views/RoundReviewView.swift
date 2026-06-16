import SwiftUI
import UIKit

struct RoundReviewView: View {
    @EnvironmentObject var vm: RoundViewModel
    @Environment(\.dismiss) var dismiss
    @State private var shareImageURL: URL?

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

                    shareResultsSection(round: round)

                    Section {
                        Button {
                            dismiss()
                            vm.returnHomeForNewRound()
                        } label: {
                            Label("Start Next Round", systemImage: "house.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
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

    private func shareResultsSection(round: Round) -> some View {
        Section("Share") {
            if let shareImageURL {
                ShareLink(item: shareImageURL) {
                    Label("Share Results Image", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }

            Button {
                shareImageURL = createShareImageURL(round: round)
            } label: {
                Label(shareImageURL == nil ? "Create Summary Image" : "Update Summary Image", systemImage: "photo")
                    .frame(maxWidth: .infinity)
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

    private func createShareImageURL(round: Round) -> URL? {
        let card = RoundSummaryShareCard(
            round: round,
            leaderboard: vm.leaderboard,
            matchResults: vm.matchResults,
            generatedAt: Date()
        )
        .frame(width: 1080)

        let renderer = ImageRenderer(content: card)
        renderer.scale = 2

        guard let image = renderer.uiImage,
              let pngData = image.pngData() else { return nil }

        let fileName = "ScoreCard-\(round.joinCode)-Results.png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
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
        case .wolf:
            return "Wolf Result"
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

private struct RoundSummaryShareCard: View {
    let round: Round
    let leaderboard: [RoundViewModel.LeaderboardEntry]
    let matchResults: [String: String]
    let generatedAt: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            if round.format != .strokePlay && !matchResults.isEmpty {
                resultsBlock
            }

            leaderboardBlock
            footer
        }
        .padding(44)
        .background(
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.09), Color(red: 0.08, green: 0.12, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(round.name)
                        .font(.system(size: 54, weight: .black))
                        .lineLimit(2)
                    Text(round.courseName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("ScoreCard")
                        .font(.system(size: 30, weight: .bold))
                    Text(round.format.rawValue)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }

            Text("\(round.holes) holes  |  Code \(round.joinCode)")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var resultsBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Game Result")
                .font(.system(size: 28, weight: .bold))

            ForEach(matchResults.keys.sorted(), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.system(size: 26, weight: .semibold))
                    Spacer()
                    Text(matchResults[key] ?? "")
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var leaderboardBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Final Leaderboard")
                .font(.system(size: 28, weight: .bold))

            ForEach(Array(leaderboard.enumerated()), id: \.element.id) { index, entry in
                HStack(spacing: 18) {
                    Text("\(index + 1)")
                        .font(.system(size: 30, weight: .black))
                        .frame(width: 46)
                        .foregroundStyle(.white.opacity(0.55))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(entry.player.name)
                            .font(.system(size: 30, weight: .bold))
                        Text("Gross \(entry.totalGross)  Net \(entry.totalNet)  \(entry.holesPlayed) holes")
                            .font(.system(size: 21, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer()

                    Text(formatToPar(entry.toPar))
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(toParColor(entry.toPar))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 18)
                .background(.white.opacity(index == 0 ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var footer: some View {
        HStack {
            Text(generatedAt.formatted(date: .abbreviated, time: .shortened))
            Spacer()
            Text("Shared from ScoreCard")
        }
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(.white.opacity(0.45))
    }

    private func formatToPar(_ toPar: Int) -> String {
        if toPar == 0 { return "E" }
        return toPar > 0 ? "+\(toPar)" : "\(toPar)"
    }

    private func toParColor(_ toPar: Int) -> Color {
        if toPar < 0 { return .red }
        if toPar > 0 { return .blue }
        return .white
    }
}
