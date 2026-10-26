import Foundation

/// A calendar date is not an instant. Store its Gregorian components so travel,
/// daylight saving changes and the device's preferred calendar cannot change it.
enum DateOnly {
    private static func gregorian(using calendar: Calendar) -> Calendar {
        var result = Calendar(identifier: .gregorian)
        result.locale = Locale(identifier: "en_US_POSIX")
        result.timeZone = calendar.timeZone
        return result
    }

    static func string(from date: Date, calendar: Calendar = .current) -> String {
        let parts = gregorian(using: calendar).dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1, parts.month ?? 1, parts.day ?? 1)
    }

    static func date(from value: String?, calendar: Calendar = .current) -> Date? {
        guard let value, value.count == 10 else { return nil }
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), (1...9999).contains(year),
              let month = Int(parts[1]), (1...12).contains(month),
              let day = Int(parts[2]), (1...31).contains(day) else { return nil }
        let gregorian = gregorian(using: calendar)
        guard let date = gregorian.date(from: DateComponents(year: year, month: month, day: day)),
              string(from: date, calendar: calendar) == value else { return nil }
        return gregorian.startOfDay(for: date)
    }

    /// Existing stores contain only Date instants. Until backfilled, retain the
    /// day currently displayed in the supplied calendar rather than guessing an
    /// original timezone that was never saved.
    static func resolve(_ value: String?, legacy: Date?, calendar: Calendar = .current) -> Date? {
        date(from: value, calendar: calendar) ?? legacy.map { gregorian(using: calendar).startOfDay(for: $0) }
    }
}
