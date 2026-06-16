import Foundation
import SwiftUI
import Combine

@MainActor
final class RoundViewModel: ObservableObject {

    // MARK: - Published State

    @Published var round: Round?
    @Published var players: [Player] = []
    @Published var scores: [Score] = []
    @Published var wolfSelections: [WolfSelection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Device identity (persisted so the same person's scores stay linked)

    let deviceID: String = {
        if let saved = UserDefaults.standard.string(forKey: "deviceID") { return saved }
        let new = UUID().uuidString
        UserDefaults.standard.set(new, forKey: "deviceID")
        return new
    }()

    private var pollingTask: Task<Void, Never>?

    // MARK: - Round Lifecycle

    func createRound(name: String, format: GameFormat, holes: Int,
                     courseName: String, courseRating: Double, slopeRating: Int, par: Int,
                     courseHoles: [Hole]?) async {
        isLoading = true
        defer { isLoading = false }
        let newRound = Round(
            id: UUID().uuidString,
            joinCode: Round.generateJoinCode(),
            name: name,
            format: format,
            holes: holes,
            courseName: courseName,
            courseRating: courseRating,
            slopeRating: slopeRating,
            par: par,
            courseHoles: courseHoles,
            createdAt: Date(),
            isFinished: false
        )
        do {
            try await CloudKitService.shared.saveRound(newRound)
            self.round = newRound
        } catch {
            showError("Failed to create round: \(error.localizedDescription)")
        }
    }

    func joinRound(code: String, playerName: String, handicapIndex: Double) async {
        isLoading = true
        defer { isLoading = false }

        let trimmedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showError("Enter your player name before joining.")
            return
        }

        do {
            guard let found = try await CloudKitService.shared.fetchRound(joinCode: code.uppercased()) else {
                showError("Round not found. Check the code and try again.")
                return
            }

            self.round = found
            async let fetchedPlayers = CloudKitService.shared.fetchPlayers(roundID: found.id)
            async let fetchedScores = CloudKitService.shared.fetchScores(roundID: found.id)
            async let fetchedWolfSelections = CloudKitService.shared.fetchWolfSelections(roundID: found.id)
            var currentPlayers = try await fetchedPlayers
            self.scores = try await fetchedScores
            self.wolfSelections = try await fetchedWolfSelections

            if let existingPlayer = currentPlayers.first(where: { $0.deviceID == deviceID }) {
                var updatedPlayer = existingPlayer
                updatedPlayer.name = trimmedName
                updatedPlayer.handicapIndex = handicapIndex
                updatedPlayer.courseHandicap = Player.computeCourseHandicap(
                    index: handicapIndex,
                    slope: found.slopeRating,
                    rating: found.courseRating,
                    par: found.par
                )
                if let index = currentPlayers.firstIndex(where: { $0.id == existingPlayer.id }) {
                    currentPlayers[index] = updatedPlayer
                }
                try await CloudKitService.shared.savePlayers([updatedPlayer])
            } else {
                let courseHandicap = Player.computeCourseHandicap(
                    index: handicapIndex,
                    slope: found.slopeRating,
                    rating: found.courseRating,
                    par: found.par
                )
                let player = Player(
                    id: UUID().uuidString,
                    roundID: found.id,
                    name: trimmedName,
                    handicapIndex: handicapIndex,
                    teamNumber: nil,
                    teeColor: "White",
                    deviceID: deviceID,
                    teeOrder: currentPlayers.count,
                    courseHandicap: courseHandicap
                )
                currentPlayers.append(player)
                try await CloudKitService.shared.savePlayers([player])
            }

            self.players = currentPlayers
            startVegasLiveActivity()
        } catch {
            showError("Failed to join: \(error.localizedDescription)")
        }
    }

    func finishRound() async {
        guard let round else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await CloudKitService.shared.markRoundFinished(round)
            var updatedRound = round
            updatedRound.isFinished = true
            self.round = updatedRound
            endVegasLiveActivity()
        } catch {
            showError("Failed to finish round: \(error.localizedDescription)")
        }
    }

    // MARK: - Players

