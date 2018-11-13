import Foundation
import RxSwift

final class RunLoopThreadScheduler: ImmediateSchedulerType {
    private let thread: Thread
    private let target: ThreadTarget
    
    init(threadName: String) {
        self.target = ThreadTarget()
        self.thread = Thread(target: target,
                            selector: #selector(ThreadTarget.threadEntryPoint),
                            object: nil)
        self.thread.name = threadName
        self.thread.start()
    }

    func schedule<StateType>(_ state: StateType, action: @escaping (StateType) -> Disposable) -> Disposable {
        let disposable = SingleAssignmentDisposable()
        
        var action: Action? = Action {
            if disposable.isDisposed {
                return
            }
            disposable.setDisposable(action(state))
        }
        
        action?.perform(#selector(Action.performAction),
                        on: thread,
                        with: nil,
                        waitUntilDone: false,
						modes: [RunLoop.Mode.default.rawValue])
        
        let actionDisposable = Disposables.create {
            action = nil
        }
        
        return Disposables.create(disposable, actionDisposable)
    }

    deinit {
        thread.cancel()
    }
}

private final class ThreadTarget: NSObject {
    @objc fileprivate func threadEntryPoint() {
        let runLoop = RunLoop.current
		runLoop.add(NSMachPort(), forMode: RunLoop.Mode.default)
        runLoop.run()
    }
}

private final class Action: NSObject {
    private let action: () -> ()
    
    init(action: @escaping () -> ()) {
        self.action = action
    }
    
    @objc func performAction() {
        action()
    }
}
