//
//  NetworkService.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2025-01-31.
//  Copyright © 2025 matthewfecher.com. All rights reserved.
//

import UIKit

// MARK: - Error

enum NetworkError: Error {
    case urlNotValid, dataNotValid, dataNotFound, fileNotFound, httpResponseNotValid, noRadioBrowserServerAvailable
}

// MARK: - Radio Browser Models

private struct RadioBrowserServer: Decodable {
    let name: String
}

private struct RadioBrowserStats: Decodable {
    let stations: Int
    let stationsBroken: Int

    enum CodingKeys: String, CodingKey {
        case stations
        case stationsBroken = "stations_broken"
    }
}

private struct RadioBrowserStation: Decodable {
    let stationuuid: String
    let name: String
    let url: String
    let urlResolved: String
    let homepage: String
    let favicon: String
    let tags: String
    let country: String
    let countrycode: String
    let state: String
    let language: String

    enum CodingKeys: String, CodingKey {
        case stationuuid
        case name
        case url
        case urlResolved = "url_resolved"
        case homepage
        case favicon
        case tags
        case country
        case countrycode
        case state
        case language
    }
}

private struct BackendStationsResponse: Decodable {
    let stations: [BackendStation]
    let nextOffset: Int?
}

private struct BackendStation: Decodable {
    let name: String
    let website: String?
    let streamURL: String
    let imageURL: String
    let desc: String
    let longDesc: String
}

private extension RadioBrowserStation {
    var radioStation: RadioStation? {
        let streamURL = urlResolved.isEmpty ? url : urlResolved
        guard !name.isEmpty, URL(string: streamURL) != nil else { return nil }

        let subtitleParts = [
            country,
            state,
            language
        ].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        let description = subtitleParts.isEmpty ? "Radio Browser" : subtitleParts.joined(separator: " - ")
        let tagList = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(8)
            .joined(separator: ", ")

        return RadioStation(
            name: name,
            website: homepage.isEmpty ? nil : homepage,
            streamURL: streamURL,
            imageURL: favicon,
            desc: description,
            longDesc: tagList.isEmpty ? description : tagList
        )
    }
}

private extension BackendStation {
    var radioStation: RadioStation? {
        guard !name.isEmpty, URL(string: streamURL) != nil else { return nil }
        return RadioStation(
            name: name,
            website: website,
            streamURL: streamURL,
            imageURL: imageURL,
            desc: desc,
            longDesc: longDesc
        )
    }
}

// MARK: - Explore Metadata Models

struct ExploreMetadataItem: Decodable {
    let name: String
    let stationcount: Int
}

// MARK: - NetworkService

struct Contributor: Decodable {
    let login: String
    let avatarURL: URL
    let htmlURL: URL
    let contributions: Int

    enum CodingKeys: String, CodingKey {
        case login
        case avatarURL = "avatar_url"
        case htmlURL = "html_url"
        case contributions
    }
}

struct GitHubRepo: Decodable {
    let name: String
    let description: String?
}

// MARK: - NetworkService

struct NetworkService {

    // MARK: - Stations

    static func fetchStations(limit: Int = Config.backendStationLimit, offset: Int = 0) async throws -> [RadioStation] {
        switch Config.stationsSource {
        case .bundledJSON, .remoteJSON:
            return try await fetchSwiftRadioStations()
        case .radioBrowser:
            return try await fetchRadioBrowserStations(limit: limit, offset: offset)
        case .backend:
            return try await fetchBackendStations(limit: limit, offset: offset)
        }
    }

    static func searchStations(
        query: String? = nil,
        filter: String? = nil,
        limit: Int = Config.backendStationLimit,
        offset: Int = 0
    ) async throws -> [RadioStation] {
        if Config.backendBaseURL != nil {
            return try await fetchBackendStations(query: query, filter: filter, limit: limit, offset: offset)
        }

        return try await fetchRadioBrowserStations(query: query, filter: filter, limit: limit, offset: offset)
    }

    private static func fetchSwiftRadioStations() async throws -> [RadioStation] {
        let data: Data

        if Config.useLocalStations {
            guard let fileURL = Bundle.main.url(forResource: "stations", withExtension: "json") else {
                if Config.debugLog { print("The local JSON file could not be found") }
                throw NetworkError.fileNotFound
            }
            data = try Data(contentsOf: fileURL, options: .uncached)
        } else {
            guard let url = URL(string: Config.stationsURL) else {
                if Config.debugLog { print("stationsURL not a valid URL") }
                throw NetworkError.urlNotValid
            }

            let config = URLSessionConfiguration.default
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: config)

            let (responseData, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
                if Config.debugLog { print("API: HTTP status code has unexpected value") }
                throw NetworkError.httpResponseNotValid
            }

            data = responseData
        }

        if Config.debugLog { print("Stations JSON Found") }

        let jsonDictionary = try JSONDecoder().decode([String: [RadioStation]].self, from: data)

        guard let stations = jsonDictionary["station"] else {
            throw NetworkError.dataNotValid
        }

