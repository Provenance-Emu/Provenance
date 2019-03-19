//
//  StartStopManager.swift
//  sReto
//
//  Created by Julian Asamer on 13/08/14.
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
* A RetryableAction should encapsulate some action that might fail or succeed after a certain delay. If it fails, or does not succeed in a specified time interval, it can be retried.
*
* For example, one might try to establish a connection to a server that might not be online. The process should be retried if it fails after a certain amount of time.
*
* You have to notify the RetryableActionExecutor about the success or failure of the action by calling onSuccess() or onFail().
*
*/
typealias RetryableAction = (_ attemptNumber: Int) -> Void

/**
A RetryableActionExecutor executes a RetryableAction in certain time intervals if necessary. The RetryableAction needs to notify the RetryableActionExecutor when an action succeeds or fails.
*/
class RetryableActionExecutor {
    /** The action to executed. */
    let action: RetryableAction
    /** The dispatch queue that the action is executed on. */
    let dispatchQueue: DispatchQueue
    /** The timer settings used to create the timer that triggers a retry. */
    let timerSettings: Timer.BackoffTimerSettings

    /** The timer used by the RetryableActionExecutor. */
    var timer: Timer?

    /**
    * Constructs a new RetryableActionExecutor.
    *
    * @param action: The action that should be retried if it does not succeed in time or fails.
    * @param timerSettings: Specifies the delay in which the action should be executed.
    * @param dispatchQueue: The dispatch queue on which actions should be executed.
    */
    init(action: @escaping RetryableAction, timerSettings: Timer.BackoffTimerSettings, dispatchQueue: DispatchQueue) {
        self.action = action
        self.timerSettings = timerSettings
        self.dispatchQueue = dispatchQueue
    }

    /**
    * Starts the RetryableActionExecutor. The action is called immediately when calling start. A timer is created with the given settings that retries the action if it does not succeed in time.
    */
    func start() {
        if self.timer != nil { return }

        self.timer = Timer.repeatActionWithBackoff(
            timerSettings: self.timerSettings,
            dispatchQueue: self.dispatchQueue,
            action: {
                timer, executionCount in
                self.action(executionCount + 1)
            }
        )

        self.dispatchQueue.async(execute: { self.action(0) })
    }
    /**
    * Stops trying to execute the RetryableAction.
    */
    func stop() {
        self.timer?.stop()
    }

    /**
    * Call this method when the RetryableAction succeeds. This method causes the executor to stop calling the action.
    */
    func onSuccess() {
        self.stop()
    }

    /**
    * Call this method when the RetryableAction succeeds. This method causes the executor to stop calling the action.
    */
    func onFail() {
        if self.timer == nil {
            self.start()
        }
    }
}

/**
* A StartStopHelper is a helper class for objects that have a "started" and "stopped" state, where both the transition to the "started" and "failed" state
* (ie. starting and stopping something) may fail and should be retried. Can also be used when the object switches from the "started" to the "stopped" state unexpectedly, and the "started" state should be restored.
*
* The user of this class should notify the StartStopHelper of state changes by calling onStart() and onStop().
* */
class StartStopHelper {
    /**
    * Represents the desired states this class should help reach.
    * */
    fileprivate enum State {
        case started
        case stopped
    }

    /** A RetryableActionExecutor that attempts to exectute the start action */
    let starter: RetryableActionExecutor
    /** A RetryableActionExecutor that attempts to exectute the stop action */
    let stopper: RetryableActionExecutor
    /** The state that should be reached.
    *
    * E.g.: When the switching the desired state to the started state (by calling start), the StartStopHelper will call
    * the start action until it is notified about a successful start via onStart(). */
    fileprivate var desiredState: State = .stopped
    /**
    * Whether the StartStopHelper is currently trying to reach or has reached the Started state.
    */
    var isStarted: Bool {
        return self.desiredState == .started
    }

    /**
    * Creates a new StartStopHelper.
    *
    * @param startAction The start action
    * @param stopAction The stop action
    * @param timerSettings The timer settings used to retry the start and stop actions
    * @param executor The executor to execute the start and stop action on.
    * */
    init(startBlock: @escaping RetryableAction, stopBlock: @escaping RetryableAction, timerSettings: Timer.BackoffTimerSettings, dispatchQueue: DispatchQueue) {
        self.starter = RetryableActionExecutor(action: startBlock, timerSettings: timerSettings, dispatchQueue: dispatchQueue)
        self.stopper = RetryableActionExecutor(action: stopBlock, timerSettings: timerSettings, dispatchQueue: dispatchQueue)
    }

    /**
    * Runs the startAction in delays until onStart is called.
    * */
    func start() {
        self.desiredState = .started

        stopper.stop()
        starter.start()
    }
    /**
    * Runs the startAction in delays until onStart is called.
    * */
    func stop() {
        self.desiredState = .stopped

        starter.stop()
        stopper.start()
    }

    /**
    * Call this method when the startAction succeeds, or a start occurs for another reason. Stops calling the start action. Starts calling the stop action if the stop() was called last (as opposed to start()).
    * */
    func confirmStartOccured() {
        self.starter.stop()
        if self.desiredState == .stopped {
            self.stopper.start()
        }
    }
    /**
    * Call this method when the stopAction succeeds, or a start occurs for another reason. Stops calling the stop action. Starts calling the start action if the start() was called last (as opposed to stop()).
    * */
    func confirmStopOccured() {
        self.stopper.stop()
        if self.desiredState == .started {
            self.starter.start()
        }
    }
}
