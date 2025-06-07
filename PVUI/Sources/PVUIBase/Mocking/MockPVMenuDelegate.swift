//
//  MockPVMenuDelegate.swift
//  UITesting
//
//  Created by Cascade on 3/26/25.
//

import Foundation
import PVUIBase

/// A mock implementation of the PVMenuDelegate protocol for testing
public class MockPVMenuDelegate: PVMenuDelegate {
    
    public init() {}
    
    public func didTapImports() {
        print("MockPVMenuDelegate: didTapImports called")

    }
    
    public func didTapSettings() {
        print("MockPVMenuDelegate: didTapSettings called")

    }
    
    public func didTapHome() {
        print("MockPVMenuDelegate: didTapHome called")

    }
    
    public func didTapAddGames() {
        print("MockPVMenuDelegate: didTapAddGames called")

    }
    
    public func didTapConsole(with consoleId: String) {
        print("MockPVMenuDelegate: didTapConsole called: \(consoleId)")

    }
    
    public func didTapCollection(with collection: Int) {
        print("MockPVMenuDelegate: didTapCollection called: \(collection)")

    }
    
    public func closeMenu() {
        print("MockPVMenuDelegate: closeMenu called")

    }
    
    public func showSettings() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showSettings called")
    }
    
    public func showAbout() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showAbout called")
    }
    
    public func showWebServer() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showWebServer called")
    }
    
    public func showGameLibrary() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showGameLibrary called")
    }
    
    public func showSaveStates() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showSaveStates called")
    }
    
    public func showDebug() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showDebug called")
    }
    
    public func showLogs() {
        // No-op in testing environment
        print("MockPVMenuDelegate: showLogs called")
    }
}
