import Foundation

struct OnThisDayService {
    var calendar: Calendar = Calendar(identifier: .gregorian)

    func entriesForOnThisDay(from entries: [DiaryEntry], targetDate: Date = .now) -> [DiaryEntry] {
        let month = calendar.component(.month, from: targetDate)
        let day = calendar.component(.day, from: targetDate)
        let year = calendar.component(.year, from: targetDate)

        return entries
            .filter { !$0.isDeleted }
            .filter { calendar.component(.year, from: $0.entryDate) < year }
            .filter {
                calendar.component(.month, from: $0.entryDate) == month &&
                calendar.component(.day, from: $0.entryDate) == day
            }
            .sorted { $0.entryDate > $1.entryDate }
    }
}
