import XCTest
@testable import OtterDiary

final class OnThisDayServiceTests: XCTestCase {
    func testEntriesForOnThisDayMatchesPreviousYearsOnly() {
        let calendar = Calendar(identifier: .gregorian)
        let service = OnThisDayService(calendar: calendar)

        let targetDate = makeDate("2026-03-02")
        let matchingLastYear = DiaryEntry(entryDate: makeDate("2025-03-02"), title: "a", content: "1")
        let matchingOlder = DiaryEntry(entryDate: makeDate("2023-03-02"), title: "b", content: "2")
        let sameYear = DiaryEntry(entryDate: makeDate("2026-03-02"), title: "c", content: "3")
        let differentDay = DiaryEntry(entryDate: makeDate("2025-03-03"), title: "d", content: "4")

        let result = service.entriesForOnThisDay(from: [differentDay, sameYear, matchingOlder, matchingLastYear], targetDate: targetDate)

        XCTAssertEqual(result.map(\.entryDate), [makeDate("2025-03-02"), makeDate("2023-03-02")])
    }

    private func makeDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }
}
