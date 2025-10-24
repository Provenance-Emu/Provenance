//
//  GameplayDurationTrackerUtil.swift
//  PVUI
//
//  Created by Joseph Mattiello on 9/19/24.
//



// MARK: Play Duration
protocol GameplayDurationTrackerUtil: class {
    var gameStartTime: Date? { get set }
    var game: PVGame! { get }

    func updatePlayedDuration()
    func updateLastPlayedTime()
    func resetPlayedDuration()
}
extension GameplayDurationTrackerUtil {
    public func updatePlayedDuration() {
        defer {
            // Clear any temp pointer to start time
            self.gameStartTime = nil
        }
        guard let gameStartTime = gameStartTime, let game = game else {
        ELOG("Game start time or game is nil")
            return
        }

        // Calcuate what the new total spent time should be
        let duration = gameStartTime.timeIntervalSinceNow * -1
        let totalTimeSpent = game.timeSpentInGame + Int(duration)
        ILOG("Played for duration \(duration). New total play time: \(totalTimeSpent) for \(game.title)")
        // Write that to the database
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                self.game.realm?.refresh()
                self.game.timeSpentInGame = totalTimeSpent
            }
        } catch {
            NSLog("\(error.localizedDescription)")
        }
    }

    public func updateLastPlayedTime() {
        ILOG("Updating last played")
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                self.game.realm?.refresh()
                self.game.lastPlayed = Date()
            }
        } catch {
            NSLog("\(error.localizedDescription)")
        }
    }
    
    func resetPlayedDuration() {
        ILOG("Resetting played duration")
        do {
            try RomDatabase.sharedInstance.writeTransaction {
                self.game.realm?.refresh()
                self.game.timeSpentInGame = 0
            }
        } catch {
            NSLog("\(error.localizedDescription)")
        }
    }
}
