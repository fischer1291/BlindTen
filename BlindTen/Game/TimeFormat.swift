import Foundation

/// Two-decimal number formatting for times and deviations.
enum TimeFormat {
    /// "10.27" (no unit; the unit comes from the localized string around it).
    static func seconds(_ value: TimeInterval, locale: Locale = .autoupdatingCurrent) -> String {
        Scoring.roundedToHundredths(value)
            .formatted(.number.precision(.fractionLength(2)).locale(locale))
    }

    /// "+0.27" or "-1.03". Always signed.
    static func signedDeviation(_ value: TimeInterval, locale: Locale = .autoupdatingCurrent) -> String {
        Scoring.roundedToHundredths(value)
            .formatted(
                .number
                    .precision(.fractionLength(2))
                    .sign(strategy: .always(includingZero: true))
                    .locale(locale)
            )
    }
}
