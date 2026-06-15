import Foundation
import CloudKit

struct Round: Identifiable, Codable {
    var id: String          // CloudKit record name
    var joinCode: String    // 6-char code others use to join
    var name: String        // e.g. "Saturday Scramble"
    var format: GameFormat
    var holes: Int          // 9 or 18
    var courseName: String
    var courseRating: Double
    var slopeRating: Int
    var par: Int
    var courseHoles: [Hole]?
    var createdAt: Date
    var isFinished: Bool

    var holeList: [Hole] {
        if let courseHoles, !courseHoles.isEmpty {
            return Array(courseHoles.prefix(holes))
        }
        return holes == 9 ? .standard9() : .standard18()
    }
}

extension Round {
    init(from record: CKRecord) {
        self.id           = record.recordID.recordName
        self.joinCode     = record["joinCode"] as? String ?? ""
        self.name         = record["name"] as? String ?? ""
        self.format       = GameFormat(rawValue: record["format"] as? String ?? "") ?? .strokePlay
        self.holes        = record["holes"] as? Int ?? 18
        self.courseName   = record["courseName"] as? String ?? ""
        self.courseRating = record["courseRating"] as? Double ?? 72.0
        self.slopeRating  = record["slopeRating"] as? Int ?? 113
        self.par          = record["par"] as? Int ?? 72
        if let data = record["courseHoles"] as? Data {
            self.courseHoles = try? JSONDecoder().decode([Hole].self, from: data)
        } else {
            self.courseHoles = nil
        }
        self.createdAt    = record.creationDate ?? Date()
        self.isFinished   = record["isFinished"] as? Int == 1
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Round", recordID: CKRecord.ID(recordName: id))
        record["joinCode"]     = joinCode as CKRecordValue
        record["name"]         = name as CKRecordValue
        record["format"]       = format.rawValue as CKRecordValue
        record["holes"]        = holes as CKRecordValue
        record["courseName"]   = courseName as CKRecordValue
        record["courseRating"] = courseRating as CKRecordValue
        record["slopeRating"]  = slopeRating as CKRecordValue
        record["par"]          = par as CKRecordValue
        if let courseHoles, let data = try? JSONEncoder().encode(courseHoles) {
            record["courseHoles"] = data as CKRecordValue
        }
        record["isFinished"]   = (isFinished ? 1 : 0) as CKRecordValue
        return record
    }

    static func generateJoinCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }
}
