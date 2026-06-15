import Foundation
import SwiftUI
import Combine

@MainActor
final class RoundViewModel: ObservableObject {

    // MARK: - Published State

    @Published var round: Round?
    @Published var players: [Player] = []
    @Published var scores: [Score] = []
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

    func joinRound(code: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let found = try await CloudKitService.shared.fetchRound(joinCode: code.uppercased()) else {
                showError("Round not found. Check the code and try again.")
                return
            }
            self.round = found
            await refreshPlayersAndScores()
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
        } catch {
            showError("Failed to finish round: \(error.localizedDescription)")
        }
    }

    // MARK: - Players

    func addPlayer(name: String, handicapIndex: Double, teeColor: String, teamNumber: Int?) {
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

    func refreshPlayersAndScores() async {
        guard let round else { return }
        do {
            async let fetchedPlayers = CloudKitService.shared.fetchPlayers(roundID: round.id)
            async let fetchedScores  = CloudKitService.shared.fetchScores(roundID: round.id)
            let (p, s) = try await (fetchedPlayers, fetchedScores)
            self.players = p
            self.scores  = s
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
        let team1 = players.filter { $0.teamNumber == 1 }
        let team2 = players.filter { $0.teamNumber == 2 }
        var t1Wins = 0, t2Wins = 0

        for hole in holes {
            let t1Best = team1.compactMap { netScore(playerID: $0.id, hole: hole.number) }.min()
            let t2Best = team2.compactMap { netScore(playerID: $0.id, hole: hole.number) }.min()
            guard let b1 = t1Best, let b2 = t2Best else { continue }
            if b1 < b2 { t1Wins += 1 } else if b2 < b1 { t2Wins += 1 }
        }

        return ["Team 1": "\(t1Wins) holes", "Team 2": "\(t2Wins) holes"]
    }

    private func computeVegas() -> [String: String] {
        guard let round else { return [:] }
        let holes = round.holeList
        let team1 = players.filter { $0.teamNumber == 1 }.sorted { $0.name < $1.name }
        let team2 = players.filter { $0.teamNumber == 2 }.sorted { $0.name < $1.name }
        var t1Total = 0, t2Total = 0

        for hole in holes {
            let t1Scores = team1.compactMap { grossScore(playerID: $0.id, hole: hole.number) }.sorted()
            let t2Scores = team2.compactMap { grossScore(playerID: $0.id, hole: hole.number) }.sorted()
            guard t1Scores.count == 2, t2Scores.count == 2 else { continue }
            // Vegas: lower score is tens digit, higher is ones digit
            let t1Val = t1Scores[0] * 10 + t1Scores[1]
            let t2Val = t2Scores[0] * 10 + t2Scores[1]
            if t1Val < t2Val { t1Total += (t2Val - t1Val) }
            else if t2Val < t1Val { t2Total += (t1Val - t2Val) }
        }

        return ["Team 1": "+\(t1Total)", "Team 2": "+\(t2Total)"]
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
}
