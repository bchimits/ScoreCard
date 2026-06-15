import Foundation
import CloudKit

struct Player: Identifiable, Codable {
    var id: String
    var roundID: String
    var name: String
    var handicapIndex: Double  // USGA Handicap Index (e.g. 12.4)
    var teamNumber: Int?        // nil for individual formats
    var teeColor: String        // "White", "Blue", "Red", etc.
    var deviceID: String        // identifies the device that created this player

    var courseHandicap: Int = 0  // computed and stored at round creation

    // Strokes received on a given hole (0 or 1, rarely 2 on high handicaps).
    func strokesOnHole(_ hole: Hole) -> Int {
        guard courseHandicap > 0 else { return 0 }
        // First 18 strokes: one stroke on each hole in stroke-index order
        // Next 18: a second stroke on holes starting from stroke index 1 again
        let strokes = min(courseHandicap, 36)
        if strokes >= hole.strokeIndex { return 1 }
        if strokes > 18 && (strokes - 18) >= hole.strokeIndex { return 1 }
        return 0
    }
}

extension Player {
    // USGA Course Handicap formula
    static func computeCourseHandicap(index: Double, slope: Int, rating: Double, par: Int) -> Int {
        let ch = index * (Double(slope) / 113.0) + (rating - Double(par))
        return Int(ch.rounded())
    }

    init(from record: CKRecord, roundID: String) {
        self.id             = record.recordID.recordName
        self.roundID        = roundID
        self.name           = record["name"] as? String ?? "Unknown"
        self.handicapIndex  = record["handicapIndex"] as? Double ?? 0
        self.teamNumber     = record["teamNumber"] as? Int
        self.teeColor       = record["teeColor"] as? String ?? "White"
        self.deviceID       = record["deviceID"] as? String ?? ""
        self.courseHandicap = record["courseHandicap"] as? Int ?? 0
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Player", recordID: CKRecord.ID(recordName: id))
        record["roundID"]        = roundID as CKRecordValue
        record["name"]           = name as CKRecordValue
        record["handicapIndex"]  = handicapIndex as CKRecordValue
        record["teeColor"]       = teeColor as CKRecordValue
        record["deviceID"]       = deviceID as CKRecordValue
        record["courseHandicap"] = courseHandicap as CKRecordValue
        if let t = teamNumber { record["teamNumber"] = t as CKRecordValue }
        return record
    }
}