    func addPlayer(name: String, handicapIndex: Double, teeColor: String, teamNumber: Int?, teeOrder: Int? = nil) {
        guard let round else { return }
        let ch = Player.computeCourseHandicap(
            index: handicapIndex,
            slope: round.slopeRating,
            rating: round.courseRating,
            par: round.par
        )
        var player = Player(
            id: UUID().uuidString,
            roundID: round.id,
            name: name,
            handicapIndex: handicapIndex,
            teamNumber: teamNumber,
            teeColor: teeColor,
            deviceID: deviceID,
            teeOrder: teeOrder ?? players.count,
            courseHandicap: ch
        )
        player.courseHandicap = ch
        players.append(player)
    }

    func savePlayers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await CloudKitService.shared.savePlayers(players)
            startVegasLiveActivity()
        } catch {
            showError("Failed to save players: \(error.localizedDescription)")
        }
    }

    // MARK: - Scores

    func enterScore(playerID: String, holeNumber: Int, grossStrokes: Int) async {
        guard let round else { return }
        let scoreID = "\(round.id)-\(playerID)-\(holeNumber)"
        let score = Score(id: scoreID, roundID: round.id,
                          playerID: playerID, holeNumber: holeNumber, grossStrokes: grossStrokes)

        // Optimistic local update
        if let idx = scores.firstIndex(where: { $0.id == scoreID }) {
            scores[idx] = score
        } else {
            scores.append(score)
        }
        updateVegasLiveActivity()

        do {
            try await CloudKitService.shared.saveScore(score)
        } catch {
            showError("Failed to save score: \(error.localizedDescription)")
        }
    }

    func grossScore(playerID: String, hole: Int) -> Int? {
        scores.first { $0.playerID == playerID && $0.holeNumber == hole }
            .map { $0.grossStrokes > 0 ? $0.grossStrokes : nil } ?? nil
    }

    func netScore(playerID: String, hole: Int) -> Int? {
        guard let gross = grossScore(playerID: playerID, hole: hole),
              let player = players.first(where: { $0.id == playerID }),
              let holeInfo = round?.holeList.first(where: { $0.number == hole }) else { return nil }
        return gross - player.strokesOnHole(holeInfo)
    }

    func wolfPlayer(for holeNumber: Int) -> Player? {
        let orderedPlayers = wolfPlayerOrder
        guard !orderedPlayers.isEmpty else { return nil }
        let index = (holeNumber - 1) % orderedPlayers.count
        return orderedPlayers[index]
    }

    func wolfSelection(for holeNumber: Int) -> WolfSelection? {
        wolfSelections.first { $0.holeNumber == holeNumber }
    }

    func wolfChoiceLabel(for holeNumber: Int) -> String {
        guard let selection = wolfSelection(for: holeNumber) else { return "Choose Wolf play" }
        if selection.isLoneWolf { return "Lone Wolf" }
        if let partnerID = selection.partnerPlayerID,
           let partner = players.first(where: { $0.id == partnerID }) {
            return "Wolf with \(partner.name)"
        }
        return "Choose Wolf play"
    }

    func wolfChoiceIcon(for holeNumber: Int) -> String {
        guard let selection = wolfSelection(for: holeNumber) else { return "pawprint.fill" }
        return selection.isLoneWolf ? "person.fill" : "person.2.fill"
    }

    func saveWolfSelection(holeNumber: Int, partnerPlayerID: String?, isLoneWolf: Bool) async {
        guard let round,
              round.format == .wolf,
              let wolf = wolfPlayer(for: holeNumber) else { return }

        let selection = WolfSelection(
            id: "\(round.id)-wolf-\(holeNumber)",
            roundID: round.id,
            holeNumber: holeNumber,
            wolfPlayerID: wolf.id,
            partnerPlayerID: isLoneWolf ? nil : partnerPlayerID,
            choice: isLoneWolf ? .loneWolf : .partner
        )

        if let index = wolfSelections.firstIndex(where: { $0.id == selection.id }) {
            wolfSelections[index] = selection
        } else {
            wolfSelections.append(selection)
        }
        updateVegasLiveActivity()

        do {
            try await CloudKitService.shared.saveWolfSelection(selection)
        } catch {
            showError("Failed to save Wolf choice: \(error.localizedDescription)")
        }
    }

    // MARK: - Leaderboard

    struct LeaderboardEntry: Identifiable {
        var id: String { player.id }
        let player: Player
        let totalGross: Int
        let totalNet: Int
        let holesPlayed: Int
        let toPar: Int       // net vs par
    }

    var leaderboard: [LeaderboardEntry] {
        guard let round else { return [] }
        let holes = round.holeList
        return players.map { player in
            let playerScores = scores.filter { $0.playerID == player.id && $0.grossStrokes > 0 }
            let totalGross = playerScores.reduce(0) { $0 + $1.grossStrokes }
            let totalNet = playerScores.reduce(0) { sum, s in
                guard let holeInfo = holes.first(where: { $0.number == s.holeNumber }) else { return sum + s.grossStrokes }
                return sum + s.grossStrokes - player.strokesOnHole(holeInfo)
            }
            let playedPar = playerScores.compactMap { s in holes.first(where: { $0.number == s.holeNumber })?.par }.reduce(0, +)
            return LeaderboardEntry(
                player: player,
                totalGross: totalGross,
                totalNet: totalNet,
                holesPlayed: playerScores.count,
                toPar: totalNet - playedPar
            )
        }
        .sorted { a, b in
            if a.holesPlayed == 0 && b.holesPlayed == 0 { return a.player.name < b.player.name }
            if a.holesPlayed == 0 { return false }
            if b.holesPlayed == 0 { return true }
            return a.toPar < b.toPar
        }
    }

    // Match Play / Best Ball / Vegas / Sixes results
    var matchResults: [String: String] {
        guard let round else { return [:] }
        switch round.format {
        case .matchPlay:   return computeMatchPlay()
        case .bestBall:    return computeBestBall()
        case .vegas:       return computeVegas()
        case .sixes:       return computeSixes()
        case .wolf:        return computeWolf()
        default:           return [:]
        }
    }

    // MARK: - Polling

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                await refreshPlayersAndScores()
                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    func returnHomeForNewRound() {
        endVegasLiveActivity()
        stopPolling()
        round = nil
        players = []
        scores = []
        wolfSelections = []
        errorMessage = nil
        showError = false
        isLoading = false
    }

    func refreshPlayersAndScores() async {
        guard let round else { return }
        do {
            async let fetchedPlayers = CloudKitService.shared.fetchPlayers(roundID: round.id)
            async let fetchedScores  = CloudKitService.shared.fetchScores(roundID: round.id)
            async let fetchedWolfSelections = CloudKitService.shared.fetchWolfSelections(roundID: round.id)
            let (p, s, w) = try await (fetchedPlayers, fetchedScores, fetchedWolfSelections)
            self.players = p
            self.scores  = s
            self.wolfSelections = w
            startVegasLiveActivity()
        } catch {
            // Silently swallow polling errors to avoid spamming the user
        }
    }

    // MARK: - Private helpers

    private func showError(_ msg: String) {
        errorMessage = msg
        showError = true
    }

    // MARK: - Game format calculators

    private func computeMatchPlay() -> [String: String] {
        guard players.count >= 2, let round else { return [:] }
        let holes = round.holeList
        let p1 = players[0], p2 = players[1]
        var p1Wins = 0, p2Wins = 0, halved = 0

        for hole in holes {
            guard let n1 = netScore(playerID: p1.id, hole: hole.number),
                  let n2 = netScore(playerID: p2.id, hole: hole.number) else { continue }
            if n1 < n2 { p1Wins += 1 }
            else if n2 < n1 { p2Wins += 1 }
            else { halved += 1 }
        }

        let diff = p1Wins - p2Wins
        if diff > 0 { return [p1.name: "\(diff) UP", p2.name: "\(diff) DN"] }
        if diff < 0 { return [p2.name: "\(abs(diff)) UP", p1.name: "\(abs(diff)) DN"] }
        return [p1.name: "AS", p2.name: "AS"]
    }

    private func computeBestBall() -> [String: String] {
        guard let round else { return [:] }
        let holes = round.holeList
        let teams = activeTeamNumbers()
        guard teams.count >= 2 else { return [:] }
        let firstTeamNumber = teams[0]
        let secondTeamNumber = teams[1]
        let firstTeam = players.filter { $0.teamNumber == firstTeamNumber }
        let secondTeam = players.filter { $0.teamNumber == secondTeamNumber }
        var firstWins = 0, secondWins = 0

        for hole in holes {
            let firstBest = firstTeam.compactMap { netScore(playerID: $0.id, hole: hole.number) }.min()
            let secondBest = secondTeam.compactMap { netScore(playerID: $0.id, hole: hole.number) }.min()
            guard let b1 = firstBest, let b2 = secondBest else { continue }
            if b1 < b2 { firstWins += 1 } else if b2 < b1 { secondWins += 1 }
        }

        let diff = firstWins - secondWins
        if diff > 0 {
            return [
                teamColorName(firstTeamNumber): "\(diff) UP",
                teamColorName(secondTeamNumber): "\(diff) DN"
            ]
        }
        if diff < 0 {
            return [
                teamColorName(firstTeamNumber): "\(abs(diff)) DN",
                teamColorName(secondTeamNumber): "\(abs(diff)) UP"
            ]
        }
        return [
            teamColorName(firstTeamNumber): "AS",
            teamColorName(secondTeamNumber): "AS"
        ]
    }

    private func vegasTeamTotals() -> (team1Number: Int, team2Number: Int, team1Diff: Int, team2Diff: Int, team1Raw: Int, team2Raw: Int) {
        guard let round else { return (1, 2, 0, 0, 0, 0) }
        let teams = activeTeamNumbers()
        let firstTeamNumber = teams.first ?? 1
        let secondTeamNumber = teams.dropFirst().first ?? 2
        let holes = round.holeList
        let team1 = players.filter { $0.teamNumber == firstTeamNumber }.sorted { $0.name < $1.name }
        let team2 = players.filter { $0.teamNumber == secondTeamNumber }.sorted { $0.name < $1.name }
        var t1Diff = 0, t2Diff = 0, t1Raw = 0, t2Raw = 0
        for hole in holes {
            let t1Scores = team1.compactMap { grossScore(playerID: $0.id, hole: hole.number) }.sorted()
            let t2Scores = team2.compactMap { grossScore(playerID: $0.id, hole: hole.number) }.sorted()
            guard t1Scores.count == 2, t2Scores.count == 2 else { continue }
            let t1Val = t1Scores[0] * 10 + t1Scores[1]
            let t2Val = t2Scores[0] * 10 + t2Scores[1]
            t1Raw += t1Val
            t2Raw += t2Val
            if t1Val < t2Val { t1Diff += (t2Val - t1Val) }
            else if t2Val < t1Val { t2Diff += (t1Val - t2Val) }
        }
        return (firstTeamNumber, secondTeamNumber, t1Diff, t2Diff, t1Raw, t2Raw)
    }

    private func computeVegas() -> [String: String] {
        let t = vegasTeamTotals()
        let firstTeamName = teamColorName(t.team1Number)
        let secondTeamName = teamColorName(t.team2Number)
        let net = t.team1Diff - t.team2Diff
        let standing: String
        if net > 0      { standing = "\(firstTeamName) +\(net)" }
        else if net < 0 { standing = "\(secondTeamName) +\(abs(net))" }
        else            { standing = "Even" }
        return [
            "Standing": standing,
            "\(firstTeamName) Total": t.team1Raw > 0 ? "\(t.team1Raw)" : "-",
            "\(secondTeamName) Total": t.team2Raw > 0 ? "\(t.team2Raw)" : "-"
        ]
    }

    private func computeSixes() -> [String: String] {
        // Sixes: 3 matches of 6 holes. Partners rotate each 6 holes.
        // With 4 players A,B,C,D: Match1 (1-6): A&B vs C&D, Match2 (7-12): A&C vs B&D, Match3 (13-18): A&D vs B&C
        guard players.count == 4, let round else { return [:] }
        let p = players
        let matches: [(partner1: [Player], partner2: [Player], holes: ClosedRange<Int>)] = [
            ([p[0], p[1]], [p[2], p[3]], 1...6),
            ([p[0], p[2]], [p[1], p[3]], 7...12),
            ([p[0], p[3]], [p[1], p[2]], 13...18)
        ]
        var points = [String: Int]()
        players.forEach { points[$0.name] = 0 }

        for match in matches {
            var t1Wins = 0, t2Wins = 0
            let holes = round.holeList.filter { match.holes.contains($0.number) }
            for hole in holes {
                let t1Best = match.partner1.compactMap { netScore(playerID: $0.id, hole: hole.number) }.min()
                let t2Best = match.partner2.compactMap { netScore(playerID: $0.id, hole: hole.number) }.min()
                guard let b1 = t1Best, let b2 = t2Best else { continue }
                if b1 < b2 { t1Wins += 1 } else if b2 < b1 { t2Wins += 1 }
            }
            let pts1 = t1Wins > t2Wins ? 2 : (t1Wins == t2Wins ? 1 : 0)
            let pts2 = 2 - pts1
            match.partner1.forEach { points[$0.name, default: 0] += pts1 }
            match.partner2.forEach { points[$0.name, default: 0] += pts2 }
        }

        return points.mapValues { "\($0) pts" }
    }

    private func computeWolf() -> [String: String] {
        guard let round, players.count >= 3 else { return [:] }
        var points = Dictionary(uniqueKeysWithValues: players.map { ($0.id, 0) })

        for hole in round.holeList {
            guard let selection = wolfSelection(for: hole.number),
                  let wolf = players.first(where: { $0.id == selection.wolfPlayerID }) else { continue }

            let wolfSide = wolfSidePlayerIDs(for: selection)
            let opposingSide = players.map(\.id).filter { !wolfSide.contains($0) }
            guard let wolfBest = bestNetScore(playerIDs: wolfSide, holeNumber: hole.number),
                  let opposingBest = bestNetScore(playerIDs: opposingSide, holeNumber: hole.number),
                  wolfBest != opposingBest else { continue }

            if wolfBest < opposingBest {
                if selection.isLoneWolf {
                    points[wolf.id, default: 0] += 2
                } else {
                    wolfSide.forEach { points[$0, default: 0] += 1 }
                }
            } else if selection.isLoneWolf {
                opposingSide.forEach { points[$0, default: 0] += 1 }
            } else {
                opposingSide.forEach { points[$0, default: 0] += 1 }
            }
        }

        return players
            .sorted { lhs, rhs in
                let lhsPoints = points[lhs.id, default: 0]
                let rhsPoints = points[rhs.id, default: 0]
                if lhsPoints == rhsPoints { return lhs.name < rhs.name }
                return lhsPoints > rhsPoints
            }
            .reduce(into: [String: String]()) { result, player in
                result[player.name] = "\(points[player.id, default: 0]) pts"
            }
    }

    private var wolfPlayerOrder: [Player] {
        players.sorted { lhs, rhs in
            if lhs.teeOrder == rhs.teeOrder {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.teeOrder < rhs.teeOrder
        }
    }

    private func wolfSidePlayerIDs(for selection: WolfSelection) -> [String] {
        if selection.isLoneWolf { return [selection.wolfPlayerID] }
        if let partnerPlayerID = selection.partnerPlayerID {
            return [selection.wolfPlayerID, partnerPlayerID]
        }
        return [selection.wolfPlayerID]
    }

    private func bestNetScore(playerIDs: [String], holeNumber: Int) -> Int? {
        playerIDs.compactMap { netScore(playerID: $0, hole: holeNumber) }.min()
    }

    // MARK: - Live Activity

    private func roundActivityState() -> RoundLiveActivityAttributes.ContentState? {
        guard #available(iOS 16.1, *), let round, !players.isEmpty else { return nil }
        let latestHole = scores.filter { $0.grossStrokes > 0 }.map { $0.holeNumber }.max() ?? 1
        let completed = round.holeList.filter { hole in
            players.allSatisfy { grossScore(playerID: $0.id, hole: hole.number) != nil }
        }.count

        let summary = liveActivitySummary(for: round.format)
        return RoundLiveActivityAttributes.ContentState(
            leadingLabel: summary.leading.label,
            leadingValue: summary.leading.value,
            trailingLabel: summary.trailing.label,
            trailingValue: summary.trailing.value,
            leadingIsWinning: summary.leading.isWinning,
            trailingIsWinning: summary.trailing.isWinning,
            leadingColorName: summary.leading.colorName,
            trailingColorName: summary.trailing.colorName,
            rows: summary.rows,
            currentHole: latestHole,
            holesCompleted: completed
        )
    }

    private func roundActivityAttributes() -> RoundLiveActivityAttributes? {
        guard #available(iOS 16.1, *), let round, !players.isEmpty else { return nil }
        return RoundLiveActivityAttributes(
            roundName: round.name,
            formatName: round.format.rawValue,
            totalHoles: round.holeList.count
        )
    }

    private typealias ActivityScore = (label: String, value: String, isWinning: Bool, colorName: String?)
    private typealias ActivitySummary = (leading: ActivityScore, trailing: ActivityScore, rows: [RoundLiveActivityAttributes.ScoreRow])

    private func liveActivitySummary(for format: GameFormat) -> ActivitySummary {
        switch format {
        case .strokePlay:
            return strokePlayActivitySummary()
        case .matchPlay:
            return matchPlayActivitySummary()
        case .bestBall:
            return bestBallActivitySummary()
        case .vegas:
            return vegasActivitySummary()
        case .sixes:
            return sixesActivitySummary()
        case .wolf:
            return wolfActivitySummary()
        }
    }

    private func strokePlayActivitySummary() -> ActivitySummary {
        let entries = leaderboard
        let first = entries.first
        let second = entries.dropFirst().first
        let firstIsWinning = first?.holesPlayed ?? 0 > 0
        let secondIsWinning = firstIsWinning && second != nil && first?.toPar == second?.toPar

        let rows = first.map { entry in
            [
                scoreRow(id: "gross", label: "Gross", value: "\(entry.totalGross)", isHighlighted: false),
                scoreRow(id: "net", label: "Net", value: "\(entry.totalNet)", isHighlighted: true),
                scoreRow(id: "holes", label: "Holes", value: "\(entry.holesPlayed)", isHighlighted: false)
            ]
        } ?? []

        return (
            leading: (first?.player.name ?? "Leader", first.map { formatToPar($0.toPar) } ?? "-", firstIsWinning, nil),
            trailing: (second?.player.name ?? "Next", second.map { formatToPar($0.toPar) } ?? "-", secondIsWinning, nil),
            rows: rows
        )
    }

    private func matchPlayActivitySummary() -> ActivitySummary {
        guard players.count >= 2 else { return placeholderActivitySummary() }
        let results = computeMatchPlay()
        let p1 = players[0]
        let p2 = players[1]
        let p1Value = results[p1.name] ?? "AS"
        let p2Value = results[p2.name] ?? "AS"

        return (
            leading: (p1.name, p1Value, p1Value.contains("UP"), nil),
            trailing: (p2.name, p2Value, p2Value.contains("UP"), nil),
            rows: resultRows(from: results, highlightedValuesContaining: "UP")
        )
    }

    private func bestBallActivitySummary() -> ActivitySummary {
        let results = computeBestBall()
        let teams = activeTeamNumbers()
        let firstTeamNumber = teams.first ?? 1
        let secondTeamNumber = teams.dropFirst().first ?? 2
        let firstTeamName = teamColorName(firstTeamNumber)
        let secondTeamName = teamColorName(secondTeamNumber)
        let firstValue = results[firstTeamName] ?? "AS"
        let secondValue = results[secondTeamName] ?? "AS"

        return (
            leading: (teamLabel(firstTeamNumber), firstValue, firstValue.contains("UP"), firstTeamName),
            trailing: (teamLabel(secondTeamNumber), secondValue, secondValue.contains("UP"), secondTeamName),
            rows: resultRows(from: results, highlightedValuesContaining: "UP")
        )
    }

    private func vegasActivitySummary() -> ActivitySummary {
        let totals = vegasTeamTotals()
        let results = computeVegas()
        let firstTeamName = teamColorName(totals.team1Number)
        let secondTeamName = teamColorName(totals.team2Number)
        let firstValue = "+\(totals.team1Diff)"
        let secondValue = "+\(totals.team2Diff)"

        return (
            leading: (teamLabel(totals.team1Number), firstValue, totals.team1Diff > totals.team2Diff, firstTeamName),
            trailing: (teamLabel(totals.team2Number), secondValue, totals.team2Diff > totals.team1Diff, secondTeamName),
            rows: [
                scoreRow(id: "standing", label: "Standing", value: results["Standing"] ?? "Even", isHighlighted: true),
                scoreRow(id: "team1Total", label: "\(firstTeamName) Total", value: results["\(firstTeamName) Total"] ?? "-", isHighlighted: false),
                scoreRow(id: "team2Total", label: "\(secondTeamName) Total", value: results["\(secondTeamName) Total"] ?? "-", isHighlighted: false)
            ]
        )
    }

    private func sixesActivitySummary() -> ActivitySummary {
        let ranked = computeSixes()
            .map { (name: $0.key, points: leadingInteger(in: $0.value), value: $0.value) }
            .sorted { lhs, rhs in
                if lhs.points == rhs.points { return lhs.name < rhs.name }
                return lhs.points > rhs.points
            }
        let first = ranked.first
        let second = ranked.dropFirst().first
        let isTie = first != nil && second != nil && first?.points == second?.points

        return (
            leading: (first?.name ?? "Leader", first?.value ?? "0 pts", first != nil && !isTie, nil),
            trailing: (second?.name ?? "Next", second?.value ?? "0 pts", second != nil && !isTie && second?.points == first?.points, nil),
            rows: ranked.prefix(3).map { scoreRow(id: $0.name, label: $0.name, value: $0.value, isHighlighted: $0.points == first?.points) }
        )
    }

    private func wolfActivitySummary() -> ActivitySummary {
        let ranked = computeWolf()
            .map { (name: $0.key, points: leadingInteger(in: $0.value), value: $0.value) }
            .sorted { lhs, rhs in
                if lhs.points == rhs.points { return lhs.name < rhs.name }
                return lhs.points > rhs.points
            }
        let first = ranked.first
        let second = ranked.dropFirst().first
        let isTie = first != nil && second != nil && first?.points == second?.points

        return (
            leading: (first?.name ?? "Leader", first?.value ?? "0 pts", first != nil && !isTie, nil),
            trailing: (second?.name ?? "Next", second?.value ?? "0 pts", second != nil && !isTie && second?.points == first?.points, nil),
            rows: ranked.prefix(3).map { scoreRow(id: $0.name, label: $0.name, value: $0.value, isHighlighted: $0.points == first?.points) }
        )
    }

    private func placeholderActivitySummary() -> ActivitySummary {
        (
            leading: ("Leader", "-", false, nil),
            trailing: ("Next", "-", false, nil),
            rows: []
        )
    }

    private func resultRows(from results: [String: String], highlightedValuesContaining marker: String) -> [RoundLiveActivityAttributes.ScoreRow] {
        results.keys.sorted().prefix(3).map { key in
            let value = results[key] ?? "-"
            let isHighlighted = !marker.isEmpty && value.contains(marker)
            return scoreRow(id: key, label: key, value: value, isHighlighted: isHighlighted)
        }
    }

    private func scoreRow(id: String, label: String, value: String, isHighlighted: Bool) -> RoundLiveActivityAttributes.ScoreRow {
        RoundLiveActivityAttributes.ScoreRow(id: id, label: label, value: value, isHighlighted: isHighlighted)
    }

    private func teamLabel(_ teamNumber: Int) -> String {
        let names = players
            .filter { $0.teamNumber == teamNumber }
            .map { $0.name }
            .joined(separator: " & ")
        return names.isEmpty ? teamColorName(teamNumber) : names
    }

    private func activeTeamNumbers() -> [Int] {
        let assigned = Set(players.compactMap(\.teamNumber)).sorted()
        if assigned.count >= 2 { return Array(assigned.prefix(2)) }
        return [1, 2]
    }

    private func teamColorName(_ teamNumber: Int) -> String {
        switch teamNumber {
        case 1: return "Red"
        case 2: return "Blue"
        case 3: return "Green"
        case 4: return "Yellow"
        case 5: return "Purple"
        default: return "Team \(teamNumber)"
        }
    }

    private func leadingInteger(in value: String) -> Int {
        let digits = value.prefix { $0.isNumber }
        return Int(digits) ?? 0
    }

    private func formatToPar(_ toPar: Int) -> String {
        if toPar == 0 { return "E" }
        return toPar > 0 ? "+\(toPar)" : "\(toPar)"
    }

    func startVegasLiveActivity() {
        guard #available(iOS 16.1, *),
              let attrs = roundActivityAttributes(),
              let state = roundActivityState() else { return }
        VegasLiveActivityManager.shared.start(attributes: attrs, initialState: state)
    }

    func updateVegasLiveActivity() {
        guard #available(iOS 16.1, *),
              let state = roundActivityState() else { return }
        Task { await VegasLiveActivityManager.shared.update(state: state) }
    }

    func endVegasLiveActivity() {
        guard #available(iOS 16.1, *) else { return }
        let finalState = roundActivityState() ?? RoundLiveActivityAttributes.ContentState(
            leadingLabel: "Leader",
            leadingValue: "-",
            trailingLabel: "Next",
            trailingValue: "-",
            leadingIsWinning: false,
            trailingIsWinning: false,
            leadingColorName: nil,
            trailingColorName: nil,
            rows: [],
            currentHole: 1,
            holesCompleted: 0
        )
        Task { await VegasLiveActivityManager.shared.end(finalState: finalState) }
    }
}
