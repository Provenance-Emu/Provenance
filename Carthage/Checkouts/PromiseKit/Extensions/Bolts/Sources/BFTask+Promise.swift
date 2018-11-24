#if !PMKCocoaPods
import PromiseKit
#endif
import Bolts

extension Promise {
    /**
     The provided closure is executed when this promise is resolved.
     */
    public func then<U>(on q: DispatchQueue? = conf.Q.map, body: @escaping (T) -> BFTask<U>) -> Promise<U?> {
        return then(on: q) { tee -> Promise<U?> in
            let task = body(tee)
            return Promise<U?> { seal in
                task.continueWith(block: { task in
                    if task.isCompleted {
                        seal.fulfill(task.result)
                    } else if let error = task.error {
                        seal.reject(error)
                    } else {
                        seal.reject(PMKError.invalidCallingConvention)
                    }
                    return nil
                })
            }
        }
    }
}