        return stations
    }

    private static func fetchBackendStations(
        query: String? = nil,
        filter: String? = nil,
        limit: Int = Config.backendStationLimit,
        offset: Int = 0
    ) async throws -> [RadioStation] {
        guard let baseURLString = Config.backendBaseURL,
              let baseURL = URL(string: baseURLString) else {
            throw NetworkError.urlNotValid
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("api/stations"), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "order", value: "votes"),
            URLQueryItem(name: "reverse", value: "true")
        ]

        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = backendFilterKey(for: filter)
            queryItems.append(URLQueryItem(name: key, value: query))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.urlNotValid
        }

        let response: BackendStationsResponse = try await fetchJSON(url: url)
        return response.stations.compactMap(\.radioStation)
    }

    private static func fetchRadioBrowserStations(
        query: String? = nil,
        filter: String? = nil,
        limit: Int? = Config.radioBrowserStationLimit,
        offset: Int = 0
    ) async throws -> [RadioStation] {
        let baseURL = try await resolveRadioBrowserBaseURL()

        if Config.debugLog, let stats = try? await fetchRadioBrowserStats(baseURL: baseURL) {
            let usableStations = stats.stations - stats.stationsBroken
            print("Radio Browser stations available: \(stats.stations) total, \(usableStations) usable, \(stats.stationsBroken) broken")
        }

        var components = URLComponents(url: baseURL.appendingPathComponent("json/stations/search"), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "hidebroken", value: Config.radioBrowserHideBroken ? "true" : "false"),
            URLQueryItem(name: "offset", value: "\(offset)"),
            URLQueryItem(name: "order", value: "clickcount"),
            URLQueryItem(name: "reverse", value: "true")
        ]

        if let limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }

        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let key = backendFilterKey(for: filter)
            queryItems.append(URLQueryItem(name: key, value: query))
        }

        if let countryCode = Config.radioBrowserCountryCode, !countryCode.isEmpty {
            queryItems.append(URLQueryItem(name: "countrycode", value: countryCode.uppercased()))
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.urlNotValid
        }

        let stations: [RadioBrowserStation] = try await fetchJSON(url: url)
        let mappedStations = stations.compactMap(\.radioStation)

        if Config.debugLog {
            print("Radio Browser stations loaded into app: \(mappedStations.count)")
        }

        guard !mappedStations.isEmpty else {
            throw NetworkError.dataNotFound
        }

        return mappedStations
    }

    private static func fetchRadioBrowserStats(baseURL: URL) async throws -> RadioBrowserStats {
        try await fetchJSON(url: baseURL.appendingPathComponent("json/stats"))
    }

    private static func resolveRadioBrowserBaseURL() async throws -> URL {
        guard let serversURL = URL(string: "https://all.api.radio-browser.info/json/servers") else {
            throw NetworkError.urlNotValid
        }

        do {
            let servers: [RadioBrowserServer] = try await fetchJSON(url: serversURL)
            guard let server = servers.first, let url = URL(string: "https://\(server.name)") else {
                throw NetworkError.noRadioBrowserServerAvailable
            }
            return url
        } catch {
            guard let fallbackURL = URL(string: "https://de1.api.radio-browser.info") else {
                throw NetworkError.urlNotValid
            }
            if Config.debugLog { print("Radio Browser server resolver failed, using fallback: \(error)") }
            return fallbackURL
        }
    }

    private static func fetchJSON<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(Config.radioBrowserAppName, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpResponseNotValid
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func backendFilterKey(for filter: String?) -> String {
        switch filter?.lowercased() {
        case "countries", "country":
            return "country"
        case "language", "languages":
            return "language"
        case "genres", "genre", "tag", "tags":
            return "tag"
        default:
            return "search"
        }
    }

    // MARK: - Explore Metadata

    static func fetchTags(limit: Int = 20) async throws -> [ExploreMetadataItem] {
        guard let baseURLString = Config.backendBaseURL,
              let baseURL = URL(string: baseURLString) else { throw NetworkError.urlNotValid }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/tags"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = components?.url else { throw NetworkError.urlNotValid }
        let response: [String: [ExploreMetadataItem]] = try await fetchJSON(url: url)
        return response["tags"] ?? []
    }

    static func fetchCountries(limit: Int = 20) async throws -> [ExploreMetadataItem] {
        guard let baseURLString = Config.backendBaseURL,
              let baseURL = URL(string: baseURLString) else { throw NetworkError.urlNotValid }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/countries"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = components?.url else { throw NetworkError.urlNotValid }
        let response: [String: [ExploreMetadataItem]] = try await fetchJSON(url: url)
        return response["countries"] ?? []
    }

    // MARK: - Images

    static func fetchImage(from url: URL) async -> UIImage? {
        let cache = URLCache.shared
        let request = URLRequest(url: url)

        if let data = cache.cachedResponse(for: request)?.data, let image = UIImage(data: data) {
            return image
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode,
                  let image = UIImage(data: data) else {
                return nil
            }

            let cachedData = CachedURLResponse(response: httpResponse, data: data)
            cache.storeCachedResponse(cachedData, for: request)
            return image
        } catch {
            return nil
        }
    }

    // MARK: - GitHub API

    static func fetchContributors(owner: String, repo: String) async throws -> [Contributor] {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contributors") else {
            throw NetworkError.urlNotValid
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpResponseNotValid
        }

        return try JSONDecoder().decode([Contributor].self, from: data)
    }

    static func fetchRepository(owner: String, repo: String) async throws -> GitHubRepo {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)") else {
            throw NetworkError.urlNotValid
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw NetworkError.httpResponseNotValid
        }

        return try JSONDecoder().decode(GitHubRepo.self, from: data)
    }
}
