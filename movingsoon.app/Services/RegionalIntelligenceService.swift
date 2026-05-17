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

        // LA Fitness (25 states)
        let statesLAFitness: Set<String> = ["CA", "FL", "TX", "IL", "GA", "PA", "WA", "NY", "NJ", "AZ", "OH", "MD", "VA", "MI", "MA", "IN", "MN", "TN", "NC", "WI", "CT", "SC", "OR", "DE", "RI"]
        if statesLAFitness.contains(state) { available.insert("lafitness") }

        // 24 Hour Fitness (9 states)
        let states24H: Set<String> = ["CA", "CO", "HI", "NV", "NJ", "NY", "OR", "TX", "WA"]
        if states24H.contains(state) { available.insert("24hourfitness") }

        // Life Time Fitness (32 states)
        let statesLifeTime: Set<String> = ["TX", "MN", "IL", "NY", "FL", "NJ", "GA", "CO", "AZ", "CA", "MI", "NC", "OH", "VA", "PA", "NV", "UT", "WA", "MA", "MD", "TN", "IN", "MO", "KS", "IA", "NE", "WI", "OK", "AL", "ID", "CT", "DE"]
        if statesLifeTime.contains(state) { available.insert("lifetime") }

        // Equinox (12 states + DC)
        let statesEquinox: Set<String> = ["NY", "CA", "FL", "IL", "TX", "MA", "CT", "DC", "NJ", "PA", "WA", "MI", "TN"]
        if statesEquinox.contains(state) { available.insert("equinox") }

        // VASA Fitness (8 states)
        let statesVASA: Set<String> = ["AZ", "CO", "IL", "IN", "NE", "OK", "UT", "WI"]
        if statesVASA.contains(state) { available.insert("vasa") }

        // EoS Fitness (7 states)
        let statesEoS: Set<String> = ["AZ", "CA", "FL", "GA", "NV", "TX", "UT"]
        if statesEoS.contains(state) { available.insert("eos") }

        // Chuze Fitness (7 states)
        let statesChuze: Set<String> = ["AZ", "CA", "CO", "FL", "GA", "NM", "TX"]
        if statesChuze.contains(state) { available.insert("chuze") }

        // JCC (Broad urban presence across 34 states/districts)
        let statesJCC: Set<String> = ["NY", "NJ", "PA", "MD", "DC", "VA", "FL", "GA", "IL", "MI", "OH", "TX", "CO", "AZ", "NV", "CA", "WA", "MA", "MN", "MO", "WI", "IN", "NC", "SC", "TN", "KY", "AL", "LA", "OK", "UT", "OR", "CT", "RI", "DE"]
        if statesJCC.contains(state) { available.insert("jcc") }


        // MARK: - Grocery

        // Publix (8 states)
        let statesPublix: Set<String> = ["FL", "GA", "AL", "SC", "NC", "TN", "VA", "KY"]
        if statesPublix.contains(state) { available.insert("publix") }

        // H-E-B (1 state)
        if state == "TX" { available.insert("heb") }

        // Meijer (6 states)
        let statesMeijer: Set<String> = ["MI", "OH", "IN", "IL", "WI", "KY"]
        if statesMeijer.contains(state) { available.insert("meijer") }

        // Wegmans (9 states + DC)
        let statesWegmans: Set<String> = ["NY", "PA", "NJ", "VA", "MD", "MA", "NC", "DE", "CT", "DC"]
        if statesWegmans.contains(state) { available.insert("wegmans") }

        // Kroger (35 states, mostly absent in Northeast/New England)
        let noKrogerStates: Set<String> = ["NY", "NJ", "PA", "CT", "MA", "RI", "ME", "NH", "VT", "HI"]
        if !noKrogerStates.contains(state) { available.insert("kroger") }

        // Safeway (18 states + DC)
        let statesSafeway: Set<String> = ["AK", "AZ", "CA", "CO", "DE", "DC", "HI", "ID", "MD", "MT", "NE", "NV", "NM", "OR", "SD", "VA", "WA", "WY"]
        if statesSafeway.contains(state) { available.insert("safeway") }

        // Albertsons (16 states)
        let statesAlbertsons: Set<String> = ["CA", "TX", "ID", "AZ", "AR", "CO", "LA", "MT", "NV", "NM", "ND", "OK", "OR", "UT", "WA", "WY"]
        if statesAlbertsons.contains(state) { available.insert("albertsons") }


        // MARK: - ISPs / TV

        // Optimum (21 states)
        let statesOptimum: Set<String> = ["AZ", "AR", "CA", "CT", "ID", "KS", "KY", "LA", "MS", "MO", "NV", "NJ", "NM", "NY", "NC", "OH", "OK", "PA", "TX", "VA", "WV"]
        if statesOptimum.contains(state) { available.insert("optimum") }

        // Verizon Fios (9 states + DC)
        let statesFios: Set<String> = ["NY", "NJ", "PA", "MD", "VA", "MA", "DC", "RI", "DE"]
        if statesFios.contains(state) { available.insert("verizon") }

        // Cox (19 states + DC)
        let statesCox: Set<String> = ["AZ", "AR", "CA", "CT", "FL", "GA", "ID", "IA", "KS", "LA", "MA", "MO", "NE", "NV", "NC", "OH", "OK", "RI", "VA", "DC"]
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
