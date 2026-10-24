import Foundation

enum SupportLinks {
    // The website is being prepared; keep the published privacy page available meanwhile.
    static let website = URL(string: "https://movingsoon.app")!
    static let github = URL(string: "https://github.com/manidanesh/MovingSoon/issues")!
    static let contact = github
    static let email = URL(string: "mailto:support@movingsoon.app?subject=MovingSoon%20support")!
    static let privacy = URL(string: "https://github.com/manidanesh/MovingSoon/blob/main/PRIVACY_POLICY.md")!
}
