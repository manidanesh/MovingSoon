// LifestyleFlag.swift — All lifestyle flags that drive checklist generation
import Foundation

enum LifestyleFlag: String, CaseIterable, Codable {
    // MARK: - Transport
    case hasCar
    case hasElectricVehicle
    case usesRideShare          // Uber / Lyft
    case hasBike                // E-bike / scooter
    case hasMotorcycle
    case hasTollRoads
    case hasMultipleCars

    // MARK: - Household
    case hasPartner
    case hasChildren
    case hasPets
    case hasRoommates
    case workFromHome
    case isMultiGenerational    // parents / in-laws in home

    // MARK: - Housing
    case isOwning
    case isRenting
    case hasHOA
    case hasHomeSecurity
    case hasSolar

    // MARK: - Shopping
    case usesAmazon
    case usesCostco
    case usesSamsClub
    case usesBJs
    case usesTarget
    case usesWalmart
    case usesREI
    case usesBestBuy
    case usesIKEA
    case usesWayfair
    case usesPublix
    case usesHEB
    case usesMeijer
    case usesWegmans
    case usesKroger
    case usesSafeway
    case usesAlbertsons

    // MARK: - Food Delivery
    case usesDoorDash
    case usesUberEats
    case usesGrubhub
    case usesInstacart
    case usesAmazonFresh
    case usesHelloFresh
    case usesBlueApron
    case usesOtherMealKit

    // MARK: - Streaming
    case usesNetflix
    case usesHulu
    case usesDisneyPlus
    case usesHBOMax
    case usesAppleTVPlus
    case usesParamountPlus
    case usesPeacock
    case usesSpotify
    case usesAppleMusic
    case usesSiriusXM
    case usesYouTubePremium
    case usesGamingSubs         // Xbox / PS / Nintendo

    // MARK: - TV & Internet Providers
    case usesXfinity
    case usesSpectrum
    case usesDirecTV
    case usesDish
    case usesVerizonFios
    case usesATT
    case usesCox
    case usesOptimum

    // MARK: - Fitness
    case hasGymMembership
    case usesPlanetFitness
    case usesEquinox
    case usesLAFitness
    case usesPeloton
    case usesClassPass
    case usesCrossFit
    case usesOrangeTheory
    case usesYMCA
    case uses24HourFitness
    case usesLifeTime
    case usesJCC
    case usesVASA
    case usesEoS
    case usesChuze
    case usesCrunch
    case usesAnytimeFitness

    // MARK: - More / Misc
    case isVeteran
    case hasMedicare
    case isSelfEmployed
    case hasProfessionalLicenses
    case hasStudentLoans
    case hasMortgage
    case hasInvestmentAccounts
    case hasLifeInsurance
    case hasPetInsurance
    case hasUmbrellaInsurance
    case isRetired
    case hasFinancialAdvisor
    case hasWill

    // MARK: - New Personas & Demographics
    case hasHouseholdHelp
    case has529
    case hasFSA
    case usesAutoShipPetFood
    case runsBusiness
    case usesCloudInfrastructure
    case holdsCrypto
    case frequentTraveler
    case hasTSAPreCheck
    case needsParkingPermit
    case hasAirlineLoyalty
    case hasPension
    case usesMailOrderPharmacy
    case usesBarnesAndNoble
    case hasHomeWarranties
    case hasVehicleWarranty
    case livesInHouseOrTownhouse

    // MARK: - Media, Apps & Digital Wallets
    case usesSling
    case usesAppleAppStore
    case usesGooglePlay
    case usesApplePay
    case usesGooglePay
    case usesShopPay
    case usesPatreonSubstack

    // MARK: - ✈️ Airline Loyalty Programs (US)
    case hasDeltaSkyMiles
    case hasUnitedMileagePlus
    case hasAmericanAAdvantage
    case hasSouthwestRapidRewards
    case hasAlaskaMileagePlan
    case hasJetBlueTrueBlue
    case hasSpiritFreeSpirit
    case hasFrontierMiles

    // MARK: - ✈️ Airline Loyalty (Canadian)
    case hasAirCanadaAeroplan
    case hasWestJetRewards
    case hasPorterVIPorter

    // MARK: - ✈️ Airline Loyalty (International)
    case hasBritishAirwaysExecClub
    case hasFlyingBlue           // Air France / KLM
    case hasMilesAndMore         // Lufthansa
    case hasEmirateSkywards
    case hasQantasFrequentFlyer
    case hasKrisFlyer            // Singapore Airlines

    // MARK: - 🏨 Hotel Loyalty Programs
    case hasMarriottBonvoy
    case hasHiltonHonors
    case hasWorldOfHyatt
    case hasIHGOneRewards
    case hasWyndhamRewards
    case hasChoicePrivileges
    case hasBestWesternRewards

    // MARK: - 🚗 Rental Car Loyalty
    case hasHertzGold
    case hasEnterpriseNationalPlus
    case hasAvisBudgetPreferred

    // MARK: - 🚇 Transit Cards
    case hasPrestoCard           // Ontario / TTC
    case hasCompassCard          // Metro Vancouver
    case hasMetroCard            // NYC
    case hasClipperCard          // Bay Area
    case hasVentraCard           // Chicago
    case hasBreezCard            // Atlanta MARTA
    case hasOtherTransitCard

