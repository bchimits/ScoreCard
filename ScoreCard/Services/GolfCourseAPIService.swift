import Foundation

struct GolfCourseAPIService {
    static let apiKeyStorageKey = "golfCourseAPIKey"

    var apiKey: String
    var baseURL = URL(string: "https://api.golfcourseapi.com")!

    func findCourseDetails(matching query: String) async throws -> GolfCourseDetails? {
        let search = try await searchCourses(query: query)
        guard let first = search.first else { return nil }
        return try await courseDetails(id: first.id)
    }

    func searchCourses(query: String) async throws -> [GolfCourseSummary] {
        var components = URLComponents(url: baseURL.appending(path: "/v1/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "search_query", value: query)]
        guard let url = components?.url else { throw GolfCourseAPIError.invalidURL }
        let response: GolfCourseSearchResponse = try await request(url)
        return response.courses
    }

    func courseDetails(id: Int) async throws -> GolfCourseDetails {
        let url = baseURL.appending(path: "/v1/courses/\(id)")
        return try await request(url)
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GolfCourseAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode(T.self, from: data)
        case 401:
            throw GolfCourseAPIError.unauthorized
        default:
            throw GolfCourseAPIError.requestFailed(httpResponse.statusCode)
        }
    }
}

enum GolfCourseAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The golf course API URL is invalid."
        case .invalidResponse:
            return "The golf course API returned an invalid response."
        case .unauthorized:
            return "GolfCourseAPI key is missing or invalid."
        case .requestFailed(let statusCode):
            return "GolfCourseAPI request failed with status \(statusCode)."
        }
    }
}

struct GolfCourseSearchResponse: Decodable {
    let courses: [GolfCourseSummary]
}

struct GolfCourseSummary: Decodable, Identifiable {
    let id: Int
    let clubName: String?
    let courseName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case clubName = "club_name"
        case courseName = "course_name"
    }
}

struct GolfCourseDetails: Decodable {
    let clubName: String?
    let courseName: String?
    let tees: GolfCourseTees?

    var bestTee: GolfCourseTee? {
        let allTees = (tees?.male ?? []) + (tees?.female ?? [])
        return allTees.first { $0.courseRating != nil && $0.slopeRating != nil && !$0.holes.isEmpty }
            ?? allTees.first { !$0.holes.isEmpty }
            ?? allTees.first
    }

    var displayName: String {
        if let courseName, let clubName, courseName != clubName {
            return "\(clubName) - \(courseName)"
        }
        return courseName ?? clubName ?? "Unknown Course"
    }

    enum CodingKeys: String, CodingKey {
        case clubName = "club_name"
        case courseName = "course_name"
        case tees
    }
}

struct GolfCourseTees: Decodable {
    let male: [GolfCourseTee]
    let female: [GolfCourseTee]

    enum CodingKeys: String, CodingKey {
        case male
        case female
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        male = try container.decodeIfPresent([GolfCourseTee].self, forKey: .male) ?? []
        female = try container.decodeIfPresent([GolfCourseTee].self, forKey: .female) ?? []
    }
}

struct GolfCourseTee: Decodable {
    let teeName: String?
    let courseRating: Double?
    let slopeRating: Int?
    let parTotal: Int?
    let holes: [GolfCourseHole]

    var scorecardHoles: [Hole] {
        holes.compactMap(\.scorecardHole).sorted { $0.number < $1.number }
    }

    enum CodingKeys: String, CodingKey {
        case teeName = "tee_name"
        case courseRating = "course_rating"
        case slopeRating = "slope_rating"
        case parTotal = "par_total"
        case par
        case holes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teeName = try container.decodeIfPresent(String.self, forKey: .teeName)
        courseRating = try container.decodeFlexibleDoubleIfPresent(forKey: .courseRating)
        slopeRating = try container.decodeFlexibleIntIfPresent(forKey: .slopeRating)
        parTotal = try container.decodeFlexibleIntIfPresent(forKey: .parTotal)
            ?? container.decodeFlexibleIntIfPresent(forKey: .par)
        holes = try container.decodeIfPresent([GolfCourseHole].self, forKey: .holes) ?? []
    }
}

struct GolfCourseHole: Decodable {
    let number: Int?
    let par: Int?
    let strokeIndex: Int?

    var scorecardHole: Hole? {
        guard let number, let par else { return nil }
        return Hole(number: number, par: par, strokeIndex: strokeIndex ?? number)
    }

    enum CodingKeys: String, CodingKey {
        case number
        case holeNumber = "hole_number"
        case par
        case strokeIndex = "stroke_index"
        case strokeIndexCamel = "strokeIndex"
        case handicap
        case handicapIndex = "handicap_index"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decodeFlexibleIntIfPresent(forKey: .number)
            ?? container.decodeFlexibleIntIfPresent(forKey: .holeNumber)
        par = try container.decodeFlexibleIntIfPresent(forKey: .par)
        strokeIndex = try container.decodeFlexibleIntIfPresent(forKey: .strokeIndex)
            ?? container.decodeFlexibleIntIfPresent(forKey: .strokeIndexCamel)
            ?? container.decodeFlexibleIntIfPresent(forKey: .handicap)
            ?? container.decodeFlexibleIntIfPresent(forKey: .handicapIndex)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let intValue = try decodeIfPresent(Int.self, forKey: key) { return intValue }
        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) { return Int(doubleValue) }
        if let stringValue = try decodeIfPresent(String.self, forKey: key) { return Int(stringValue) }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let doubleValue = try decodeIfPresent(Double.self, forKey: key) { return doubleValue }
        if let intValue = try decodeIfPresent(Int.self, forKey: key) { return Double(intValue) }
        if let stringValue = try decodeIfPresent(String.self, forKey: key) { return Double(stringValue) }
        return nil
    }
}
