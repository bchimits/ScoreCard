import Foundation

enum KnownCourseData {
    static func course(matching name: String) -> CachedCourse? {
        let normalized = name.lowercased()
        guard normalized.contains("arrowood") else { return nil }
        return arrowoodAlbatross
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
}
