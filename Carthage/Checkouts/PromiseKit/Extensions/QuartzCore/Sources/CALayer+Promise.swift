#if !PMKCocoaPods
import PromiseKit
#endif
import QuartzCore

public extension CALayer {
    /**
     Adds an animation to a layer, returning a Guarantee which resolves when the animation stops.

         layer.add(.promise, animation: animation).done { finished in
             //…
         }
    */
    func add(_: PMKNamespacer, animation: CAAnimation, forKey key: String? = nil) -> Guarantee<Bool> {
        let proxy = Proxy()
        proxy.retainCycle = proxy
        animation.delegate = proxy
        add(animation, forKey: key)
        return proxy.pending.guarantee
    }
}

private class Proxy: NSObject, CAAnimationDelegate {
    var retainCycle: Proxy?
    let pending = Guarantee<Bool>.pending()

    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        pending.resolve(flag)
        retainCycle = nil
    }
}
