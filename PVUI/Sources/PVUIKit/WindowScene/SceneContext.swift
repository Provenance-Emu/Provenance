//
//  SceneContext.swift
//  PVUI
//
//  Created by Joseph Mattiello on 10/10/24.
//


/// Singleton accessor for the current `UIWindowScene`
/// In your SceneDelegate:
/// func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions:
/// UIScene.ConnectionOptions) {
///    SceneContext.shared.currentScene = (scene as? UIWindowScene)
/// }
public final class SceneContext {
    
    /// Singleton instance
    static var shared = SceneContext()
    
    /// Current scene
    @MainActor
    var currentScene: UIWindowScene?

    /// Private init, use the Singleton
    private init() {}
}
