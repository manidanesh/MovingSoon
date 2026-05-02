// KnownInstitutions.swift — Curated list of US financial institutions with brand colors
import Foundation

struct KnownInstitution: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let initials: String
    let colorHex: String
    let type: InstitutionType
    let websiteURL: URL?

    func hash(into hasher: inout Hasher) { hasher.combine(name) }
    static func == (lhs: KnownInstitution, rhs: KnownInstitution) -> Bool { lhs.name == rhs.name }
}

enum KnownInstitutions {

    // MARK: - All institutions grouped by type

    static var all: [KnownInstitution] { banks + creditUnions + creditCards + investments + studentLoans + mortgages }

    static let banks: [KnownInstitution] = [
        .init(name: "Chase",            initials: "CH", colorHex: "#117ACA", type: .bank,        websiteURL: URL(string: "https://www.chase.com")),
        .init(name: "Bank of America",  initials: "BA", colorHex: "#C0392B", type: .bank,        websiteURL: URL(string: "https://www.bankofamerica.com")),
        .init(name: "Wells Fargo",      initials: "WF", colorHex: "#B7410E", type: .bank,        websiteURL: URL(string: "https://www.wellsfargo.com")),
        .init(name: "Citibank",         initials: "CI", colorHex: "#154360", type: .bank,        websiteURL: URL(string: "https://www.citi.com")),
        .init(name: "Capital One",      initials: "C1", colorHex: "#D03027", type: .bank,        websiteURL: URL(string: "https://www.capitalone.com")),
        .init(name: "US Bank",          initials: "US", colorHex: "#1B4F72", type: .bank,        websiteURL: URL(string: "https://www.usbank.com")),
        .init(name: "TD Bank",          initials: "TD", colorHex: "#1E8449", type: .bank,        websiteURL: URL(string: "https://www.td.com")),
        .init(name: "PNC Bank",         initials: "PN", colorHex: "#D35400", type: .bank,        websiteURL: URL(string: "https://www.pnc.com")),
        .init(name: "Ally Bank",        initials: "AL", colorHex: "#7D3C98", type: .bank,        websiteURL: URL(string: "https://www.ally.com")),
        .init(name: "USAA",             initials: "UA", colorHex: "#1A237E", type: .bank,        websiteURL: URL(string: "https://www.usaa.com")),
        .init(name: "Truist",           initials: "TR", colorHex: "#4A235A", type: .bank,        websiteURL: URL(string: "https://www.truist.com")),
        .init(name: "Regions Bank",     initials: "RG", colorHex: "#17543C", type: .bank,        websiteURL: URL(string: "https://www.regions.com")),
        .init(name: "KeyBank",          initials: "KB", colorHex: "#1F618D", type: .bank,        websiteURL: URL(string: "https://www.key.com")),
        .init(name: "Citizens Bank",    initials: "CB", colorHex: "#145A32", type: .bank,        websiteURL: URL(string: "https://www.citizensbank.com")),
        .init(name: "Fifth Third Bank", initials: "5T", colorHex: "#1F4E79", type: .bank,        websiteURL: URL(string: "https://www.53.com")),
        .init(name: "Huntington",       initials: "HU", colorHex: "#186A3B", type: .bank,        websiteURL: URL(string: "https://www.huntington.com")),
        .init(name: "SoFi",             initials: "SF", colorHex: "#3D5A80", type: .bank,        websiteURL: URL(string: "https://www.sofi.com")),
        .init(name: "Marcus (Goldman)", initials: "MG", colorHex: "#212F3D", type: .bank,        websiteURL: URL(string: "https://www.marcus.com")),
        .init(name: "Chime",            initials: "CM", colorHex: "#1ABC9C", type: .bank,        websiteURL: URL(string: "https://www.chime.com")),
        .init(name: "Other Bank",       initials: "OT", colorHex: "#626567", type: .bank,        websiteURL: nil),
    ]

    static let creditUnions: [KnownInstitution] = [
        .init(name: "Navy Federal CU",  initials: "NF", colorHex: "#0D2137", type: .creditUnion, websiteURL: URL(string: "https://www.navyfederal.org")),
        .init(name: "Pentagon FCU",     initials: "PF", colorHex: "#1B2631", type: .creditUnion, websiteURL: URL(string: "https://www.penfed.org")),
        .init(name: "SchoolsFirst FCU", initials: "SC", colorHex: "#1A5276", type: .creditUnion, websiteURL: URL(string: "https://www.schoolsfirstfcu.org")),
        .init(name: "Local Credit Union",initials:"CU", colorHex: "#1D6A96", type: .creditUnion, websiteURL: nil),
    ]

