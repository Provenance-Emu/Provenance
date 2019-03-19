/**
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

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import Foundation

/**
This class offers several class methods for timer-related tasks.

All of the following examples take a dispatch queue as an optional parameter to run the action on.

Examples:

Execute an action after a fixed delay:

    Timer.delay(1, action: { print("Hello 1 second later!") })


Execute an action in a fixed interval and firing prematurely / stopping the timer:

    let timer = Timer.repeatAction(interval: 0.5) { (timer, executionCount) -> () in
        print("Hello, this is execution #\(executionCount + 1)")
    }
    
    //...
    timer.fire()
    //...
    timer.stop()

Execute an action in fixed intervals for a certain number of times:

    Timer.repeatAction(interval: 0.5, maximumExecutionCount: 5) { (timer, executionCount) -> () in
        print("Hello, this is execution #\(executionCount + 1)")
    }

Execute an action an arbitrary number of times, and stop at some point:

    Timer.repeatAction(interval: 0.5) { (timer, executionCount) -> () in
        print("Hello, this is execution #\(executionCount + 1)")
        if someCondition {
            print("Stopping now.")
            timer.stop()
        }
    }

Execute an action with growing delays. For example, when requesting data from a server that doesn't respond, it makes sense to have growing delays between each attempt. If it's your own server, it might save you from DDOSing yourself. It also limits the computation power wasted on the device.

    In this example, the action is executed with delays of 0.2, 0.4, 0.8, 1.6, ... seconds, but with a maximum of 10 seconds.

    Timer.repeatActionWithBackoff(initialDelay: 0.2,
        backOffFactor: 2.0, 
        maximumDelay: 10.0, 
        action: { (timer, executionCount) -> () in
            print("This action is executed in growing delays.")
        }
    )

Execute an action with user-specified delays (you figure out something to do with that).

    let digitsOfΠ: [Timer.TimeInterval] = [3,1,4,1,5,9,2,6,5,3]
    Timer.repeatAction(
        delayBlock: { (executionCount) -> Timer.TimeInterval in
            return digitsOfΠ[executionCount % 10]
        },
        action: { (timer, executionCount) -> () in
            print("What is this!")
        }
    )
*/
open class Timer {
    /**
    Represents a time interval in seconds
    */
    public typealias TimeInterval = Double
    /**
    An action executed by a Timer if it is repeated. A Timer object is passed to allow stopping of the timer, as well as the number of executions.
    */
    public typealias TimerAction = (_ timer: Timer, _ executionCount: Int) -> Void
    /**
    An function that returns a time interval.
    */
    public typealias DelayBlock = (_ executionCount: Int) -> TimeInterval

    /**
    Executes a block after a given delay.
    
    - parameter delay: The delay in seconds after which the action block is executed
    - parameter dispatchQueue: Optional. 
        
        A dispatch queue on which to execute the action.
        
        The main dispatch queue is used by default.
    - parameter action: The action to execute.
    */
    open class func delay(
        _ delay: TimeInterval,
        dispatchQueue: DispatchQueue = DispatchQueue.main,
        action: @escaping () -> Void) -> Timer {

        return Timer(
            delayBlock: { _ in delay },
            dispatchQueue: dispatchQueue,
            maximumExecutions: 1,
            action: {
                _, _ in
                action()
            }
        )
    }
    /**
    Executes a block in regular intervals.
    
    - parameter interval: The interval in seconds in which the action will be executed.
    - parameter dispatchQueue: Optional.
    
        A dispatch queue on which to execute the action. 
    
        The main dispatch queue is used by default.
    - parameter maximumExecutionCount: Optional.
        
        The maximum number of times the action will be executed. 
    
        Pass nil to not have a limit. 
    
        Nil by default.
    - parameter action: The action to execute.
    */
    open class func repeatAction(
        interval: TimeInterval,
        dispatchQueue: DispatchQueue = DispatchQueue.main,
        maximumExecutionCount: Int? = nil,
        action: @escaping TimerAction) -> Timer {

        return Timer(
            delayBlock: { _ in interval },
            dispatchQueue: dispatchQueue,
            maximumExecutions: maximumExecutionCount,
            action: action
        )
    }
    /**
    Executes a block in growing intervals. For example, with an initialDelay of 1 and a backOffFactor of 2, 
    the action will be executed using the following intervals: 1, 2, 4, 8, 16, ...
    
    - parameter initialDelay: The delay in seconds after which the action will be executed the first time.
    - parameter backOffFactor: Optional. 
    
        The delay will be increased by this factor with each execution of the action.
    
        1.5 by default.
    - parameter maximumDelay: Optional. 
    
        The delay will not increase past this maximum delay (also passed in seconds).
    
        Pass nil to not use a maximum delay.
    
        Nil by default.
    - parameter dispatchQueue: Optional. 
    
        A dispatch queue on which to execute the action.
    
        The main dispatch queue is used by default.
    - parameter maximumExecutionCount: Optional. 
   
        The maximum number of times the action will be executed. Pass nil to not have a limit.
    
        Nil by default.
    - parameter action: The action to execute.
    */
    open class func repeatActionWithBackoff (
        initialDelay: TimeInterval,
        backOffFactor: Double = 1.5,
        maximumDelay: TimeInterval? = nil,
        dispatchQueue: DispatchQueue = DispatchQueue.main,
        maximumExecutionCount: Int? = nil,
        action: @escaping TimerAction) -> Timer {

        return Timer(
            delayBlock: {
                executionCount in
                let timeInterval = TimeInterval(initialDelay * pow(backOffFactor, Double(executionCount)))
                if let maximum = maximumDelay { return min(timeInterval, maximum) }
                return timeInterval
            },
            dispatchQueue: dispatchQueue,
            maximumExecutions: maximumExecutionCount,
            action: action
        )
    }

