//
//  SceneDelegate.swift
//  VPNClient
//
//  Created by DREAMWORLD on 24/11/25.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var animatedLaunchVC: AnimatedLaunchViewController?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            
            // Create the SwiftUI view that provides the window contents.
            let contentView = ServerListView()
            let hostingController = UIHostingController(rootView: contentView)
            
            // Show animated launch screen first
            let animatedLaunch = AnimatedLaunchViewController()
            self.animatedLaunchVC = animatedLaunch
            window.rootViewController = animatedLaunch
            self.window = window
            window.makeKeyAndVisible()
            
            // Hide launch screen after delay and show main app
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self, weak window] in
                guard let self = self, let window = window else { return }
                
                self.animatedLaunchVC?.transitionToMainApp(in: window, with: hostingController)
                self.animatedLaunchVC = nil // Release reference
            }
        }
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
        // Release animated launch controller if still held
        animatedLaunchVC = nil
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
    }
}
