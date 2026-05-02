// FinancialInstitution.swift — On-device record of a user's selected institution
import Foundation
import SwiftData

@Model
final class FinancialInstitution {
    var id: UUID
    var name: String
    var initials: String
    var colorHex: String
    var typeRaw: String
    var websiteURLString: String?
    var move: Move?

    init(name: String, initials: String, colorHex: String, type: InstitutionType, websiteURL: URL? = nil) {
        self.id             = UUID()
        self.name           = name
        self.initials       = initials
        self.colorHex       = colorHex
        self.typeRaw        = type.rawValue
        self.websiteURLString = websiteURL?.absoluteString
    }

    var institutionType: InstitutionType {
        InstitutionType(rawValue: typeRaw) ?? .bank
    }

    var websiteURL: URL? {
        guard let s = websiteURLString else { return nil }
        return URL(string: s)
    }
}

enum InstitutionType: String, Codable, CaseIterable {
    case bank        = "Bank"
    case creditUnion = "Credit Union"
    case creditCard  = "Credit Card"
    case investment  = "Investment"
    case studentLoan = "Student Loan"
    case mortgage    = "Mortgage"

    var icon: String {
        switch self {
        case .bank:        return "building.columns.fill"
        case .creditUnion: return "person.2.fill"
        case .creditCard:  return "creditcard.fill"
        case .investment:  return "chart.line.uptrend.xyaxis"
        case .studentLoan: return "graduationcap.fill"
        case .mortgage:    return "house.fill"
        }
    }
}
