import Foundation

struct Hole: Identifiable, Codable {
    let number: Int       // 1–18
    var par: Int          // 3, 4, or 5
    var strokeIndex: Int  // 1–18, used for handicap stroke allocation (1 = hardest)

    var id: Int { number }
}

extension [Hole] {
    static func standard18() -> [Hole] {
        // Default pars and stroke indices for a generic 18-hole course.
        // Users can edit these in setup.
        let pars        = [4,4,3,4,5,4,3,5,4, 4,4,3,5,4,4,3,5,4]
        let strokeIndex = [1,9,15,5,13,3,17,7,11, 2,10,16,6,14,4,18,8,12]
        return (1...18).map { Hole(number: $0, par: pars[$0-1], strokeIndex: strokeIndex[$0-1]) }
    }

    static func standard9() -> [Hole] {
        let pars        = [4,4,3,4,5,4,3,5,4]
        let strokeIndex = [1,5,9,3,7,2,8,4,6]
        return (1...9).map { Hole(number: $0, par: pars[$0-1], strokeIndex: strokeIndex[$0-1]) }
    }
}