    // MARK: - 🛡️ Insurance — Vehicle Subtypes
    case hasAutoInsurance
    case hasMotorcycleInsurance
    case hasRVInsurance
    case hasBoatInsurance

    // MARK: - 🛡️ Insurance — Property Subtypes
    case hasHomeownersInsurance
    case hasRentersInsurance
    case hasLandlordInsurance    // Investment property
    case hasCondoInsurance
    case hasFloodInsurance       // NFIP or private — separate from homeowners

    // MARK: - 🛡️ Insurance — Specialty
    case hasJewelryInsurance
    case hasIDTheftProtection    // LifeLock etc.
    case hasDisabilityInsurance

    // MARK: - 📦 Subscription Boxes
    case usesBeautyBox           // Birchbox, IPSY, Allure
    case usesFabFitFun
    case usesBespokePost
    case usesWineClub            // Winc, Firstleaf
    case usesCoffeeSubscription  // Trade, Atlas, Peet's
    case usesKidsCrateBox        // KiwiCo, Little Passports
    case usesBookOfTheMonth
    case usesSnackBox            // Graze, NatureBox
    case usesClothingBox         // Stitch Fix, Trunk Club

    // MARK: - 📰 News & Magazines
    case usesNewYorkTimes
    case usesWashingtonPost
    case usesWallStreetJournal
    case usesLocalNewspaper
    case usesMagazineSubscription  // Vogue, GQ, Wired, etc.

    // MARK: - 🏡 Estate & Legal Planning
    case hasTrust                // Living Trust
    case hasPowerOfAttorney
    case hasHealthcareDirective
    case hasSafeDepositBox
    case hasRentalProperty       // Investment / Landlord

    // MARK: - 🌐 Digital Identity
    case hasPersonalWebsite
    case hasGoogleBusinessProfile
    case usesDomainRegistrar     // GoDaddy, Namecheap, etc.
    case usesPasswordManager     // 1Password, LastPass
    case hasProfessionalOnlineProfile  // LinkedIn, Behance, etc.

    // MARK: - 🌿 Community & Faith
    case attendsReligiousInstitution
    case belongsToSocialClub
    case donatesCharitably
    case hasPoliticalContributions

    // MARK: - 🏠 Smart Home
    case hasSmartThermostat      // Nest, Ecobee
    case hasSmartLocks
    case hasVideoDoorbells
    case hasPoolSpa
    case hasLawnCareService
    case hasPestControlService
    case hasCleaningService

    // MARK: - 🛺 Home Services (Physical Recurring)
    case hasSnowRemovalService
    case hasWindowWashingService
    case hasSepticTank
    case hasWell

    // MARK: - 🍁 Country & Region
    case isCanadian              // Master flag — swaps US catalog for Canada catalog
    case isAmerican              // Explicit US flag (default if neither set)

    // MARK: - 🍁 Canadian Provinces & Territories
    case inOntario               // ServiceOntario, Hydro One, Enbridge, TTC/Presto
    case inBritishColumbia       // ICBC, BC Hydro, FortisBC, TransLink/Compass
    case inQuebec                // SAAQ, RAMQ, Hydro-Québec, Énergir, Videotron, STM/OPUS
    case inAlberta               // Service Alberta, ATCO/ENMAX/EPCOR, AHS
    case inManitoba              // MPI, Manitoba Hydro
    case inSaskatchewan          // SGI, SaskPower, SaskEnergy, eHealth SK
    case inNovaScotia            // Access Nova Scotia, NS Power, MSI
    case inNewBrunswick          // SNB, NB Power
    case inNewfoundland          // SNL, Newfoundland Power, NL Health Services
    case inPEI                   // Access PEI, Maritime Electric
    case inNorthwestTerritories
    case inNunavut
    case inYukon
}

// MARK: - Lifestyle Profile (SwiftData model)

import SwiftData

@Model
final class LifestyleProfile {
    var move: Move?
    /// JSON-encoded [String] of active LifestyleFlag rawValues
    var activeFlagsJSON: String

    init() {
        self.activeFlagsJSON = "[]"
    }

    // MARK: - Flag access

    var activeFlags: Set<LifestyleFlag> {
        get {
            guard let data = activeFlagsJSON.data(using: .utf8),
                  let strings = try? JSONDecoder().decode([String].self, from: data) else { return [] }
            return Set(strings.compactMap { LifestyleFlag(rawValue: $0) })
        }
        set {
            let strings = newValue.map { $0.rawValue }
            if let data = try? JSONEncoder().encode(strings),
               let json = String(data: data, encoding: .utf8) {
                activeFlagsJSON = json
            }
        }
    }

    func has(_ flag: LifestyleFlag) -> Bool { activeFlags.contains(flag) }

    func set(_ flag: LifestyleFlag, to value: Bool) {
        var flags = activeFlags
        if value { flags.insert(flag) } else { flags.remove(flag) }
        activeFlags = flags
    }

    func toggle(_ flag: LifestyleFlag) { set(flag, to: !has(flag)) }
}
