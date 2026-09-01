//
//  CustomBindings.swift
//  Oriel
//

import AppKit
import Combine
import Foundation

struct CustomBinding: Codable, Identifiable, Equatable {
    var bundleID: String
    var appName: String
    var appPath: String
    var key: String

    var id: String { bundleID }
    var letter: Character? { key.first }
}

enum CustomBindingError: Error, Equatable, LocalizedError {
    case invalidKey
    case keyInUse(appName: String)

    var errorDescription: String? {
        switch self {
        case .invalidKey:
            return "Choose one letter or number."
        case let .keyInUse(appName):
            return "This key is already assigned to \(appName)."
        }
    }
}

final class CustomBindingsStore: ObservableObject {
    static let shared = CustomBindingsStore()
    static let defaultsKey = "customAppBindings"

    @Published private(set) var bindings: [CustomBinding]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: Self.defaultsKey),
              let decoded = try? JSONDecoder().decode([CustomBinding].self, from: data) else {
            bindings = []
            return
        }

        let cleaned = Self.cleaned(decoded)
        bindings = cleaned
        if cleaned != decoded {
            save()
        }
    }

    func add(_ binding: CustomBinding) throws {
        guard let key = Self.normalizedKey(binding.key) else {
            throw CustomBindingError.invalidKey
        }
        if let conflict = bindings.first(where: { $0.key == key && $0.bundleID != binding.bundleID }) {
            throw CustomBindingError.keyInUse(appName: conflict.appName)
        }

        var normalized = binding
        normalized.key = key
        bindings.removeAll { $0.bundleID == normalized.bundleID }
        bindings.append(normalized)
        sortBindings()
        save()
    }

    func remove(_ binding: CustomBinding) {
        bindings.removeAll { $0.id == binding.id }
        save()
    }

    func letter(for bundleID: String) -> Character? {
        bindings.first { $0.bundleID == bundleID }?.letter
    }

    var reservedLetters: Set<Character> {
        Set(bindings.compactMap(\.letter))
    }

    private static func cleaned(_ bindings: [CustomBinding]) -> [CustomBinding] {
        var bundleIDs = Set<String>()
        var keys = Set<String>()
        var result: [CustomBinding] = []

        for var binding in bindings {
            guard let key = normalizedKey(binding.key),
                  bundleIDs.insert(binding.bundleID).inserted,
                  keys.insert(key).inserted else {
                continue
            }
            binding.key = key
            result.append(binding)
        }
        return result.sorted {
            $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }

    private static func normalizedKey(_ key: String) -> String? {
        let normalized = key.lowercased()
        guard normalized.count == 1,
              let character = normalized.first,
              character.isLetter || character.isNumber else {
            return nil
        }
        return normalized
    }

    private func sortBindings() {
        bindings.sort {
            $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bindings) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