    public typealias BackoffTimerSettings = (initialInterval: TimeInterval, backOffFactor: Double, maximumDelay: TimeInterval?)
    open class func repeatActionWithBackoff (
        timerSettings: BackoffTimerSettings,
        dispatchQueue: DispatchQueue = DispatchQueue.main,
        maximumExecutionCount: Int? = nil,
        action: @escaping TimerAction) -> Timer {

            return repeatActionWithBackoff(initialDelay: timerSettings.initialInterval, backOffFactor: timerSettings.backOffFactor, maximumDelay: timerSettings.maximumDelay, dispatchQueue: dispatchQueue, maximumExecutionCount: maximumExecutionCount, action: action)
    }
    /**
    Executes a block with user-specified delays.
    
    - parameter delayBlock: Should return the delay in seconds in which the next execution of the action should occur.
    - parameter dispatchQueue: Optional. 
    
        A dispatch queue on which to execute the action.
    
        The main dispatch queue is used by default.
    - parameter maximumExecutionCount: Optional. 
    
        The maximum number of times the action will be executed.
    
        Pass nil to not have a limit.
    
        Nil by default.
    - parameter action: The action to execute.
    */
    open class func repeatAction (
        delayBlock: @escaping DelayBlock,
        dispatchQueue: DispatchQueue = DispatchQueue.main,
        maximumExecutionCount: Int? = nil,
        action: @escaping TimerAction) -> Timer {

        return Timer(
            delayBlock: delayBlock,
            dispatchQueue: dispatchQueue,
            maximumExecutions: maximumExecutionCount,
            action: action
        )
    }

    fileprivate let dispatchQueue: DispatchQueue
    fileprivate let delayBlock: DelayBlock
    fileprivate let action: TimerAction
    fileprivate let maximumExecutions: Int?

    fileprivate var currentExecutionCount: Int = 0
    fileprivate var isDone: Bool = false

    fileprivate var selfRetain: Timer?

    fileprivate init(delayBlock: @escaping DelayBlock, dispatchQueue: DispatchQueue, maximumExecutions: Int?, action: @escaping TimerAction) {
        self.delayBlock = delayBlock
        self.dispatchQueue = dispatchQueue
        self.maximumExecutions = maximumExecutions
        self.action = action

        self.selfRetain = self
        self.startTimer()
    }

    /**
    Stops the Timer. No actions will be executed anymore.
    */
    open func stop() {
        self.isDone = true
        self.selfRetain = nil
    }

    /**
    Fires the timer prematurely. The action is only executed if the Timer is still running.
    */
    open func fire() {
        if self.isDone { return }

        self.action(self, self.currentExecutionCount)
        self.currentExecutionCount += 1

        if let maximum = self.maximumExecutions {
            if self.currentExecutionCount >= maximum { self.isDone = true }
        }

        if !self.isDone {
            self.startTimer()
        } else {
            self.selfRetain = nil
        }
    }
    fileprivate func startTimer() {
        let delay = Int64(self.delayBlock(self.currentExecutionCount) * Double(NSEC_PER_SEC))

        self.dispatchQueue.asyncAfter(
            deadline: DispatchTime.now() + Double(delay) / Double(NSEC_PER_SEC)) {
            [weak self] in
            if let weakSelf = self { weakSelf.fire() }
        }
    }
}
