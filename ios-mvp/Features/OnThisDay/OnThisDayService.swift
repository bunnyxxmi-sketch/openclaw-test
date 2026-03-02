import Foundation

public struct OnThisDayService {
    private let calendar: Calendar

    public init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar
    }

    /// Returns entries that match the same month/day in previous years.
    /// Priority: previous year first, then older years.
    public func entriesForOnThisDay(
        from allEntries: [DiaryEntry],
        targetDate: Date = .now,
        maxYearsBack: Int = 5,
        fallbackFromLeapDayToFeb28: Bool = true
    ) -> [DiaryEntry] {
        let targetYear = calendar.component(.year, from: targetDate)
        let targetMonth = calendar.component(.month, from: targetDate)
        let targetDay = calendar.component(.day, from: targetDate)

        let matchMonthDay: (DiaryEntry) -> Bool = { entry in
            let month = calendar.component(.month, from: entry.entryDate)
            let day = calendar.component(.day, from: entry.entryDate)
            if month == targetMonth && day == targetDay { return true }

            // Optional fallback for non-leap years: 2/29 -> 2/28
            if fallbackFromLeapDayToFeb28,
               targetMonth == 2, targetDay == 28,
               month == 2, day == 29,
               !calendar.isDate(targetDate, equalTo: entry.entryDate, toGranularity: .year) {
                return true
            }
            return false
        }

        let filtered = allEntries.filter { entry in
            guard !entry.isDeleted else { return false }
            let year = calendar.component(.year, from: entry.entryDate)
            guard year < targetYear else { return false }
            guard year >= targetYear - maxYearsBack else { return false }
            return matchMonthDay(entry)
        }

        return filtered.sorted { lhs, rhs in
            let lhsYear = calendar.component(.year, from: lhs.entryDate)
            let rhsYear = calendar.component(.year, from: rhs.entryDate)

            // Prioritize previous year records first.
            let lhsScore = abs((targetYear - 1) - lhsYear)
            let rhsScore = abs((targetYear - 1) - rhsYear)
            if lhsScore != rhsScore { return lhsScore < rhsScore }

            // Then by date descending.
            return lhs.entryDate > rhs.entryDate
        }
    }
}
