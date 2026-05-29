//
//  CarPlaySceneDelegate.swift
//  Swift Radio
//
//  Created by Fethi El Hassasna on 1/25/25.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//
//

import CarPlay
import FRadioPlayer

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    
    private var interfaceController: CPInterfaceController?
    private var homeTemplate: CPListTemplate?
    private var exploreTemplate: CPListTemplate?
    private var libraryTemplate: CPListTemplate?
    private var searchTemplate: CPListTemplate?
    private let audioService = AudioSetupService.shared
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let templateApplicationScene = scene as? CPTemplateApplicationScene else { return }
        // Set up the CarPlay window
        templateApplicationScene.delegate = self
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        print("CarPlay connected")
        self.interfaceController = interfaceController

        let templates = makeRootTemplates()
        let tabBar = CPTabBarTemplate(templates: templates)
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)
        
        // Then fetch and update stations
        if StationsManager.shared.stations.isEmpty {
            StationsManager.shared.fetch { [weak self] _ in
                self?.updateTemplates()
            }
        } else {
            updateTemplates()
        }
        
        // Subscribe to updates
        StationsManager.shared.addObserver(self)
    }

    private func makeRootTemplates() -> [CPTemplate] {
        let home = CPListTemplate(title: "rdio.", sections: [])
        home.tabTitle = "Home"
        home.tabImage = UIImage(systemName: "house.fill")

        let explore = CPListTemplate(title: "Explore", sections: [])
        explore.tabTitle = "Explore"
        explore.tabImage = UIImage(systemName: "dot.radiowaves.left.and.right")

        let library = CPListTemplate(title: "Library", sections: [])
        library.tabTitle = "Library"
        library.tabImage = UIImage(systemName: "rectangle.stack.fill")

        let search = CPListTemplate(title: "Search", sections: [])
        search.tabTitle = "Search"
        search.tabImage = UIImage(systemName: "magnifyingglass")

        homeTemplate = home
        exploreTemplate = explore
        libraryTemplate = library
        searchTemplate = search

        return [home, explore, library, search]
    }

    private func updateTemplates() {
        let stations = StationsManager.shared.stations
        print("Setting up stations list with \(stations.count) stations")

        homeTemplate?.updateSections(makeHomeSections(stations: stations))
        exploreTemplate?.updateSections([
            CPListSection(items: stations.prefix(40).map(makeStationItem(_:)))
        ])
        libraryTemplate?.updateSections(makeLibrarySections(stations: stations))
        searchTemplate?.updateSections([
            CPListSection(items: stations.map(makeStationItem(_:)))
        ])
    }

    private func makeHomeSections(stations: [RadioStation]) -> [CPListSection] {
        var sections: [CPListSection] = []

        if let station = StationsManager.shared.currentStation {
            let nowPlayingItem = CPListItem(text: station.name, detailText: "Now playing • \(station.desc)")
            station.getImage { image in nowPlayingItem.setImage(image) }
            nowPlayingItem.handler = { [weak self] _, completion in
                self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
                completion()
            }
            sections.append(CPListSection(items: [nowPlayingItem], header: "now playing", sectionIndexTitle: nil))
        }

        let recentItems = stations.prefix(5).map(makeStationItem(_:))
        sections.append(CPListSection(items: recentItems, header: "recent stations", sectionIndexTitle: nil))

        let favorites = Array(stations.prefix(4))
        if !favorites.isEmpty {
            sections.append(CPListSection(items: favorites.map(makeStationItem(_:)), header: "favorites", sectionIndexTitle: nil))
        }

        return sections
    }

    private func makeLibrarySections(stations: [RadioStation]) -> [CPListSection] {
        let favorites = CPListItem(text: "Favorite Stations", detailText: "\(min(stations.count, 15)) stations")
        favorites.setImage(UIImage(systemName: "heart"))

        let morning = CPListItem(text: "Morning Drive", detailText: "curated for the drive")
        morning.setImage(UIImage(systemName: "sun.max"))

        let focus = CPListItem(text: "Focus Mode", detailText: "low-distraction listening")
        focus.setImage(UIImage(systemName: "target"))

        let collections = [favorites, morning, focus]
        collections.forEach { item in
            item.handler = { _, completion in completion() }
        }

        return [
            CPListSection(items: collections, header: "collections", sectionIndexTitle: nil),
            CPListSection(items: stations.prefix(8).map(makeStationItem(_:)), header: "saved stations", sectionIndexTitle: nil)
        ]
    }

    private func makeStationItem(_ station: RadioStation) -> CPListItem {
        let item = CPListItem(text: station.name, detailText: station.desc)
        station.getImage { image in item.setImage(image) }
        item.handler = { _, completion in
            print("Selected station: \(station.name)")
            StationsManager.shared.set(station: station)
            FRadioPlayer.shared.play()
            completion()
        }
        return item
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        print("CarPlay disconnected")
        self.interfaceController = nil
        homeTemplate = nil
        exploreTemplate = nil
        libraryTemplate = nil
        searchTemplate = nil
        StationsManager.shared.removeObserver(self)
    }
}

// MARK: - StationsManagerObserver

extension CarPlaySceneDelegate: StationsManagerObserver {
    
    func stationsManager(_ manager: StationsManager, stationsDidUpdate stations: [RadioStation]) {
        print("Stations updated: \(stations.count) stations")
        DispatchQueue.main.async {
            self.updateTemplates()
        }
    }
    
    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?) {
        if let station {
            print("Station changed to: \(station.name)")
        }
        DispatchQueue.main.async {
            self.updateTemplates()
        }
    }
}
