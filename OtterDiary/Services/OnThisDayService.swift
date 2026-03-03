import Foundation

struct OnThisDayService {
    var calendar: Calendar = Calendar(identifier: .gregorian)

    func entriesForOnThisDay(from entries: [DiaryEntry], targetDate: Date = .now) -> [DiaryEntry] {
        entriesForRecentYearsOnThisDay(from: entries, years: Int.max, targetDate: targetDate)
    }

    func entriesForYearOffsetOnThisDay(from entries: [DiaryEntry], yearOffset: Int, targetDate: Date = .now) -> [DiaryEntry] {
        let month = calendar.component(.month, from: targetDate)
        let day = calendar.component(.day, from: targetDate)
        let currentYear = calendar.component(.year, from: targetDate)
        let targetYear = currentYear - yearOffset

        return entries
            .filter { !$0.isDeleted }
            .filter { calendar.component(.year, from: $0.entryDate) == targetYear }
            .filter {
                calendar.component(.month, from: $0.entryDate) == month &&
                calendar.component(.day, from: $0.entryDate) == day
            }
            .sorted { $0.entryDate > $1.entryDate }
    }

    func entriesForRecentYearsOnThisDay(from entries: [DiaryEntry], years: Int, targetDate: Date = .now) -> [DiaryEntry] {
        let month = calendar.component(.month, from: targetDate)
        let day = calendar.component(.day, from: targetDate)
        let currentYear = calendar.component(.year, from: targetDate)
        let lowerBoundYear = max(0, currentYear - years)

        return entries
            .filter { !$0.isDeleted }
            .filter {
                let year = calendar.component(.year, from: $0.entryDate)
                return year < currentYear && year >= lowerBoundYear
            }
            .filter {
                calendar.component(.month, from: $0.entryDate) == month &&
                calendar.component(.day, from: $0.entryDate) == day
            }
            .sorted { $0.entryDate > $1.entryDate }
    }
}
