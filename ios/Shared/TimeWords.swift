import Foundation

/// The time and date as words, for the sentence widgets and word clock.
enum TimeWords {
    private static let ones = [
        "twelve", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
    ]
    private static let tens = ["", "", "twenty", "thirty", "forty", "fifty"]

    static func minuteWords(_ m: Int) -> String {
        if m == 0 { return "o'clock" }
        if m < 10 { return "oh \(ones[m])" }
        if m < 20 { return ones[m] }
        return tens[m / 10] + (m % 10 == 0 ? "" : " \(ones[m % 10])")
    }

    /// "ten forty", "nine oh five", "seven o'clock"
    static func time(_ date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hour = (parts.hour ?? 0) % 12
        return "\(ones[hour]) \(minuteWords(parts.minute ?? 0))"
    }

    static func period(_ date: Date) -> String {
        let h = Calendar.current.component(.hour, from: date)
        switch h {
        case 0..<5: return "at night"
        case 5..<12: return "in the morning"
        case 12..<17: return "in the afternoon"
        case 17..<21: return "in the evening"
        default: return "at night"
        }
    }

    static func weekday(_ date: Date) -> String { format(date, "EEEE") }
    static func month(_ date: Date) -> String { format(date, "MMMM") }
    static func day(_ date: Date) -> String { format(date, "d") }

    /// "Satur–" / "day", as an editorial headline.
    static func dayParts(_ date: Date) -> (String, String) {
        let name = weekday(date)
        let stem = name.hasSuffix("day") ? String(name.dropLast(3)) : name
        return ("\(stem)–", "day")
    }

    /// "It's 4 October, time now ten forty."
    static func sentence(_ date: Date) -> String {
        "It's \(day(date)) \(month(date)), time now \(time(date))."
    }

    private static func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = pattern
        return f.string(from: date)
    }
}
