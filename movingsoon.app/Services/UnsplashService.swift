// UnsplashService.swift — Fetches premium ambient photography
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.movingsoon", category: "UnsplashService")

@Observable
final class UnsplashService {
    // Unsplash API access key — registered under the MovingSoon app
    // Demo tier — rate limited to 50 requests/hour, shared across every install of the app.
    // The persisted cache below exists specifically to keep repeat launches from re-spending
    // that shared budget; if usage grows, this key needs to move to Unsplash's production tier.
    private let accessKey = "LdfqNF5XOvLzBUlZlKhvDIdKjCZQ06sPmwPOLYkd8mY"

    private let defaults: UserDefaults
    private let cachePrefix = "com.movingsoon.unsplashCache."
    // Re-fetch for variety after a week, but a stale entry is still served if the
    // refetch fails (e.g. the shared key is rate-limited) rather than losing the photo.
    private let cacheTTL: TimeInterval = 7 * 86400

    private struct CacheEntry: Codable {
        let urlString: String
        let fetchedAt: Date
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Fetches a random, high-quality Unsplash photo tailored for a dark-mode background.
    func fetchAmbientBackgroundURL(for zip: String, cityBucket: String?) async -> URL? {
        let queryKey = cityBucket ?? zip
        let cacheKey = cachePrefix + queryKey
        let cached = readCache(key: cacheKey)

        if let cached, Date().timeIntervalSince(cached.fetchedAt) < cacheTTL, let url = URL(string: cached.urlString) {
            return url
        }

        // We append aesthetic keywords to ensure the image fits the "Picasso Bull" dark mode UI
        let searchKeywords = "\(queryKey),dark,moody,minimalist,landscape,night"

        guard var components = URLComponents(string: "https://api.unsplash.com/photos/random") else {
            return cached.flatMap { URL(string: $0.urlString) }
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: accessKey),
            URLQueryItem(name: "query", value: searchKeywords),
            URLQueryItem(name: "orientation", value: "portrait")
        ]

        guard let url = components.url else { return cached.flatMap { URL(string: $0.urlString) } }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0 // Don't block UI too long

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                logger.error("Unsplash API error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                // Rate-limited (or otherwise failing) — serve the stale cached photo if we have one
                // rather than falling all the way back to the generic local background.
                return cached.flatMap { URL(string: $0.urlString) }
            }

            let photo = try JSONDecoder().decode(UnsplashPhoto.self, from: data)
            if let photoURL = URL(string: photo.urls.regular) {
                writeCache(key: cacheKey, entry: CacheEntry(urlString: photo.urls.regular, fetchedAt: Date()))
                return photoURL
            }
            return cached.flatMap { URL(string: $0.urlString) }

        } catch {
            logger.error("Unsplash network error: \(error.localizedDescription)")
            return cached.flatMap { URL(string: $0.urlString) }
        }
    }

    private func readCache(key: String) -> CacheEntry? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CacheEntry.self, from: data)
    }

    private func writeCache(key: String, entry: CacheEntry) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        defaults.set(data, forKey: key)
    }
}
