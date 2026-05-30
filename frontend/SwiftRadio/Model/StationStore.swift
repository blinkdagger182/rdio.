import Foundation

final class StationStore {
    static let shared = StationStore()

    private let favoritesKey = "rdio.favorites.v1"
    private let historyKey = "rdio.history.v1"
    private let maxHistory = 50

    private(set) var favorites: [RadioStation] = []
    private(set) var recentlyPlayed: [RadioStation] = []

    private init() {
        favorites = load(key: favoritesKey)
        recentlyPlayed = load(key: historyKey)
    }

    func toggleFavorite(_ station: RadioStation) {
        if let idx = favorites.firstIndex(of: station) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(station, at: 0)
        }
        save(favorites, key: favoritesKey)
        notify()
    }

    func isFavorite(_ station: RadioStation) -> Bool {
        favorites.contains(station)
    }

    func recordPlay(_ station: RadioStation) {
        recentlyPlayed.removeAll { $0 == station }
        recentlyPlayed.insert(station, at: 0)
        if recentlyPlayed.count > maxHistory {
            recentlyPlayed = Array(recentlyPlayed.prefix(maxHistory))
        }
        save(recentlyPlayed, key: historyKey)
        notify()
    }

    private func save(_ stations: [RadioStation], key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(stations), forKey: key)
    }

    private func load(key: String) -> [RadioStation] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RadioStation].self, from: data)) ?? []
    }

    private func notify() {
        NotificationCenter.default.post(name: .stationStoreDidChange, object: nil)
    }
}

extension Notification.Name {
    static let stationStoreDidChange = Notification.Name("rdio.stationStoreDidChange")
}
