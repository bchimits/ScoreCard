import Foundation
import CloudKit

struct Score: Identifiable, Codable {
    var id: String
    var roundID: String
    var playerID: String
    var holeNumber: Int
    var grossStrokes: Int  // raw score; 0 = not yet entered

    var isEntered: Bool { grossStrokes > 0 }
}

extension Score {
    init(from record: CKRecord) {
        self.id           = record.recordID.recordName
        self.roundID      = record["roundID"] as? String ?? ""
        self.playerID     = record["playerID"] as? String ?? ""
        self.holeNumber   = record["holeNumber"] as? Int ?? 0
        self.grossStrokes = record["grossStrokes"] as? Int ?? 0
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Score", recordID: CKRecord.ID(recordName: id))
        record["roundID"]      = roundID as CKRecordValue
        record["playerID"]     = playerID as CKRecordValue
        record["holeNumber"]   = holeNumber as CKRecordValue
        record["grossStrokes"] = grossStrokes as CKRecordValue
        return record
    }
}
