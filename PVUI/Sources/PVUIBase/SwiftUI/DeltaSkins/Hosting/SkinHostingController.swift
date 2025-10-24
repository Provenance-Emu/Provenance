import SwiftUI

/// Hosting controller that forces hidden Home Indicator and defers system gestures on edges
final class SkinHostingController<Content: View>: UIHostingController<Content> {
	#if os(iOS)
	/// Always hide the home indicator while emulation is active
	override var prefersHomeIndicatorAutoHidden: Bool { true }
	/// Defer system gestures on edges to reduce accidental swipes
	override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [.left, .right, .bottom] }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		setNeedsUpdateOfHomeIndicatorAutoHidden()
		setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
	}
	#endif
}
