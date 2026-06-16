import Foundation

// Uses Supabase when configured in SupabaseConfig.swift, otherwise falls back to
// an in-memory store so the app still works locally without a backend.

@MainActor
final class CloudKitService {
    static let shared = CloudKitService()

    private let supabase = SupabaseService.shared

    // In-memory fallback stores
    private var rounds:  [String: Round]   = [:]
    private var players: [String: Player]  = [:]
    private var scores:  [String: Score]   = [:]
    private var wolfSelections: [String: WolfSelection] = [:]

    // MARK: - Round

    func saveRound(_ round: Round) async throws {
        if supabase.isConfigured {
            try await supabase.saveRound(round)
            return
        }
        rounds[round.id] = round
    }

    func fetchRound(joinCode: String) async throws -> Round? {
        if supabase.isConfigured {
            return try await supabase.fetchRound(joinCode: joinCode)
        }
        return rounds.values.first { $0.joinCode == joinCode }
    }

    func fetchRound(id: String) async throws -> Round? {
        if supabase.isConfigured {
            return try await supabase.fetchRound(id: id)
        }
        return rounds[id]
    }

    func markRoundFinished(_ round: Round) async throws {
        if supabase.isConfigured {
            try await supabase.markRoundFinished(round)
            return
        }
        var updated = round
        updated.isFinished = true
        rounds[round.id] = updated
    }

    // MARK: - Players

    func savePlayers(_ newPlayers: [Player]) async throws {
        if supabase.isConfigured {
            try await supabase.savePlayers(newPlayers)
            return
        }
        for p in newPlayers { players[p.id] = p }
    }

    func fetchPlayers(roundID: String) async throws -> [Player] {
        if supabase.isConfigured {
            return try await supabase.fetchPlayers(roundID: roundID)
        }
        return players.values.filter { $0.roundID == roundID }
    }

    // MARK: - Scores

    func saveScore(_ score: Score) async throws {
        if supabase.isConfigured {
            try await supabase.saveScore(score)
            return
        }
        scores[score.id] = score
    }

    func fetchScores(roundID: String) async throws -> [Score] {
        if supabase.isConfigured {
            return try await supabase.fetchScores(roundID: roundID)
        }
        return scores.values.filter { $0.roundID == roundID }
    }

    // MARK: - Wolf

    func saveWolfSelection(_ selection: WolfSelection) async throws {
        if supabase.isConfigured {
            try await supabase.saveWolfSelection(selection)
            return
        }
        wolfSelections[selection.id] = selection
    }

    func fetchWolfSelections(roundID: String) async throws -> [WolfSelection] {
        if supabase.isConfigured {
            return try await supabase.fetchWolfSelections(roundID: roundID)
        }
        return wolfSelections.values.filter { $0.roundID == roundID }
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
