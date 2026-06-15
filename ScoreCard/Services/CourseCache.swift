import Foundation

struct CachedCourse: Codable {
    var name: String
    var courseRating: Double
    var slopeRating: Int
    var par: Int
    var holes: [Hole]?
}

final class CourseCache {
    static let shared = CourseCache()

    private let key = "savedCourses"

    private init() {}

    var all: [CachedCourse] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let courses = try? JSONDecoder().decode([CachedCourse].self, from: data)
        else { return [] }
        return courses
    }

    func find(name: String) -> CachedCourse? {
        all.first { $0.name.lowercased() == name.lowercased() }
    }

    func save(_ course: CachedCourse) {
        var existing = all.filter { $0.name.lowercased() != course.name.lowercased() }
        existing.insert(course, at: 0)
        if let data = try? JSONEncoder().encode(existing) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
