import Foundation
import CloudKit

struct WolfSelection: Identifiable, Codable {
    enum Choice: String, Codable {
        case partner
        case loneWolf
    }

    var id: String
    var roundID: String
    var holeNumber: Int
    var wolfPlayerID: String
    var partnerPlayerID: String?
    var choice: Choice

    var isLoneWolf: Bool { choice == .loneWolf }
}

extension WolfSelection {
    init(from record: CKRecord) {
        self.id = record.recordID.recordName
        self.roundID = record["roundID"] as? String ?? ""
        self.holeNumber = record["holeNumber"] as? Int ?? 0
        self.wolfPlayerID = record["wolfPlayerID"] as? String ?? ""
        self.partnerPlayerID = record["partnerPlayerID"] as? String
        self.choice = Choice(rawValue: record["choice"] as? String ?? "") ?? .partner
    }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "WolfSelection", recordID: CKRecord.ID(recordName: id))
        record["roundID"] = roundID as CKRecordValue
        record["holeNumber"] = holeNumber as CKRecordValue
        record["wolfPlayerID"] = wolfPlayerID as CKRecordValue
        record["choice"] = choice.rawValue as CKRecordValue
        if let partnerPlayerID {
            record["partnerPlayerID"] = partnerPlayerID as CKRecordValue
        }
        return record
    }
}
