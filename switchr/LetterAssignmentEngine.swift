//
//  LetterAssignmentEngine.swift
//  switchr
//

import Foundation

struct LetterAssignmentWindow<ID: Hashable> {
    let id: ID
    let bundleID: String?
    let appName: String
}

struct LetterAssignment<ID: Hashable> {
    let id: ID
    let letter: Character?
}

struct LetterAssignmentResult<ID: Hashable> {
    let assignments: [LetterAssignment<ID>]
    let persistedLetters: [String: String]
}

struct LetterAssignmentEngine<ID: Hashable> {
    private static var pool: [Character] {
        Array("asdfghjklqwertyuiopzxcvbnm1234567890")
    }

    private var sessionLetters: [ID: Character] = [:]
    private var firstSeen: [ID: Int] = [:]
    private var seenCounter = 0

    mutating func assign(
        windows: [LetterAssignmentWindow<ID>],
        customLetters: [String: Character],
        reservedLetters: Set<Character>,
        persistedLetters: [String: String]
    ) -> LetterAssignmentResult<ID> {
        var taken = reservedLetters.union(customLetters.values)
        var persistedLetters = persistedLetters
        var primaryLetters: [String: Character] = [:]
        var seenApps = Set<String>()

        for window in windows {
            guard let bundleID = window.bundleID, seenApps.insert(bundleID).inserted else { continue }
            if let custom = customLetters[bundleID] {
                primaryLetters[bundleID] = custom
            } else if let stored = persistedLetters[bundleID]?.first, !taken.contains(stored) {
                primaryLetters[bundleID] = stored
                taken.insert(stored)
            }
        }

        for window in windows {
            guard let bundleID = window.bundleID, primaryLetters[bundleID] == nil else { continue }
            let candidates = window.appName.lowercased().filter(\.isLetter) + Self.pool
            guard let letter = candidates.first(where: { !taken.contains($0) }) else { continue }
            primaryLetters[bundleID] = letter
            taken.insert(letter)
            persistedLetters[bundleID] = String(letter)
        }

        for window in windows where firstSeen[window.id] == nil {
            firstSeen[window.id] = seenCounter
            seenCounter += 1
        }

        var appOrder: [String: Int] = [:]
        for window in windows {
            let bundleID = window.bundleID ?? ""
            if appOrder[bundleID] == nil {
                appOrder[bundleID] = appOrder.count
            }
        }
        let ordered = windows.sorted { lhs, rhs in
            let lhsApp = appOrder[lhs.bundleID ?? ""] ?? 0
            let rhsApp = appOrder[rhs.bundleID ?? ""] ?? 0
            if lhsApp != rhsApp { return lhsApp < rhsApp }
            return (firstSeen[lhs.id] ?? 0) < (firstSeen[rhs.id] ?? 0)
        }

        var holders: [String: ID] = [:]
        for (bundleID, group) in Dictionary(grouping: ordered, by: { $0.bundleID ?? "" }) {
            guard let primary = primaryLetters[bundleID] else { continue }
            let holder = group.first { sessionLetters[$0.id] == primary } ?? group.first
            if let holder {
                holders[bundleID] = holder.id
            }
        }

        var used = taken
        var newSessionLetters: [ID: Character] = [:]
        let assignments = ordered.map { window in
            let bundleID = window.bundleID ?? ""
            let letter: Character?
            if holders[bundleID] == window.id {
                letter = primaryLetters[bundleID]
            } else if let previous = sessionLetters[window.id], !used.contains(previous) {
                letter = previous
                used.insert(previous)
            } else {
                letter = Self.pool.first { !used.contains($0) }
                if let letter {
                    used.insert(letter)
                }
            }
            if let letter {
                newSessionLetters[window.id] = letter
            }
            return LetterAssignment(id: window.id, letter: letter)
        }

        sessionLetters = newSessionLetters
        let currentIDs = Set(ordered.map(\.id))
        firstSeen = firstSeen.filter { currentIDs.contains($0.key) }

        return LetterAssignmentResult(
            assignments: assignments,
            persistedLetters: persistedLetters
        )
    }
}
