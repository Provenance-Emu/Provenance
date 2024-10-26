//
//  AppBootupState.swift
//  Provenance
//
//  Created by Joseph Mattiello on 10/26/24.
//  Copyright © 2024 Provenance Emu. All rights reserved.
//


import Foundation
import RxSwift
import RxRelay

class AppBootupState {
    enum State {
        case notStarted
        case initializingDatabase
        case databaseInitialized
        case initializingLibrary
        case completed
        case error(Error)
    }
    
    let currentState = BehaviorRelay<State>(value: .notStarted)
    
    func transition(to state: State) {
        currentState.accept(state)
    }
}
