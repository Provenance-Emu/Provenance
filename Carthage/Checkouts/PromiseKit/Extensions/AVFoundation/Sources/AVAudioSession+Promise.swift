import AVFoundation
import Foundation
#if !PMKCocoaPods
import PromiseKit
#endif

/**
 To import the `AVAudioSession` category:

    use_frameworks!
    pod "PromiseKit/AVFoundation"

 And then in your sources:

    import PromiseKit
*/
extension AVAudioSession {
    public func requestRecordPermission() -> Guarantee<Bool> {
        return Guarantee(resolver: requestRecordPermission)
    }
}
