// UnsplashService.swift — Fetches premium ambient photography
import Foundation

@Observable
final class UnsplashService {
    // The Access Key provided by the user
    private let accessKey = "LdfqNF5XOvLzBUlZlKhvDIdKjCZQ06sPmwPOLYkd8mY"
    
    // We cache fetched URLs so we don't spam the API on re-renders
    private var urlCache: [String: URL] = [:]
    
    /// Fetches a random, high-quality Unsplash photo tailored for a dark-mode background.
    func fetchAmbientBackgroundURL(for zip: String, cityBucket: String?) async -> URL? {
        let queryKey = cityBucket ?? zip
        
        // Return cached URL if we already fetched it this session
        if let cached = urlCache[queryKey] {
            return cached
        }
        
        // We append aesthetic keywords to ensure the image fits the "Picasso Bull" dark mode UI
        let searchKeywords = "\(queryKey),dark,moody,minimalist,landscape,night"
        
        guard var components = URLComponents(string: "https://api.unsplash.com/photos/random") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: accessKey),
            URLQueryItem(name: "query", value: searchKeywords),
            URLQueryItem(name: "orientation", value: "portrait")
        ]
        
        guard let url = components.url else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 5.0 // Don't block UI too long
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("Unsplash API Error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }
            
            let photo = try JSONDecoder().decode(UnsplashPhoto.self, from: data)
            if let photoURL = URL(string: photo.urls.regular) {
                urlCache[queryKey] = photoURL
                return photoURL
            }
            return nil
            
        } catch {
            print("Unsplash Network Error: \(error.localizedDescription)")
            return nil
        }
    }
}
