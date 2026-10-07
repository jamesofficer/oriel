//
//  WindowSearch.swift
//  Oriel
//
//  Orders windows for search mode, best match first.
//

import Foundation

enum WindowSearchGroup: Int {
    case other
    case pinned
    case closed
}

struct WindowSearchCandidate<ID: Hashable> {
    let id: ID
    let appName: String
    let title: String
    let group: WindowSearchGroup
    let lastUsed: Int?
}

enum WindowSearch {
    /// Equal matches put unpinned windows first, as pinned apps already
    /// have a letter. After that, the most recently used window wins.
    static func rank<ID: Hashable>(_ candidates: [WindowSearchCandidate<ID>], query: String) -> [ID] {
        let query = normalized(query).trimmingCharacters(in: .whitespaces)
        let matches = candidates.enumerated().compactMap { index, candidate -> (ID, SortKey)? in
            guard let quality = matchQuality(of: candidate, query: query) else { return nil }

            let key = SortKey(
                quality: quality.rawValue,
                group: candidate.group.rawValue,
                lastUsed: candidate.lastUsed ?? -1,
                index: index
            )
            return (candidate.id, key)
        }
        return matches.sorted { $0.1.isBefore($1.1) }.map(\.0)
    }

    private enum MatchQuality: Int {
        case appNamePrefix
        case wordPrefix
        case substring
        case appNameLettersInOrder
    }

    private struct SortKey {
        let quality: Int
        let group: Int
        let lastUsed: Int
        let index: Int

        func isBefore(_ other: SortKey) -> Bool {
            if quality != other.quality { return quality < other.quality }
            if group != other.group { return group < other.group }
            if lastUsed != other.lastUsed { return lastUsed > other.lastUsed }
            return index < other.index
        }
    }

    private static func matchQuality<ID>(of candidate: WindowSearchCandidate<ID>, query: String) -> MatchQuality? {
        guard !query.isEmpty else { return .appNamePrefix }

        let appName = normalized(candidate.appName)
        let title = normalized(candidate.title)

        if appName.hasPrefix(query) {
            return .appNamePrefix
        }

        if containsAtWordStart(appName, query) || containsAtWordStart(title, query) {
            return .wordPrefix
        }

        if appName.contains(query) || title.contains(query) {
            return .substring
        }

        if containsLettersInOrder(appName, query.filter { !$0.isWhitespace }) {
            return .appNameLettersInOrder
        }

        return nil
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: .diacriticInsensitive, locale: nil).lowercased()
    }

    private static func containsAtWordStart(_ text: String, _ query: String) -> Bool {
        text.ranges(of: query).contains { range in
            guard range.lowerBound != text.startIndex else { return true }

            let previous = text[text.index(before: range.lowerBound)]
            return !previous.isLetter && !previous.isNumber
        }
    }

    private static func containsLettersInOrder(_ text: String, _ letters: String) -> Bool {
        var remaining = letters[...]
        for character in text where character == remaining.first {
            remaining.removeFirst()
        }
        return remaining.isEmpty
    }
}

enum SearchText {
    /// Removes the last word and the spaces after it, like Option-Delete.
    static func deletingLastWord(_ text: String) -> String {
        var result = Substring(text)
        while result.last?.isWhitespace == true {
            result.removeLast()
        }
        while let last = result.last, !last.isWhitespace {
            result.removeLast()
        }
        return String(result)
    }

    /// Returns nil for keys that do not type text, such as arrows and Tab.
    /// AppKit sends function keys as characters in U+F700 to U+F8FF.
    static func typedText(_ characters: String?) -> String? {
        guard let characters, !characters.isEmpty else { return nil }

        let isTypable = characters.unicodeScalars.allSatisfy { scalar in
            !CharacterSet.controlCharacters.contains(scalar) && !(0xF700...0xF8FF).contains(scalar.value)
        }
        return isTypable ? characters : nil
    }
}
