//
//  KeyboardLeaderOverride.swift
//  switchr
//

import Foundation

struct KeyboardIdentity: Codable, Hashable {
    let vendorID: Int?
    let productID: Int?
    let serialNumber: String?
    let locationID: Int?
    let transport: String?

    init(
        vendorID: Int?,
        productID: Int?,
        serialNumber: String?,
        locationID: Int?,
        transport: String?
    ) {
        let serialNumber = serialNumber?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSerialNumber = serialNumber?.isEmpty == false
        self.vendorID = vendorID
        self.productID = productID
        self.serialNumber = hasSerialNumber ? serialNumber : nil
        self.locationID = hasSerialNumber ? nil : locationID
        self.transport = hasSerialNumber ? nil : transport
    }
}

struct KeyboardDevice: Identifiable, Equatable {
    let identity: KeyboardIdentity
    let name: String
    let isBuiltIn: Bool

    var id: KeyboardIdentity { identity }
}

struct KeyboardLeaderOverride: Codable, Identifiable, Equatable {
    let id: UUID
    let keyboard: KeyboardIdentity
    var keyboardName: String
    var leaderKey: LeaderKey

    init(
        id: UUID = UUID(),
        keyboard: KeyboardIdentity,
        keyboardName: String,
        leaderKey: LeaderKey
    ) {
        self.id = id
        self.keyboard = keyboard
        self.keyboardName = keyboardName
        self.leaderKey = leaderKey
    }
}

enum LeaderKeySelection: Equatable {
    case `default`(LeaderKey)
    case override(KeyboardLeaderOverride)

    var leaderKey: LeaderKey {
        switch self {
        case let .default(leaderKey):
            return leaderKey
        case let .override(override):
            return override.leaderKey
        }
    }
}

enum LeaderKeyResolver {
    static func resolve(
        defaultKey: LeaderKey,
        overrides: [KeyboardLeaderOverride],
        connectedKeyboards: Set<KeyboardIdentity>
    ) -> LeaderKeySelection {
        if let override = overrides.first(where: { connectedKeyboards.contains($0.keyboard) }) {
            return .override(override)
        }
        return .default(defaultKey)
    }
}
