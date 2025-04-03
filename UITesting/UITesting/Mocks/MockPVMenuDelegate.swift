//
//  MockPVMenuDelegate.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import Foundation
import PVUIBase

/// A mock implementation of the PVMenuDelegate protocol for testing
class MockPVMenuDelegate: PVMenuDelegate {
    func didTapImports() {
        print("MockPVMenuDelegate: didTapImports called")

    }
    
    func didTapSettings() {
        print("MockPVMenuDelegate: didTapSettings called")

    }
    
    func didTapHome() {
        print("MockPVMenuDelegate: didTapHome called")

    }
    
    func didTapAddGames() {
        print("MockPVMenuDelegate: didTapAddGames called")

    }
    
    func didTapConsole(with consoleId: String) {
        print("MockPVMenuDelegate: didTapConsole called: \(consoleId)")

    }
    
    func didTapCollection(with collection: Int) {
        print("MockPVMenuDelegate: didTapCollection called: \(collection)")

    }
    
    func closeMenu() {
        print("MockPVMenuDelegate: closeMenu called")

    }
    
    func showSettings() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showSettings called")
    }
    
    func showAbout() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showAbout called")
    }
    
    func showWebServer() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showWebServer called")
    }
    
    func showGameLibrary() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showGameLibrary called")
    }
    
    func showSaveStates() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showSaveStates called")
    }
    
    func showDebug() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showDebug called")
    }
    
    func showLogs() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showLogs called")
    }
}
