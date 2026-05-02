// RegionalIntelligenceService.swift — Maps zip codes to available regional brands
import Foundation

enum RegionalIntelligenceService {

    /// Returns the set of chip IDs that are available for the given zip code.
    /// National brands are not filtered here (they are always shown).
    /// This service only filters out strictly regional brands.
    static func availableRegionalChips(forZip zip: String) -> Set<String> {
        let (state, _) = ZipBucketService.bucket(zip: zip)
        var available: Set<String> = []

        // MARK: - Fitness
        
        // LA Fitness is absent in CO, UT, WY, MT, ND, SD, VT, ME
        let noLAFitnessStates: Set<String> = ["CO", "UT", "WY", "MT", "ND", "SD", "VT", "ME"]
        if !noLAFitnessStates.contains(state) {
            available.insert("lafitness")
        }

        // 24 Hour Fitness (CA, CO, TX, WA, OR, NV, HI, NY, NJ, FL, MD, VA)
        let states24H: Set<String> = ["CA", "CO", "TX", "WA", "OR", "NV", "HI", "NY", "NJ", "FL", "MD", "VA"]
        if states24H.contains(state) { available.insert("24hourfitness") }

        // Life Time Fitness (Major hubs)
        let statesLifeTime: Set<String> = ["MN", "TX", "IL", "CA", "CO", "NY", "NJ", "FL", "GA", "NC", "OH", "MI", "VA", "PA", "AZ", "NV", "UT", "WA"]
        if statesLifeTime.contains(state) { available.insert("lifetime") }

        // Equinox (NY, CA, IL, MA, DC, FL, TX)
        let statesEquinox: Set<String> = ["NY", "CA", "IL", "MA", "DC", "FL", "TX"]
        if statesEquinox.contains(state) { available.insert("equinox") }

        // VASA Fitness (CO, UT, AZ, OK, IN, WI, IL)
        let statesVASA: Set<String> = ["CO", "UT", "AZ", "OK", "IN", "WI", "IL"]
        if statesVASA.contains(state) { available.insert("vasa") }

        // EoS Fitness (AZ, CA, CO, FL, NV, TX, UT)
        let statesEoS: Set<String> = ["AZ", "CA", "CO", "FL", "NV", "TX", "UT"]
        if statesEoS.contains(state) { available.insert("eos") }

        // Chuze Fitness (CA, CO, NM, AZ, FL, TX, GA)
        let statesChuze: Set<String> = ["CA", "CO", "NM", "AZ", "FL", "TX", "GA"]
        if statesChuze.contains(state) { available.insert("chuze") }

        // JCC (Urban metros, prevalent nationally, but we'll include it in major states)
        let statesJCC: Set<String> = ["NY", "NJ", "PA", "MD", "DC", "VA", "FL", "GA", "IL", "MI", "OH", "TX", "CO", "AZ", "NV", "CA", "WA", "MA"]
        if statesJCC.contains(state) { available.insert("jcc") }


        // MARK: - Grocery
        
        // Publix (FL, GA, AL, SC, NC, TN, VA)
        let statesPublix: Set<String> = ["FL", "GA", "AL", "SC", "NC", "TN", "VA"]
        if statesPublix.contains(state) { available.insert("publix") }

        // H-E-B (TX)
        if state == "TX" { available.insert("heb") }

        // Meijer (MI, OH, IN, IL, KY, WI)
        let statesMeijer: Set<String> = ["MI", "OH", "IN", "IL", "KY", "WI"]
        if statesMeijer.contains(state) { available.insert("meijer") }

        // Wegmans (NY, PA, NJ, VA, MD, MA, NC)
        let statesWegmans: Set<String> = ["NY", "PA", "NJ", "VA", "MD", "MA", "NC"]
        if statesWegmans.contains(state) { available.insert("wegmans") }

        // Kroger (King Soopers, Ralphs, Fry's, Smith's, Fred Meyer)
        // Kroger operates everywhere, but under different names. We'll show "Kroger / King Soopers / Ralphs" broadly.
        // It's mostly absent from the Northeast (NY, NJ, PA, New England)
        let noKrogerStates: Set<String> = ["NY", "NJ", "PA", "CT", "MA", "RI", "ME", "NH", "VT"]
        if !noKrogerStates.contains(state) { available.insert("kroger") }

        // Safeway / Albertsons (West, SW, PNW, Mid-Atlantic)
        let statesSafeway: Set<String> = ["CA", "WA", "OR", "CO", "AZ", "NM", "NV", "ID", "MT", "WY", "TX", "MD", "VA", "DC"]
        if statesSafeway.contains(state) {
            available.insert("safeway")
            available.insert("albertsons")
        }


        // MARK: - ISPs / TV
        
        // Optimum (NY, NJ, CT, TX, NC)
        let statesOptimum: Set<String> = ["NY", "NJ", "CT", "TX", "NC"]
        if statesOptimum.contains(state) { available.insert("optimum") }

        // Verizon Fios (NY, NJ, PA, MD, VA, MA, DC, RI, DE)
        let statesFios: Set<String> = ["NY", "NJ", "PA", "MD", "VA", "MA", "DC", "RI", "DE"]
        if statesFios.contains(state) { available.insert("verizon") }

        // Cox (AZ, CA, NV, VA, LA, OK, NE, FL, GA, AR)
        let statesCox: Set<String> = ["AZ", "CA", "NV", "VA", "LA", "OK", "NE", "FL", "GA", "AR"]
        if statesCox.contains(state) { available.insert("cox") }

        return available
    }

    /// Set of chip IDs that are regional and subject to filtering.
    /// National brands are not in this list and are always shown.
    static let regionalChipIDs: Set<String> = [
        "lafitness", "24hourfitness", "lifetime", "equinox", "vasa", "eos", "chuze", "jcc",
        "publix", "heb", "meijer", "wegmans", "kroger", "safeway", "albertsons",
        "optimum", "verizon", "cox"
    ]
}
