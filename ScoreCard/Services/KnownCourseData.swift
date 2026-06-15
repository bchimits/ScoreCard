import Foundation

enum KnownCourseData {
    static func course(matching name: String) -> CachedCourse? {
        let normalized = name.lowercased()
        if normalized.contains("arrowood") { return arrowoodAlbatross }
        if normalized.contains("goat hill") { return goatHillPark }
        return nil
    }

    private static let arrowoodAlbatross = CachedCourse(
        name: "Arrowood Golf Course",
        courseRating: 72.4,
        slopeRating: 135,
        par: 71,
        holes: zip(arrowoodPar.indices, arrowoodPar).map { index, par in
            Hole(number: index + 1, par: par, strokeIndex: arrowoodMensStrokeIndex[index])
        }
    )

    private static let arrowoodPar = [
        4, 5, 3, 4, 4, 4, 4, 3, 5,
        4, 3, 4, 5, 4, 3, 4, 4, 4
    ]

    private static let arrowoodMensStrokeIndex = [
        6, 4, 10, 2, 12, 18, 16, 8, 14,
        15, 11, 3, 17, 13, 9, 1, 5, 7
    ]

    // MARK: - Goat Hill Park, Oceanside CA

    private static let goatHillPark = CachedCourse(
        name: "Goat Hill Park",
        courseRating: 61.2,
        slopeRating: 94,
        par: 65,
        holes: zip(goatHillPar.indices, goatHillPar).map { index, par in
            Hole(number: index + 1, par: par, strokeIndex: goatHillMensStrokeIndex[index])
        }
    )

    private static let goatHillPar = [
        4, 3, 4, 4, 3, 3, 3, 4, 3,
        4, 3, 4, 3, 4, 5, 4, 3, 4
    ]

    private static let goatHillMensStrokeIndex = [
        14, 2, 16, 8, 6, 4, 10, 12, 18,
        11, 3, 5, 7, 15, 13, 1, 9, 17
    ]
}
