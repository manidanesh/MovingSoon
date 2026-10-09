import Foundation

enum PostalCodeService {
    static func normalize(_ raw: String) -> String {
        raw.filter { !$0.isWhitespace }.uppercased()
    }

    static func isValid(_ raw: String) -> Bool {
        let value = normalize(raw)
        return value.range(of: "^[0-9]{5}$", options: .regularExpression) != nil
            || value.range(of: "^[ABCEGHJ-NPRSTVXY][0-9][ABCEGHJ-NPRSTV-Z][0-9][ABCEGHJ-NPRSTV-Z][0-9]$",
                           options: .regularExpression) != nil
    }

    static let geographicFlags: Set<LifestyleFlag> = [
        .isAmerican, .isCanadian, .inOntario, .inBritishColumbia, .inQuebec, .inAlberta,
        .inManitoba, .inSaskatchewan, .inNovaScotia, .inNewBrunswick, .inNewfoundland,
        .inPEI, .inNorthwestTerritories, .inNunavut, .inYukon
    ]

    static func regionalFlags(for raw: String) -> Set<LifestyleFlag> {
        let value = normalize(raw)
        guard isValid(value) else { return [] }
        if value.count == 5 { return [.isAmerican] }
        var flags: Set<LifestyleFlag> = [.isCanadian]
        let province: LifestyleFlag?
        switch value.first {
        case "A": province = .inNewfoundland
        case "B": province = .inNovaScotia
        case "C": province = .inPEI
        case "E": province = .inNewBrunswick
        case "G", "H", "J": province = .inQuebec
        case "K", "L", "M", "N", "P": province = .inOntario
        case "R": province = .inManitoba
        case "S": province = .inSaskatchewan
        case "T": province = .inAlberta
        case "V": province = .inBritishColumbia
        case "X": province = value.hasPrefix("X0A") || value.hasPrefix("X0B") || value.hasPrefix("X0C")
            ? .inNunavut : .inNorthwestTerritories
        case "Y": province = .inYukon
        default: province = nil
        }
        if let province { flags.insert(province) }
        return flags
    }

    static func contexts(for move: Move, flags: Set<LifestyleFlag>) -> [Set<LifestyleFlag>] {
        let household = flags.subtracting(geographicFlags)
        let codes = [move.originZip, move.destinationZip].compactMap { $0 }.filter(isValid)
        if codes.isEmpty { return [flags] }
        return codes.map { household.union(regionalFlags(for: $0)) }
    }

    static func canReview(_ item: CatalogItem, for move: Move) -> Bool {
        canReview(item, contexts: contexts(for: move, flags: move.lifestyleProfile?.activeFlags ?? []))
    }

    static func canReview(_ item: CatalogItem, contexts: [Set<LifestyleFlag>]) -> Bool {
        contexts.contains { flags in
            let geography = flags.intersection(geographicFlags)
            guard item.excludes.intersection(geographicFlags).isDisjoint(with: geography),
                  item.requires.intersection(geographicFlags).isSubset(of: geography) else { return false }
            let anyGeography = item.requiresAny.intersection(geographicFlags)
            return anyGeography.isEmpty || !item.requiresAny.isSubset(of: geographicFlags)
                || !anyGeography.isDisjoint(with: geography)
        }
    }
}
