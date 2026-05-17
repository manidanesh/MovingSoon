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
