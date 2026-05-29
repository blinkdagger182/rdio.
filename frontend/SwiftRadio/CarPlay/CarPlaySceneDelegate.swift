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
        configureNowPlayingTemplate()

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
        exploreTemplate?.updateSections(makeExploreSections(stations: stations))
        libraryTemplate?.updateSections(makeLibrarySections(stations: stations))
        searchTemplate?.updateSections([
            CPListSection(items: stations.map(makeStationItem(_:)))
        ])
    }

    private func makeHomeSections(stations: [RadioStation]) -> [CPListSection] {
        var sections: [CPListSection] = []

        let recentItems = stations.prefix(5).map(makeStationItem(_:))
        if !recentItems.isEmpty {
            sections.append(CPListSection(items: recentItems, header: "recent stations", sectionIndexTitle: nil))
        }

        if let station = StationsManager.shared.currentStation ?? stations.first {
            sections.append(CPListSection(items: [makeNowPlayingItem(station)], header: "now playing", sectionIndexTitle: nil))
        }

        let favorites = metadataItems(stations: stations, values: { $0.genreNames })
            .prefix(4)
            .map { makeCollectionItem(item: $0, stations: stations, filter: { $0.genreNames.contains($1) }) }
        if !favorites.isEmpty {
            sections.append(CPListSection(items: favorites, header: "favorites", sectionIndexTitle: nil))
        }

        return sections
    }

    private func makeNowPlayingItem(_ station: RadioStation) -> CPListItem {
        let item = CPListItem(text: station.name, detailText: "\(station.desc) • LIVE")
        station.getImage { image in item.setImage(image) }
        item.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }
            if StationsManager.shared.currentStation == nil {
                StationsManager.shared.set(station: station)
            }
            self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }
        return item
    }

    private func makeLibrarySections(stations: [RadioStation]) -> [CPListSection] {
        let collections = metadataItems(stations: stations, values: { $0.genreNames })
            .prefix(5)
            .map { makeCollectionItem(item: $0, stations: stations, filter: { $0.genreNames.contains($1) }) }

        return [
            CPListSection(items: collections, header: "collections", sectionIndexTitle: nil),
            CPListSection(items: stations.prefix(8).map(makeStationItem(_:)), header: "top stations", sectionIndexTitle: nil)
        ]
    }

    private func makeExploreSections(stations: [RadioStation]) -> [CPListSection] {
        let countries = metadataItems(stations: stations, values: { station in
            station.countryName.map { [$0] } ?? []
        }).prefix(8).map {
            makeCollectionItem(item: $0, stations: stations, filter: { $0.countryName == $1 })
        }

        let genres = metadataItems(stations: stations, values: { $0.genreNames }).prefix(8).map {
            makeCollectionItem(item: $0, stations: stations, filter: { $0.genreNames.contains($1) })
        }

        return [
            CPListSection(items: countries, header: "countries", sectionIndexTitle: nil),
            CPListSection(items: genres, header: "genres", sectionIndexTitle: nil),
            CPListSection(items: stations.prefix(20).map(makeStationItem(_:)), header: "stations", sectionIndexTitle: nil)
        ]
    }

    private func makeCollectionItem(item: RdioCarPlayMetadataItem, stations: [RadioStation], filter: @escaping (RadioStation, String) -> Bool) -> CPListItem {
        let listItem = CPListItem(text: item.name, detailText: "\(item.count) stations")
        listItem.setImage(symbolImage(for: item.name))
        listItem.handler = { [weak self] _, completion in
            guard let self else {
                completion()
                return
            }
            let matchingStations = stations.filter { filter($0, item.name) }
            let stationItems = matchingStations.map { self.makeStationItem($0) }
            let template = CPListTemplate(
                title: item.name,
                sections: [CPListSection(items: stationItems)]
            )
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
            completion()
        }
        return listItem
    }

    private func metadataItems(stations: [RadioStation], values: (RadioStation) -> [String]) -> [RdioCarPlayMetadataItem] {
        var counts: [String: Int] = [:]
        stations.forEach { station in
            values(station).forEach { counts[$0, default: 0] += 1 }
        }

        return counts
            .map { RdioCarPlayMetadataItem(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }
    }

    private func makeStationItem(_ station: RadioStation) -> CPListItem {
        let item = CPListItem(text: station.name, detailText: station.desc)
        station.getImage { image in item.setImage(image) }
        item.handler = { [weak self] _, completion in
            print("Selected station: \(station.name)")
            StationsManager.shared.set(station: station)
            FRadioPlayer.shared.play()
            self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }
        return item
    }

    private func symbolImage(for value: String) -> UIImage? {
        let lowercased = value.lowercased()
        if lowercased.contains("news") { return UIImage(systemName: "newspaper") }
        if lowercased.contains("morning") || lowercased.contains("pop") { return UIImage(systemName: "sun.max") }
        if lowercased.contains("jazz") || lowercased.contains("music") { return UIImage(systemName: "music.note") }
        if lowercased.contains("rock") { return UIImage(systemName: "guitars") }
        if lowercased.contains("classic") { return UIImage(systemName: "music.quarternote.3") }
        if lowercased.contains("talk") { return UIImage(systemName: "mic") }
        return UIImage(systemName: "heart")
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        print("CarPlay disconnected")
        self.interfaceController = nil
        homeTemplate = nil
        exploreTemplate = nil
        libraryTemplate = nil
        searchTemplate = nil
        CPNowPlayingTemplate.shared.remove(self)
        StationsManager.shared.removeObserver(self)
    }
}

// MARK: - Template Builders

private extension CarPlaySceneDelegate {
    func configureNowPlayingTemplate() {
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.add(self)
        nowPlaying.isUpNextButtonEnabled = true
        nowPlaying.upNextTitle = "Stations"
        nowPlaying.isAlbumArtistButtonEnabled = true

        let stationInfo = CPNowPlayingMoreButton { [weak self] _ in
            guard let self else { return }
            self.pushCurrentStationInfo()
        }
        nowPlaying.updateNowPlayingButtons([stationInfo])
    }

    func pushCurrentStationInfo() {
        guard let station = StationsManager.shared.currentStation else { return }
        let items = [
            CPListItem(text: "Station", detailText: station.name),
            CPListItem(text: "Region", detailText: station.desc),
            CPListItem(text: "Tags", detailText: station.longDesc.isEmpty ? "Radio Browser" : station.longDesc)
        ]
        items.forEach { $0.isEnabled = false }
        let template = CPListTemplate(title: station.name, sections: [
            CPListSection(items: items, header: "now playing", sectionIndexTitle: nil)
        ])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }
}

// MARK: - Now Playing

extension CarPlaySceneDelegate: CPNowPlayingTemplateObserver {
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        let stations = StationsManager.shared.stations
        let template = CPListTemplate(title: "Stations", sections: [
            CPListSection(items: stations.prefix(40).map(makeStationItem(_:)), header: "up next", sectionIndexTitle: nil)
        ])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        pushCurrentStationInfo()
    }
}

private struct RdioCarPlayMetadataItem {
    let name: String
    let count: Int
}

private extension RadioStation {
    var countryName: String? {
        desc
            .components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("radio browser") }
    }

    var genreNames: [String] {
        longDesc
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("radio browser") }
            .map { $0.localizedCapitalized }
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
