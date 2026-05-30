//
//  CarPlaySceneDelegate.swift
//  rdio.
//
//  Created by Fethi El Hassasna on 1/25/25.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import CarPlay
import FRadioPlayer

class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {

    private var interfaceController: CPInterfaceController?
    private var homeTemplate: CPListTemplate?
    private var exploreTemplate: CPListTemplate?
    private var libraryTemplate: CPListTemplate?
    private var searchTabTemplate: CPListTemplate?
    private let audioService = AudioSetupService.shared

    private var exploreResponse: ExploreResponse?
    private var featuredStations: [RadioStation] = []

    // Coalesces rapid-fire observer callbacks into one update
    private var updateWorkItem: DispatchWorkItem?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let templateApplicationScene = scene as? CPTemplateApplicationScene else { return }
        templateApplicationScene.delegate = self
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didConnect interfaceController: CPInterfaceController) {
        print("CarPlay connected")
        self.interfaceController = interfaceController
        audioService.setupAudioSession()
        audioService.activateAudioSession()
        configureNowPlayingTemplate()

        let templates = makeRootTemplates()
        let tabBar = CPTabBarTemplate(templates: templates)
        interfaceController.setRootTemplate(tabBar, animated: false, completion: nil)

        if StationsManager.shared.stations.isEmpty {
            StationsManager.shared.fetch { [weak self] _ in
                DispatchQueue.main.async { self?.updateTemplates() }
            }
        } else {
            updateTemplates()
        }

        // Always remove before adding to prevent observer pile-up on reconnect
        StationsManager.shared.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .stationStoreDidChange, object: nil)
        StationsManager.shared.addObserver(self)
        NotificationCenter.default.addObserver(self, selector: #selector(storeDidChange), name: .stationStoreDidChange, object: nil)

        Task { [weak self] in await self?.fetchExploreData() }
    }

    @objc private func storeDidChange() {
        scheduleUpdate()
    }

    private func scheduleUpdate() {
        updateWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.updateTemplates() }
        updateWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func fetchExploreData() async {
        async let exploreTask = NetworkService.fetchExplore()
        async let featuredTask = NetworkService.fetchFeatured()
        do {
            let (explore, featured) = try await (exploreTask, featuredTask)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.exploreResponse = explore
                self.featuredStations = featured
                self.exploreTemplate?.updateSections(self.makeExploreSections())
                self.searchTabTemplate?.updateSections(self.makeSearchTabSections())
            }
        } catch {
            if Config.debugLog { print("CarPlay: fetchExploreData failed: \(error)") }
        }
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

        let searchTab = CPListTemplate(title: "Search", sections: [])
        searchTab.tabTitle = "Search"
        searchTab.tabImage = UIImage(systemName: "magnifyingglass")

        homeTemplate = home
        exploreTemplate = explore
        libraryTemplate = library
        searchTabTemplate = searchTab

        return [home, explore, library, searchTab]
    }

    private func updateTemplates() {
        guard interfaceController != nil else { return }
        let stations = StationsManager.shared.stations
        homeTemplate?.updateSections(makeHomeSections(stations: stations))
        exploreTemplate?.updateSections(makeExploreSections())
        libraryTemplate?.updateSections(makeLibrarySections())
        searchTabTemplate?.updateSections(makeSearchTabSections())
    }

    // MARK: - Section builders

    private func makeHomeSections(stations: [RadioStation]) -> [CPListSection] {
        var sections: [CPListSection] = []

        let recentItems = stations.prefix(5).map(makeStationItem(_:))
        if let s = safeSection(recentItems, header: "recent stations") { sections.append(s) }

        if let station = StationsManager.shared.currentStation ?? stations.first {
            sections.append(CPListSection(items: [makeNowPlayingItem(station)], header: "now playing", sectionIndexTitle: nil))
        }

        let genreItems = metadataItems(stations: stations, values: { $0.genreNames })
            .prefix(4)
            .map { makeCollectionItem(item: $0, stations: stations, filter: { $0.genreNames.contains($1) }) }
        if let s = safeSection(genreItems, header: "by genre") { sections.append(s) }

        return sections
    }

    private func makeExploreSections() -> [CPListSection] {
        let stations = StationsManager.shared.stations
        var sections: [CPListSection] = []

        // Local / Featured Stations
        let localSource = featuredStations.isEmpty ? Array(stations.prefix(8)) : Array(featuredStations.prefix(8))
        if let s = safeSection(localSource.map(makeStationItem(_:)), header: "local stations") { sections.append(s) }

        // Local countries — Southeast Asia (always visible)
        let seaCountries: [(name: String, code: String)] = [
            ("Malaysia", "MY"), ("Singapore", "SG"), ("Indonesia", "ID"),
            ("Brunei", "BN"), ("Thailand", "TH"), ("Philippines", "PH"), ("Vietnam", "VN")
        ]
        let seaItems = seaCountries.map { country -> CPListItem in
            makeDrillDownItem(title: country.name, subtitle: "local stations", symbol: UIImage(systemName: "globe.asia.australia.fill")) { [weak self] template in
                Task {
                    do {
                        let results = try await NetworkService.searchStations(query: country.code, filter: "countrycode")
                        await MainActor.run { [weak self] in
                            guard let self else { return }
                            template.updateSections([self.stationSection(results, title: country.name)])
                        }
                    } catch {
                        if Config.debugLog { print("CarPlay SEA fetch failed: \(error)") }
                    }
                }
            }
        }
        sections.append(CPListSection(items: seaItems, header: "local countries", sectionIndexTitle: nil))

        // Genres
        if let tags = exploreResponse?.featuredTags, !tags.isEmpty {
            let genreItems = tags.prefix(10).map { tag -> CPListItem in
                makeDrillDownItem(title: tag.name, subtitle: "\(tag.stationcount) stations", symbol: symbolImage(for: tag.name)) { [weak self] template in
                    Task {
                        do {
                            let results = try await NetworkService.searchStations(query: tag.name, filter: "tag")
                            await MainActor.run { [weak self] in
                                guard let self else { return }
                                template.updateSections([self.stationSection(results, title: tag.name)])
                            }
                        } catch {
                            if Config.debugLog { print("CarPlay genre fetch failed: \(error)") }
                        }
                    }
                }
            }
            sections.append(CPListSection(items: genreItems, header: "genres", sectionIndexTitle: nil))
        } else if !stations.isEmpty {
            let items = metadataItems(stations: stations, values: { $0.genreNames })
                .prefix(8)
                .map { makeCollectionItem(item: $0, stations: stations, filter: { $0.genreNames.contains($1) }) }
            if let s = safeSection(items, header: "genres") { sections.append(s) }
        }

        // Regions
        if let regions = exploreResponse?.regions, !regions.isEmpty {
            let regionItems = regions.prefix(8).map { region -> CPListItem in
                makeDrillDownItem(title: region.name, subtitle: "\(region.stationcount) stations", symbol: UIImage(systemName: "map")) { [weak self] template in
                    Task {
                        guard let code = region.codes.first, !code.isEmpty else { return }
                        do {
                            let results = try await NetworkService.searchStations(query: code, filter: "countrycode")
                            await MainActor.run { [weak self] in
                                guard let self else { return }
                                template.updateSections([self.stationSection(results, title: region.name)])
                            }
                        } catch {
                            if Config.debugLog { print("CarPlay region fetch failed: \(error)") }
                        }
                    }
                }
            }
            sections.append(CPListSection(items: regionItems, header: "regions", sectionIndexTitle: nil))
        }

        // Popular Countries
        if let countries = exploreResponse?.featuredCountries, !countries.isEmpty {
            let countryItems = countries.prefix(10).map { country -> CPListItem in
                makeDrillDownItem(title: country.name, subtitle: "\(country.stationcount) stations", symbol: UIImage(systemName: "globe")) { [weak self] template in
                    Task {
                        do {
                            let results = try await NetworkService.searchStations(query: country.code, filter: "countrycode")
                            await MainActor.run { [weak self] in
                                guard let self else { return }
                                template.updateSections([self.stationSection(results, title: country.name)])
                            }
                        } catch {
                            if Config.debugLog { print("CarPlay country fetch failed: \(error)") }
                        }
                    }
                }
            }
            sections.append(CPListSection(items: countryItems, header: "popular countries", sectionIndexTitle: nil))
        } else if !stations.isEmpty {
            let items = metadataItems(stations: stations, values: { station in
                station.countryName.map { [$0] } ?? []
            }).prefix(8).map {
                makeCollectionItem(item: $0, stations: stations, filter: { $0.countryName == $1 })
            }
            if let s = safeSection(items, header: "countries") { sections.append(s) }
        }

        return sections
    }

    private func makeLibrarySections() -> [CPListSection] {
        var sections: [CPListSection] = []

        let favorites = StationStore.shared.favorites
        if let s = safeSection(favorites.prefix(20).map(makeStationItem(_:)), header: "favorites") { sections.append(s) }

        let recent = StationStore.shared.recentlyPlayed
        if let s = safeSection(recent.prefix(20).map(makeStationItem(_:)), header: "recently played") { sections.append(s) }

        if sections.isEmpty {
            let empty = CPListItem(text: "No saved stations yet", detailText: "Play stations to see them here")
            empty.isEnabled = false
            sections.append(CPListSection(items: [empty]))
        }

        return sections
    }

    private func makeSearchTabSections() -> [CPListSection] {
        var sections: [CPListSection] = []

        let recent = StationStore.shared.recentlyPlayed
        if let s = safeSection(recent.prefix(10).map(makeStationItem(_:)), header: "recently played") { sections.append(s) }

        if let tags = exploreResponse?.featuredTags, !tags.isEmpty {
            let genreItems = tags.prefix(8).map { tag -> CPListItem in
                makeDrillDownItem(title: tag.name, subtitle: "\(tag.stationcount) stations", symbol: symbolImage(for: tag.name)) { [weak self] template in
                    Task {
                        do {
                            let results = try await NetworkService.searchStations(query: tag.name, filter: "tag")
                            await MainActor.run { [weak self] in
                                guard let self else { return }
                                template.updateSections([self.stationSection(results, title: tag.name)])
                            }
                        } catch {
                            if Config.debugLog { print("CarPlay search genre failed: \(error)") }
                        }
                    }
                }
            }
            if let s = safeSection(genreItems, header: "browse by genre") { sections.append(s) }
        } else {
            let stations = StationsManager.shared.stations
            let items = metadataItems(stations: stations, values: { $0.genreNames })
                .prefix(8)
                .map { makeCollectionItem(item: $0, stations: stations, filter: { $0.genreNames.contains($1) }) }
            if let s = safeSection(items, header: "browse by genre") { sections.append(s) }
        }

        if let countries = exploreResponse?.featuredCountries, !countries.isEmpty {
            let countryItems = countries.prefix(8).map { country -> CPListItem in
                makeDrillDownItem(title: country.name, subtitle: "\(country.stationcount) stations", symbol: UIImage(systemName: "globe")) { [weak self] template in
                    Task {
                        do {
                            let results = try await NetworkService.searchStations(query: country.code, filter: "countrycode")
                            await MainActor.run { [weak self] in
                                guard let self else { return }
                                template.updateSections([self.stationSection(results, title: country.name)])
                            }
                        } catch {
                            if Config.debugLog { print("CarPlay search country failed: \(error)") }
                        }
                    }
                }
            }
            if let s = safeSection(countryItems, header: "browse by country") { sections.append(s) }
        } else {
            let stations = StationsManager.shared.stations
            let items = metadataItems(stations: stations, values: { station in
                station.countryName.map { [$0] } ?? []
            }).prefix(8).map {
                makeCollectionItem(item: $0, stations: stations, filter: { $0.countryName == $1 })
            }
            if let s = safeSection(items, header: "browse by country") { sections.append(s) }
        }

        return sections
    }

    // MARK: - Safe section helpers

    /// Returns nil (skip) when items is empty, preventing CPListSection(items:[]) crash
    private func safeSection(_ items: [CPListItem], header: String? = nil) -> CPListSection? {
        guard !items.isEmpty else { return nil }
        return CPListSection(items: items, header: header, sectionIndexTitle: nil)
    }

    private func safeSection(_ items: ArraySlice<CPListItem>, header: String? = nil) -> CPListSection? {
        safeSection(Array(items), header: header)
    }

    /// Builds a one-section station list; shows "No stations found" placeholder when empty
    private func stationSection(_ stations: [RadioStation], title: String) -> CPListSection {
        let items = stations.prefix(30).map(makeStationItem(_:))
        if items.isEmpty {
            let placeholder = CPListItem(text: "No stations found", detailText: nil)
            placeholder.isEnabled = false
            return CPListSection(items: [placeholder])
        }
        return CPListSection(items: items, header: title.lowercased(), sectionIndexTitle: nil)
    }

    // MARK: - Item builders

    private func makeDrillDownItem(title: String, subtitle: String, symbol: UIImage?, onLoad: @escaping (CPListTemplate) -> Void) -> CPListItem {
        let item = CPListItem(text: title, detailText: subtitle)
        item.setImage(symbol)
        item.handler = { [weak self] _, completion in
            guard let self else { completion(); return }
            let loading = CPListItem(text: "Loading...", detailText: nil)
            loading.isEnabled = false
            let template = CPListTemplate(title: title, sections: [CPListSection(items: [loading])])
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
            onLoad(template)
            completion()
        }
        return item
    }

    private func makeNowPlayingItem(_ station: RadioStation) -> CPListItem {
        let item = CPListItem(text: station.name, detailText: "\(station.desc) • LIVE")
        station.getImage { image in item.setImage(image) }
        item.handler = { [weak self] _, completion in
            guard let self else { completion(); return }
            self.play(station)
            self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }
        return item
    }

    private func makeCollectionItem(item: RdioCarPlayMetadataItem, stations: [RadioStation], filter: @escaping (RadioStation, String) -> Bool) -> CPListItem {
        let listItem = CPListItem(text: item.name, detailText: "\(item.count) stations")
        listItem.setImage(symbolImage(for: item.name))
        listItem.handler = { [weak self] _, completion in
            guard let self else { completion(); return }
            let matching = stations.filter { filter($0, item.name) }
            // matching could be empty — stationSection guards against that
            let template = CPListTemplate(title: item.name, sections: [self.stationSection(matching, title: item.name)])
            self.interfaceController?.pushTemplate(template, animated: true, completion: nil)
            completion()
        }
        return listItem
    }

    private func makeStationItem(_ station: RadioStation) -> CPListItem {
        let item = CPListItem(text: station.name, detailText: station.desc)
        station.getImage { image in item.setImage(image) }
        item.handler = { [weak self] _, completion in
            print("Selected station: \(station.name)")
            self?.play(station)
            self?.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            completion()
        }
        return item
    }

    private func play(_ station: RadioStation) {
        audioService.activateAudioSession()
        StationsManager.shared.set(station: station)
        FRadioPlayer.shared.play()
        // No updateTemplates() here — stationDidChange observer handles it via scheduleUpdate()
    }

    private func metadataItems(stations: [RadioStation], values: (RadioStation) -> [String]) -> [RdioCarPlayMetadataItem] {
        var counts: [String: Int] = [:]
        stations.forEach { station in values(station).forEach { counts[$0, default: 0] += 1 } }
        return counts
            .map { RdioCarPlayMetadataItem(name: $0.key, count: $0.value) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
    }

    private func symbolImage(for value: String) -> UIImage? {
        let v = value.lowercased()
        if v.contains("news") { return UIImage(systemName: "newspaper") }
        if v.contains("pop") || v.contains("morning") { return UIImage(systemName: "sun.max") }
        if v.contains("jazz") || v.contains("music") { return UIImage(systemName: "music.note") }
        if v.contains("rock") { return UIImage(systemName: "guitars") }
        if v.contains("classic") { return UIImage(systemName: "music.quarternote.3") }
        if v.contains("talk") { return UIImage(systemName: "mic") }
        return UIImage(systemName: "heart")
    }

    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                  didDisconnectInterfaceController interfaceController: CPInterfaceController) {
        print("CarPlay disconnected")
        updateWorkItem?.cancel()
        updateWorkItem = nil
        self.interfaceController = nil
        homeTemplate = nil
        exploreTemplate = nil
        libraryTemplate = nil
        searchTabTemplate = nil
        CPNowPlayingTemplate.shared.remove(self)
        StationsManager.shared.removeObserver(self)
        NotificationCenter.default.removeObserver(self, name: .stationStoreDidChange, object: nil)
    }
}

