// CityBackgroundMapper.swift — Maps location data to premium background assets
import Foundation

struct CityBackgroundMapper {
    
    /// Returns the asset catalog image name based on the destination ZIP or City Bucket.
    static func getBackgroundAsset(forZip zip: String, cityBucket: String?) -> String {
        // VIP Specific Zip Codes
        if zip.starts(with: "802") || zip == "80014" || zip == "80202" {
            return "bg_denver"
        }
        
        if zip.starts(with: "926") || zip == "92656" {
            return "bg_laguna"
        }
        
        // General Archetypes based on Bucket
        if let bucket = cityBucket?.lowercased() {
            if bucket.contains("beach") || bucket.contains("coast") || bucket.contains("laguna") {
                return "bg_laguna"
            }
            if bucket.contains("mountain") || bucket.contains("denver") {
                return "bg_denver"
            }
        }
        
        // Default moody fallback
        return "bg_cityscape"
    }
}
