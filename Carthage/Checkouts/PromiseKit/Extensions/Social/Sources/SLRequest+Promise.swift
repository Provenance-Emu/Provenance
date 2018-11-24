#if !PMKCocoaPods
import PMKFoundation
import PromiseKit
#endif
import Social

/**
 To import the `SLRequest` category:

    use_frameworks!
    pod "PromiseKit/Social"

 And then in your sources:

    import PromiseKit
*/
extension SLRequest {
    /**
     Performs the request asynchronously.

     - Returns: A promise that fulfills with the response.
     - SeeAlso: `URLDataPromise`
    */
    public func perform() -> Promise<(data: Data, response: HTTPURLResponse)> {
        return Promise { seal in
            perform { data, rsp, error in
                if let data = data, let rsp = rsp {
                    seal.fulfill((data, rsp))
                } else if let error = error {
                    seal.reject(error)
                } else {
                    seal.reject(PMKError.invalidCallingConvention)
                }
            }
        }
    }
}
