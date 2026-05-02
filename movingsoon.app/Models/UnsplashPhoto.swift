// UnsplashPhoto.swift — Data models for Unsplash API
import Foundation

struct UnsplashPhoto: Codable {
    let id: String
    let urls: UnsplashPhotoURLs
}

struct UnsplashPhotoURLs: Codable {
    let raw: String
    let full: String
    let regular: String
    let small: String
    let thumb: String
}
