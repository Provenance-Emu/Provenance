import Foundation
import Testing
@testable import PVUIBase

struct SupportNagScheduleTests {
    private let now = Date(timeIntervalSince1970: 2_000_000)

    @Test func retainsExistingSessionThresholds() {
        let eligible = (0...55).filter { SupportNagSchedule.isEligible(completedSessions: $0, lastShown: nil, now: now) }
        #expect(eligible == [10, 25, 40, 55])
    }

    @Test func neverIncreasesExistingFourDayFrequency() {
        #expect(!SupportNagSchedule.isEligible(completedSessions: 25, lastShown: now.addingTimeInterval(-345_599), now: now))
        #expect(SupportNagSchedule.isEligible(completedSessions: 25, lastShown: now.addingTimeInterval(-345_600), now: now))
    }

    @Test func clockMovingBackwardsCannotTriggerPrompt() {
        #expect(!SupportNagSchedule.isEligible(completedSessions: 40, lastShown: now.addingTimeInterval(1), now: now))
    }

    @Test func unrelatedSessionDoesNotPromptAfterLongAbsence() {
        #expect(!SupportNagSchedule.isEligible(completedSessions: 26, lastShown: now.addingTimeInterval(-1_000_000), now: now))
    }
}
