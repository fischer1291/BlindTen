import Foundation

/// A season is one week of weekly leaderboards, Monday 00:00 to Monday
/// 00:00 UTC, the same moment Game Center's recurring leaderboards reset.
struct Season: Equatable, Sendable {
    /// ISO 8601 week-numbering year and week, e.g. 2026 and 42.
    let year: Int
    let week: Int
    let start: Date
    let end: Date

    init(date: Date) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
        start = interval?.start ?? date
        end = interval?.end ?? date.addingTimeInterval(7 * 86_400)
        week = calendar.component(.weekOfYear, from: date)
        year = calendar.component(.yearForWeekOfYear, from: date)
    }

    /// Whole days until the next season, 0 on the last day.
    func daysLeft(from date: Date) -> Int {
        max(0, Int(end.timeIntervalSince(date) / 86_400))
    }

}
