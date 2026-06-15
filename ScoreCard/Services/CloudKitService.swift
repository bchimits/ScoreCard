import Foundation

// LOCAL TESTING MODE
// CloudKit requires a paid Apple Developer account ($99/yr).
// This file uses an in-memory store so the full app can be tested locally.
// When you have a developer account, delete everything below and uncomment
// the CloudKit implementation at the bottom of this file.

actor CloudKitService {
    static let shared = CloudKitService()

    // In-memory stores
    private var rounds:  [String: Round]   = [:]  // id -> Round
    private var players: [String: Player]  = [:]  // id -> Player
    private var scores:  [String: Score]   = [:]  // id -> Score

    // MARK: - Round

    func saveRound(_ round: Round) async throws {
        rounds[round.id] = round
    }

    func fetchRound(joinCode: String) async throws -> Round? {
        rounds.values.first { $0.joinCode == joinCode }
    }

    func fetchRound(id: String) async throws -> Round? {
        rounds[id]
    }

    func markRoundFinished(_ round: Round) async throws {
        var updated = round
        updated.isFinished = true
        rounds[round.id] = updated
    }

    // MARK: - Players

    func savePlayers(_ newPlayers: [Player]) async throws {
        for p in newPlayers { players[p.id] = p }
    }

    func fetchPlayers(roundID: String) async throws -> [Player] {
        players.values.filter { $0.roundID == roundID }
    }

    // MARK: - Scores

    func saveScore(_ score: Score) async throws {
        scores[score.id] = score
    }

    func fetchScores(roundID: String) async throws -> [Score] {
        scores.values.filter { $0.roundID == roundID }
    }
}


// =============================================================================
// CLOUDKIT IMPLEMENTATION — restore when you have a paid developer account
// =============================================================================
//
// import CloudKit
//
// actor CloudKitService {
//     static let shared = CloudKitService()
//     private let db = CKContainer.default().publicCloudDatabase
//
//     func saveRound(_ round: Round) async throws {
//         try await db.save(round.toCKRecord())
//     }
//
//     func fetchRound(joinCode: String) async throws -> Round? {
//         let pred = NSPredicate(format: "joinCode == %@", joinCode)
//         let query = CKQuery(recordType: "Round", predicate: pred)
//         let result = try await db.records(matching: query, resultsLimit: 1)
//         guard let (_, r) = result.matchResults.first, let record = try? r.get() else { return nil }
//         return Round(from: record)
//     }
//
//     func fetchRound(id: String) async throws -> Round? {
//         let record = try await db.record(for: CKRecord.ID(recordName: id))
//         return Round(from: record)
//     }
//
//     func markRoundFinished(_ round: Round) async throws {
//         let record = try await db.record(for: CKRecord.ID(recordName: round.id))
//         record["isFinished"] = 1 as CKRecordValue
//         try await db.save(record)
//     }
//
//     func savePlayers(_ players: [Player]) async throws {
//         let op = CKModifyRecordsOperation(recordsToSave: players.map { $0.toCKRecord() }, recordIDsToDelete: nil)
//         op.savePolicy = .changedKeys
//         try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
//             op.modifyRecordsResultBlock = { result in
//                 switch result {
//                 case .success: cont.resume()
//                 case .failure(let e): cont.resume(throwing: e)
//                 }
//             }
//             db.add(op)
//         }
//     }
//
//     func fetchPlayers(roundID: String) async throws -> [Player] {
//         let pred = NSPredicate(format: "roundID == %@", roundID)
//         let result = try await db.records(matching: CKQuery(recordType: "Player", predicate: pred), resultsLimit: 100)
//         return result.matchResults.compactMap { _, r in try? Player(from: r.get(), roundID: roundID) }
//     }
//
//     func saveScore(_ score: Score) async throws {
//         let op = CKModifyRecordsOperation(recordsToSave: [score.toCKRecord()], recordIDsToDelete: nil)
//         op.savePolicy = .allKeys
//         try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
//             op.modifyRecordsResultBlock = { result in
//                 switch result {
//                 case .success: cont.resume()
//                 case .failure(let e): cont.resume(throwing: e)
//                 }
//             }
//             db.add(op)
//         }
//     }
//
//     func fetchScores(roundID: String) async throws -> [Score] {
//         let pred = NSPredicate(format: "roundID == %@", roundID)
//         let result = try await db.records(matching: CKQuery(recordType: "Score", predicate: pred), resultsLimit: 400)
//         return result.matchResults.compactMap { _, r in try? Score(from: r.get()) }
//     }
// }
