//
//  SceneDelegate.swift
//  rdio.
//
//  Created by Fethi El Hassasna on 1/25/25.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    private var coordinator: MainCoordinator?
    
    private let audioService = AudioSetupService.shared
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // UI Setup
        setupUIAppearance()
        
        // Start the coordinator
        setupCoordinator(windowScene: windowScene)
    }
    
    private func setupUIAppearance() {
        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().tintColor = Config.tintColor
        UINavigationBar.appearance().prefersLargeTitles = true

        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        navigationAppearance.backgroundColor = .clear
        navigationAppearance.shadowColor = .clear
        navigationAppearance.largeTitleTextAttributes = [
            .foregroundColor: Config.primaryTextColor,
            .font: UIFont.systemFont(ofSize: 34, weight: .regular)
        ]
        navigationAppearance.titleTextAttributes = [
            .foregroundColor: Config.primaryTextColor,
            .font: UIFont.systemFont(ofSize: 17, weight: .medium)
        ]
        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance

        UISearchBar.appearance().tintColor = Config.tintColor
        UITableView.appearance().indicatorStyle = .white
    }
    
    private func setupCoordinator(windowScene: UIWindowScene) {
        coordinator = MainCoordinator(navigationController: UINavigationController())
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = coordinator?.navigationController
        window?.makeKeyAndVisible()
        
        coordinator?.start()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        audioService.activateAudioSession()
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        audioService.activateAudioSession()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        audioService.activateAudioSession()
    }
}
