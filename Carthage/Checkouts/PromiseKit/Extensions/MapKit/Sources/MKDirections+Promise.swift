import MapKit
#if !PMKCocoaPods
import PromiseKit
#endif

/**
 To import the `MKDirections` category:

    use_frameworks!
    pod "PromiseKit/MapKit"

 And then in your sources:

    import PromiseKit
*/
extension MKDirections {
#if swift(>=4.2)
    /// Begins calculating the requested route information asynchronously.
    public func calculate() -> Promise<Response> {
        return Promise { calculate(completionHandler: $0.resolve) }
    }

    /// Begins calculating the requested travel-time information asynchronously.
    public func calculateETA() -> Promise<ETAResponse> {
        return Promise { calculateETA(completionHandler: $0.resolve) }
    }
#else
    /// Begins calculating the requested route information asynchronously.
    public func calculate() -> Promise<MKDirectionsResponse> {
        return Promise { calculate(completionHandler: $0.resolve) }
    }

    /// Begins calculating the requested travel-time information asynchronously.
    public func calculateETA() -> Promise<MKETAResponse> {
        return Promise { calculateETA(completionHandler: $0.resolve) }
    }
#endif
}