    static let creditCards: [KnownInstitution] = [
        .init(name: "American Express", initials: "AX", colorHex: "#1F618D", type: .creditCard,  websiteURL: URL(string: "https://www.americanexpress.com")),
        .init(name: "Discover",         initials: "DC", colorHex: "#E67E22", type: .creditCard,  websiteURL: URL(string: "https://www.discover.com")),
        .init(name: "Apple Card",       initials: "AC", colorHex: "#2C3E50", type: .creditCard,  websiteURL: URL(string: "https://www.apple.com/apple-card")),
        .init(name: "Citi Credit Card", initials: "CC", colorHex: "#154360", type: .creditCard,  websiteURL: URL(string: "https://www.citi.com")),
    ]

    static let investments: [KnownInstitution] = [
        .init(name: "Fidelity",         initials: "FI", colorHex: "#27AE60", type: .investment,  websiteURL: URL(string: "https://www.fidelity.com")),
        .init(name: "Vanguard",         initials: "VG", colorHex: "#922B21", type: .investment,  websiteURL: URL(string: "https://www.vanguard.com")),
        .init(name: "Charles Schwab",   initials: "CS", colorHex: "#2E86C1", type: .investment,  websiteURL: URL(string: "https://www.schwab.com")),
        .init(name: "Robinhood",        initials: "RH", colorHex: "#27AE60", type: .investment,  websiteURL: URL(string: "https://www.robinhood.com")),
        .init(name: "E*TRADE",          initials: "ET", colorHex: "#6C3483", type: .investment,  websiteURL: URL(string: "https://www.etrade.com")),
        .init(name: "Betterment",       initials: "BE", colorHex: "#0E6655", type: .investment,  websiteURL: URL(string: "https://www.betterment.com")),
        .init(name: "Wealthfront",      initials: "WA", colorHex: "#1A5276", type: .investment,  websiteURL: URL(string: "https://www.wealthfront.com")),
        .init(name: "Acorns",           initials: "AC", colorHex: "#2E4057", type: .investment,  websiteURL: URL(string: "https://www.acorns.com")),
        .init(name: "401(k) / 403(b)",  initials: "4K", colorHex: "#1E8449", type: .investment,  websiteURL: nil),
        .init(name: "Employer 401(k)",  initials: "ER", colorHex: "#1D6A96", type: .investment,  websiteURL: nil),
    ]

    static let studentLoans: [KnownInstitution] = [
        .init(name: "Federal Student Aid",initials:"FA", colorHex: "#1A5276", type: .studentLoan, websiteURL: URL(string: "https://studentaid.gov")),
        .init(name: "Sallie Mae",         initials:"SM", colorHex: "#0077C8", type: .studentLoan, websiteURL: URL(string: "https://www.salliemae.com")),
        .init(name: "Navient",            initials:"NV", colorHex: "#005EB8", type: .studentLoan, websiteURL: URL(string: "https://www.navient.com")),
        .init(name: "MOHELA",             initials:"MO", colorHex: "#2E7D32", type: .studentLoan, websiteURL: URL(string: "https://www.mohela.com")),
        .init(name: "Aidvantage",         initials:"AV", colorHex: "#1B4F72", type: .studentLoan, websiteURL: URL(string: "https://aidvantage.com")),
        .init(name: "Nelnet",             initials:"NL", colorHex: "#154360", type: .studentLoan, websiteURL: URL(string: "https://www.nelnet.com")),
        .init(name: "SoFi Student Loans", initials:"SL", colorHex: "#3D5A80", type: .studentLoan, websiteURL: URL(string: "https://www.sofi.com")),
    ]

    static let mortgages: [KnownInstitution] = [
        .init(name: "Rocket Mortgage",   initials:"RM", colorHex: "#C0392B", type: .mortgage,    websiteURL: URL(string: "https://www.rocketmortgage.com")),
        .init(name: "United Wholesale",  initials:"UW", colorHex: "#1A5276", type: .mortgage,    websiteURL: URL(string: "https://www.uwm.com")),
        .init(name: "LoanDepot",         initials:"LD", colorHex: "#D35400", type: .mortgage,    websiteURL: URL(string: "https://www.loandepot.com")),
        .init(name: "Other Mortgage",    initials:"MG", colorHex: "#626567", type: .mortgage,    websiteURL: nil),
    ]
}
