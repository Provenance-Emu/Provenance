//
//  DelayedExecutor.swift
//  sReto
//
//  Created by Julian Asamer on 15/08/14.
//  Copyright (c) 2014 - 2016 Chair for Applied Software Engineering
//
//  Licensed under the MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness
//  for a particular purpose and noninfringement. in no event shall the authors or copyright holders be liable for any claim, damages or other liability, 
//  whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
//

import Foundation

/**
* A RepeatedExecutor executes an action repeatedly with a certain delay. On demand, the action can also be triggered immediately or after a short delay.
* */
class RepeatedExecutor {
    let regularDelay: Timer.TimeInterval
    let shortDelay: Timer.TimeInterval
    let dispatchQueue: DispatchQueue

    var action: (() -> Void)?
    var isStarted: Bool = false
    weak var timer: Timer?

    /**
    * Constructs a new RepeatableExecutor.
    *
    * @param actüion The action to execute.
    * @param regularDelay The delay in which the action is executed by default.
    * @param shortDelay The delay used when runActionInShortDelay is called.
    * @param executor The executor to execute the action with.
    * */
    init(regularDelay: Timer.TimeInterval, shortDelay: Timer.TimeInterval, dispatchQueue: DispatchQueue) {
        self.regularDelay = regularDelay
        self.shortDelay = shortDelay
        self.dispatchQueue = dispatchQueue
    }
    /**
    * Starts executing the action in regular delays.
    * */
    func start(_ action: @escaping () -> Void) {
        if self.isStarted {
            return
        }

        self.action = action
        self.isStarted = true
        self.resume()
    }
    /**
    * Stops executing the action in regular delays.
    * */
    func stop() {
        if !self.isStarted { return }

        self.action = nil
        self.isStarted = false
        self.interrupt()
    }

    /**
    * Runs the action immediately. Resets the timer, the next execution of the action will occur after the regular delay.
    * */
    func runActionNow() {
        self.resetTimer()
        self.action?()
    }

    /**
    * Runs the action after the short delay. After this, actions are executed in regular intervals again.
    * */
    func runActionInShortDelay() {
        self.interrupt()
        self.timer = Timer.delay(
            self.shortDelay,
            dispatchQueue: self.dispatchQueue,
            action: {
                () -> Void in
                self.action?()
                self.resume()
            }
        )
    }

    fileprivate func interrupt() {
        self.timer?.stop()
        self.timer = nil
    }

    fileprivate func resume() {
        if !self.isStarted {
            return
        }

        self.timer = Timer.repeatAction(
            interval: self.regularDelay,
            dispatchQueue: self.dispatchQueue,
            action: {
                (timer, executionCount) -> Void in
                self.action?()
                return
            }
        )
    }

    fileprivate func resetTimer() {
        self.interrupt()
        self.resume()
    }
}
