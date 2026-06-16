import Foundation

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()

    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    var isConfigured: Bool { SupabaseConfig.isConfigured }

    func saveRound(_ round: Round) async throws {
        try await upsert(table: "rounds", conflictColumn: "id", body: [RoundRecord(round)])
    }

    func fetchRound(joinCode: String) async throws -> Round? {
        let records: [RoundRecord] = try await fetch(
            table: "rounds",
            queryItems: [
                URLQueryItem(name: "join_code", value: "eq.\(joinCode)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        return records.first?.round
    }

    func fetchRound(id: String) async throws -> Round? {
        let records: [RoundRecord] = try await fetch(
            table: "rounds",
            queryItems: [
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        return records.first?.round
    }

    func markRoundFinished(_ round: Round) async throws {
        try await patch(table: "rounds", filter: URLQueryItem(name: "id", value: "eq.\(round.id)"), body: ["is_finished": true])
    }

    func savePlayers(_ players: [Player]) async throws {
        guard !players.isEmpty else { return }
        try await upsert(table: "players", conflictColumn: "id", body: players.map(PlayerRecord.init))
    }

    func fetchPlayers(roundID: String) async throws -> [Player] {
        let records: [PlayerRecord] = try await fetch(
            table: "players",
            queryItems: [URLQueryItem(name: "round_id", value: "eq.\(roundID)")]
        )
        return records.map(\.player)
    }

    func saveScore(_ score: Score) async throws {
        try await upsert(table: "scores", conflictColumn: "id", body: [ScoreRecord(score)])
    }

    func fetchScores(roundID: String) async throws -> [Score] {
        let records: [ScoreRecord] = try await fetch(
            table: "scores",
            queryItems: [URLQueryItem(name: "round_id", value: "eq.\(roundID)")]
        )
        return records.map(\.score)
    }

    private func fetch<T: Decodable>(table: String, queryItems: [URLQueryItem]) async throws -> T {
        var request = try request(path: table, queryItems: queryItems)
        request.httpMethod = "GET"
        let data = try await perform(request)
        return try decoder.decode(T.self, from: data)
    }

    private func upsert<T: Encodable>(table: String, conflictColumn: String, body: T) async throws {
        var request = try request(
            path: table,
            queryItems: [URLQueryItem(name: "on_conflict", value: conflictColumn)]
        )
        request.httpMethod = "POST"
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        _ = try await perform(request)
    }

    private func patch<T: Encodable>(table: String, filter: URLQueryItem, body: T) async throws {
        var request = try request(path: table, queryItems: [filter])
        request.httpMethod = "PATCH"
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try encoder.encode(body)
        _ = try await perform(request)
    }

    private func request(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard let baseURL = URL(string: SupabaseConfig.projectURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SupabaseError.invalidConfiguration
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("rest/v1/\(path)"), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw SupabaseError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "No response body"
            throw SupabaseError.requestFailed(statusCode: httpResponse.statusCode, message: message)
        }
        return data.isEmpty ? Data("[]".utf8) : data
    }
}

private enum SupabaseError: LocalizedError {
    case invalidConfiguration
    case invalidURL
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Supabase is not configured. Add your project URL and anon key in SupabaseConfig.swift."
        case .invalidURL:
            return "Invalid Supabase request URL."
        case .invalidResponse:
            return "Supabase returned an invalid response."
        case .requestFailed(let statusCode, let message):
            return "Supabase request failed (\(statusCode)): \(message)"
        }
    }
}

private struct RoundRecord: Codable {
    let id: String
    let joinCode: String
    let name: String
    let format: String
    let holes: Int
    let courseName: String
    let courseRating: Double
    let slopeRating: Int
    let par: Int
    let courseHoles: [Hole]?
    let createdAt: Date
    let isFinished: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case joinCode = "join_code"
        case name
        case format
        case holes
        case courseName = "course_name"
        case courseRating = "course_rating"
        case slopeRating = "slope_rating"
        case par
        case courseHoles = "course_holes"
        case createdAt = "created_at"
        case isFinished = "is_finished"
    }

    init(_ round: Round) {
        id = round.id
        joinCode = round.joinCode
        name = round.name
        format = round.format.rawValue
        holes = round.holes
        courseName = round.courseName
        courseRating = round.courseRating
        slopeRating = round.slopeRating
        par = round.par
        courseHoles = round.courseHoles
        createdAt = round.createdAt
        isFinished = round.isFinished
    }

    var round: Round {
        Round(
            id: id,
            joinCode: joinCode,
            name: name,
            format: GameFormat(rawValue: format) ?? .strokePlay,
            holes: holes,
            courseName: courseName,
            courseRating: courseRating,
            slopeRating: slopeRating,
            par: par,
            courseHoles: courseHoles,
            createdAt: createdAt,
            isFinished: isFinished
        )
    }
}

private struct PlayerRecord: Codable {
    let id: String
    let roundID: String
    let name: String
    let handicapIndex: Double
    let teamNumber: Int?
    let teeColor: String
    let deviceID: String
    let courseHandicap: Int

    enum CodingKeys: String, CodingKey {
        case id
        case roundID = "round_id"
        case name
        case handicapIndex = "handicap_index"
        case teamNumber = "team_number"
        case teeColor = "tee_color"
        case deviceID = "device_id"
        case courseHandicap = "course_handicap"
    }

    init(_ player: Player) {
        id = player.id
        roundID = player.roundID
        name = player.name
        handicapIndex = player.handicapIndex
        teamNumber = player.teamNumber
        teeColor = player.teeColor
        deviceID = player.deviceID
        courseHandicap = player.courseHandicap
    }

    var player: Player {
        Player(
            id: id,
            roundID: roundID,
            name: name,
            handicapIndex: handicapIndex,
            teamNumber: teamNumber,
            teeColor: teeColor,
            deviceID: deviceID,
            courseHandicap: courseHandicap
        )
    }
}

private struct ScoreRecord: Codable {
    let id: String
    let roundID: String
    let playerID: String
    let holeNumber: Int
    let grossStrokes: Int

    enum CodingKeys: String, CodingKey {
        case id
        case roundID = "round_id"
        case playerID = "player_id"
        case holeNumber = "hole_number"
        case grossStrokes = "gross_strokes"
    }

    init(_ score: Score) {
        id = score.id
        roundID = score.roundID
        playerID = score.playerID
        holeNumber = score.holeNumber
        grossStrokes = score.grossStrokes
    }

    var score: Score {
        Score(
            id: id,
            roundID: roundID,
            playerID: playerID,
            holeNumber: holeNumber,
            grossStrokes: grossStrokes
        )
    }
}