// MARK: - Now Playing Template Setup

private extension CarPlaySceneDelegate {
    func configureNowPlayingTemplate() {
        let nowPlaying = CPNowPlayingTemplate.shared
        nowPlaying.add(self)
        nowPlaying.isUpNextButtonEnabled = true
        nowPlaying.upNextTitle = "Stations"
        nowPlaying.isAlbumArtistButtonEnabled = true

        let stationInfo = CPNowPlayingMoreButton { [weak self] _ in
            self?.pushCurrentStationInfo()
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

// MARK: - CPNowPlayingTemplateObserver

extension CarPlaySceneDelegate: CPNowPlayingTemplateObserver {
    func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        let stations = StationsManager.shared.stations
        guard !stations.isEmpty else { return }
        let template = CPListTemplate(title: "Stations", sections: [
            CPListSection(items: stations.prefix(40).map(makeStationItem(_:)), header: "up next", sectionIndexTitle: nil)
        ])
        interfaceController?.pushTemplate(template, animated: true, completion: nil)
    }

    func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate) {
        pushCurrentStationInfo()
    }
}

// MARK: - StationsManagerObserver

extension CarPlaySceneDelegate: StationsManagerObserver {

    func stationsManager(_ manager: StationsManager, stationsDidUpdate stations: [RadioStation]) {
        print("Stations updated: \(stations.count) stations")
        scheduleUpdate()
    }

    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?) {
        if let station { print("Station changed to: \(station.name)") }
        scheduleUpdate()
    }
}

// MARK: - Helpers

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
