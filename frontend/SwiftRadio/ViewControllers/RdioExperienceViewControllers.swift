//
//  RdioExperienceViewControllers.swift
//  SwiftRadio
//
//  Created by Codex on 2026-05-29.
//

import UIKit
import AVKit
import FRadioPlayer

protocol RdioExperienceDelegate: AnyObject {
    func rdioDidSelectStation(_ station: RadioStation, from controller: UIViewController)
    func rdioDidRequestNowPlaying(from controller: UIViewController)
    func rdioDidRequestPlaybackOptions(from controller: UIViewController)
    func rdioDidRequestAbout(from controller: UIViewController)
}

enum RdioDesign {
    static let horizontalInset: CGFloat = 24
    static let cardColor = Config.elevatedBackgroundColor.withAlphaComponent(0.78)
    static let borderColor = UIColor.white.withAlphaComponent(0.1)

    static func title(_ text: String, size: CGFloat = 34) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: .bold)
        label.textColor = Config.primaryTextColor
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    static func section(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = Config.secondaryTextColor
        return label
    }

    static func secondary(_ text: String, size: CGFloat = 17, weight: UIFont.Weight = .regular) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = Config.secondaryTextColor
        label.numberOfLines = 1
        return label
    }

    static func iconButton(_ name: String, pointSize: CGFloat = 24) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        button.setImage(UIImage(systemName: name, withConfiguration: config), for: .normal)
        button.tintColor = Config.secondaryTextColor
        return button
    }

    static func applyCardStyle(_ view: UIView, radius: CGFloat = 18) {
        view.backgroundColor = cardColor
        view.layer.cornerRadius = radius
        view.layer.borderWidth = 1
        view.layer.borderColor = borderColor.cgColor
        view.clipsToBounds = true
    }
}

final class RdioTabBarController: UITabBarController {
    private let customBar = UIStackView()
    private var customButtons: [UIButton] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Config.backgroundColor
        if #available(iOS 18.0, *) {
            mode = .tabBar
        }
        if #available(iOS 26.0, *) {
            tabBarMinimizeBehavior = .never
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Config.backgroundColor.withAlphaComponent(0.96)
        appearance.shadowColor = UIColor.white.withAlphaComponent(0.08)
        appearance.stackedLayoutAppearance.normal.iconColor = Config.tertiaryTextColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: Config.tertiaryTextColor]
        appearance.stackedLayoutAppearance.selected.iconColor = Config.tintColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: Config.tintColor]
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = Config.tintColor
        tabBar.unselectedItemTintColor = Config.tertiaryTextColor
        tabBar.isHidden = true
        buildCustomBar()
        updateCustomSelection()
    }

    override var selectedIndex: Int {
        didSet { updateCustomSelection() }
    }

    private func buildCustomBar() {
        let background = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        background.layer.cornerRadius = 24
        background.layer.borderWidth = 1
        background.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        background.clipsToBounds = true
        background.translatesAutoresizingMaskIntoConstraints = false

        customBar.axis = .horizontal
        customBar.distribution = .fillEqually
        customBar.alignment = .center
        customBar.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(background)
        background.contentView.addSubview(customBar)

        let items = [
            ("home", "house"),
            ("explore", "safari"),
            ("library", "rectangle.stack"),
            ("search", "magnifyingglass")
        ]

        customButtons = items.enumerated().map { index, item in
            var config = UIButton.Configuration.plain()
            config.image = UIImage(systemName: item.1)
            config.title = item.0
            config.imagePlacement = .top
            config.imagePadding = 4
            config.baseForegroundColor = Config.tertiaryTextColor
            let button = UIButton(configuration: config)
            button.tag = index
            button.addTarget(self, action: #selector(tabPressed(_:)), for: .touchUpInside)
            customBar.addArrangedSubview(button)
            return button
        }

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            background.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            background.heightAnchor.constraint(equalToConstant: 66),
            customBar.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            customBar.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            customBar.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            customBar.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor)
        ])
    }

    private func updateCustomSelection() {
        for button in customButtons {
            var config = button.configuration
            let selected = button.tag == selectedIndex
            config?.baseForegroundColor = selected ? Config.tintColor : Config.tertiaryTextColor
            button.configuration = config
        }
    }

    @objc private func tabPressed(_ sender: UIButton) {
        selectedIndex = sender.tag
    }
}

class RdioBaseViewController: BaseController {
    weak var experienceDelegate: RdioExperienceDelegate?
    let manager = StationsManager.shared
    let player = FRadioPlayer.shared

    let scrollView = UIScrollView()
    let contentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Config.backgroundColor
        manager.addObserver(self)
        player.addObserver(self)
    }

    deinit {
        manager.removeObserver(self)
        player.removeObserver(self)
    }

    override func setupViews() {
        super.setupViews()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 104, right: 0)
        scrollView.verticalScrollIndicatorInsets.bottom = 104

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: RdioDesign.horizontalInset),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -RdioDesign.horizontalInset),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    var stations: [RadioStation] {
        if !manager.stations.isEmpty { return manager.stations }
        return RdioFixtures.stations
    }

    func reloadContent() {}
}

extension RdioBaseViewController: StationsManagerObserver, FRadioPlayerObserver {
    func stationsManager(_ manager: StationsManager, stationsDidUpdate stations: [RadioStation]) {
        reloadContent()
    }

    func stationsManager(_ manager: StationsManager, stationDidChange station: RadioStation?) {
        reloadContent()
    }

    func radioPlayer(_ player: FRadioPlayer, playbackStateDidChange state: FRadioPlayer.PlaybackState) {
        reloadContent()
    }
}

final class RdioHomeViewController: RdioBaseViewController {
    private let nowTitle = UILabel()
    private let nowSubtitle = UILabel()
    private let featuredStack = UIStackView()
    private let recentStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarItem = UITabBarItem(title: "home", image: UIImage(systemName: "house"), selectedImage: UIImage(systemName: "house.fill"))
        build()
        reloadContent()
    }

    private func build() {
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .top
        header.distribution = .equalSpacing

        let logo = RdioDesign.title("rdio.", size: 34)
        let buttons = UIStackView()
        buttons.spacing = 18
        let route = RdioDesign.iconButton("airplayaudio")
        let settings = RdioDesign.iconButton("gearshape")
        settings.addTarget(self, action: #selector(playbackOptions), for: .touchUpInside)
        buttons.addArrangedSubview(route)
        buttons.addArrangedSubview(settings)
        header.addArrangedSubview(logo)
        header.addArrangedSubview(buttons)
        contentStack.addArrangedSubview(header)

        let nowStack = UIStackView()
        nowStack.axis = .vertical
        nowStack.spacing = 8
        nowStack.addArrangedSubview(RdioDesign.secondary("now playing", size: 18, weight: .medium))
        nowTitle.font = .systemFont(ofSize: 34, weight: .bold)
        nowTitle.textColor = Config.primaryTextColor
        nowSubtitle.font = .systemFont(ofSize: 20, weight: .regular)
        nowSubtitle.textColor = Config.secondaryTextColor
        nowStack.addArrangedSubview(nowTitle)
        nowStack.addArrangedSubview(nowSubtitle)
        let waveform = RdioWaveformView()
        waveform.backgroundColor = .clear
        waveform.isOpaque = false
        waveform.translatesAutoresizingMaskIntoConstraints = false
        waveform.heightAnchor.constraint(equalToConstant: 56).isActive = true
        nowStack.addArrangedSubview(waveform)

        let transport = UIStackView()
        transport.axis = .horizontal
        transport.alignment = .center
        transport.distribution = .equalSpacing
        transport.addArrangedSubview(RdioDesign.secondary("AAC 128 kbps", size: 16, weight: .medium))
        let play = UIButton(type: .system)
        play.setImage(UIImage(systemName: "play.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 25, weight: .bold)), for: .normal)
        play.tintColor = Config.backgroundColor
        play.backgroundColor = Config.primaryTextColor
        play.layer.cornerRadius = 38
        play.translatesAutoresizingMaskIntoConstraints = false
        play.widthAnchor.constraint(equalToConstant: 76).isActive = true
        play.heightAnchor.constraint(equalToConstant: 76).isActive = true
        play.addTarget(self, action: #selector(nowPlaying), for: .touchUpInside)
        transport.addArrangedSubview(play)
        transport.addArrangedSubview(RdioDesign.secondary("LIVE  ▥", size: 16, weight: .bold))
        nowStack.addArrangedSubview(transport)
        contentStack.addArrangedSubview(nowStack)
        contentStack.setCustomSpacing(22, after: nowStack)

        contentStack.addArrangedSubview(sectionHeader("featured stations"))
        featuredStack.axis = .horizontal
        featuredStack.spacing = 14
        featuredStack.distribution = .fillEqually
        contentStack.addArrangedSubview(featuredStack)

        contentStack.addArrangedSubview(RdioDesign.section("categories"))
        let categories = UIStackView()
        categories.axis = .horizontal
        categories.spacing = 14
        categories.distribution = .fillEqually
        [("music", "music.note"), ("news", "mic"), ("talk", "bubble.left"), ("culture", "building.columns")].forEach {
            categories.addArrangedSubview(categoryTile(title: $0.0, icon: $0.1))
        }
        contentStack.addArrangedSubview(categories)

        contentStack.addArrangedSubview(sectionHeader("recently played"))
        recentStack.axis = .vertical
        recentStack.spacing = 12
        contentStack.addArrangedSubview(recentStack)
    }

    override func reloadContent() {
        let station = manager.currentStation ?? stations.first ?? RdioFixtures.stations[0]
        nowTitle.text = station.name
        nowSubtitle.text = station.desc

        featuredStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        Array(stations.prefix(4)).enumerated().forEach { index, station in
            featuredStack.addArrangedSubview(featuredTile(station: station, highlighted: index == 2))
        }

        recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        recentStack.addArrangedSubview(stationRow(station: Array(stations.dropFirst()).first ?? station, compact: false))
    }

    private func sectionHeader(_ title: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.addArrangedSubview(RdioDesign.section(title))
        stack.addArrangedSubview(RdioDesign.secondary("See All", size: 18, weight: .semibold))
        return stack
    }

    private func featuredTile(station: RadioStation, highlighted: Bool) -> UIView {
        let button = UIButton(type: .system)
        RdioDesign.applyCardStyle(button, radius: 16)
        button.layer.borderColor = (highlighted ? Config.tintColor : RdioDesign.borderColor).cgColor
        button.layer.borderWidth = highlighted ? 2 : 1
        button.heightAnchor.constraint(equalToConstant: 78).isActive = true
        var config = UIButton.Configuration.plain()
        config.title = shortName(station.name)
        config.subtitle = station.desc.components(separatedBy: " ").first
        config.baseForegroundColor = Config.primaryTextColor
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 20, weight: .bold)
            return outgoing
        }
        button.configuration = config
        button.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.experienceDelegate?.rdioDidSelectStation(station, from: self)
        }, for: .touchUpInside)
        return button
    }

    private func categoryTile(title: String, icon: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        let box = UIView()
        RdioDesign.applyCardStyle(box, radius: 16)
        box.translatesAutoresizingMaskIntoConstraints = false
        box.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let imageView = UIImageView(image: UIImage(systemName: icon))
        imageView.tintColor = Config.secondaryTextColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: box.centerYAnchor),
            imageView.heightAnchor.constraint(equalToConstant: 24),
            imageView.widthAnchor.constraint(equalToConstant: 28)
        ])
        stack.addArrangedSubview(box)
        stack.addArrangedSubview(RdioDesign.secondary(title, size: 16))
        return stack
    }

    private func stationRow(station: RadioStation, compact: Bool) -> UIView {
        RdioStationRow(station: station, showsHeart: false) { [weak self] in
            guard let self else { return }
            self.experienceDelegate?.rdioDidSelectStation(station, from: self)
        }
    }

    @objc private func nowPlaying() {
        experienceDelegate?.rdioDidRequestNowPlaying(from: self)
    }

    @objc private func playbackOptions() {
        experienceDelegate?.rdioDidRequestPlaybackOptions(from: self)
    }

    private func shortName(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count <= 2 { return name }
        return words.prefix(2).joined(separator: "\n")
    }
}

final class RdioExploreViewController: RdioBaseViewController {
    private let cities = [("Tokyo", "96 stations"), ("London", "112 stations"), ("New York", "128 stations"), ("Kuala Lumpur", "64 stations"), ("Paris", "78 stations")]

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarItem = UITabBarItem(title: "explore", image: UIImage(systemName: "safari"), selectedImage: UIImage(systemName: "safari.fill"))
        build()
    }

    private func build() {
        let header = UIStackView()
        header.axis = .horizontal
        header.distribution = .equalSpacing
        header.addArrangedSubview(RdioDesign.title("explore"))
        header.addArrangedSubview(RdioDesign.iconButton("bell"))
        contentStack.addArrangedSubview(header)

        let tabs = UIStackView()
        tabs.axis = .horizontal
        tabs.distribution = .fillEqually
        ["for you", "genres", "countries", "cities"].forEach { title in
            let label = RdioDesign.secondary(title, size: 19, weight: title == "cities" ? .bold : .semibold)
            label.textColor = title == "cities" ? Config.primaryTextColor : Config.tertiaryTextColor
            tabs.addArrangedSubview(label)
        }
        contentStack.addArrangedSubview(tabs)
        contentStack.addArrangedSubview(RdioHomeViewControllerSectionLabel(title: "popular cities"))

        cities.enumerated().forEach { index, city in
            contentStack.addArrangedSubview(cityCard(name: city.0, count: city.1, index: index))
        }

        let station = manager.currentStation ?? stations.first ?? RdioFixtures.stations[0]
        let mini = RdioMiniPlayerView(station: station) { [weak self] in
            guard let self else { return }
            self.experienceDelegate?.rdioDidRequestNowPlaying(from: self)
        }
        contentStack.addArrangedSubview(mini)
    }

    private func cityCard(name: String, count: String, index: Int) -> UIView {
        let view = UIView()
        let colors = [
            UIColor(red: 0.18, green: 0.12, blue: 0.25, alpha: 1),
            UIColor(red: 0.10, green: 0.16, blue: 0.20, alpha: 1),
            UIColor(red: 0.18, green: 0.13, blue: 0.09, alpha: 1),
            UIColor(red: 0.08, green: 0.18, blue: 0.15, alpha: 1),
            UIColor(red: 0.18, green: 0.10, blue: 0.14, alpha: 1)
        ]
        view.backgroundColor = colors[index % colors.count]
        view.layer.cornerRadius = 18
        view.clipsToBounds = true
        view.heightAnchor.constraint(equalToConstant: 84).isActive = true

        let title = RdioDesign.title(name, size: 23)
        let subtitle = RdioDesign.secondary(count, size: 17)
        let bars = RdioCityBarsView()
        bars.backgroundColor = .clear
        bars.isOpaque = false
        [title, subtitle, bars].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            title.topAnchor.constraint(equalTo: view.topAnchor, constant: 18),
            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            bars.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            bars.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bars.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.58),
            bars.heightAnchor.constraint(equalToConstant: 62)
        ])
        return view
    }
}

final class RdioLibraryViewController: RdioBaseViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarItem = UITabBarItem(title: "library", image: UIImage(systemName: "rectangle.stack"), selectedImage: UIImage(systemName: "rectangle.stack.fill"))
        build()
    }

    private func build() {
        let header = UIStackView()
        header.axis = .horizontal
        header.distribution = .equalSpacing
        header.addArrangedSubview(RdioDesign.title("library"))
        header.addArrangedSubview(RdioDesign.iconButton("bell"))
        contentStack.addArrangedSubview(header)

        let tabs = UIStackView()
        tabs.axis = .horizontal
        tabs.distribution = .fillEqually
        ["favorites", "collections", "history"].forEach { title in
            let label = RdioDesign.secondary(title, size: 20, weight: title == "favorites" ? .bold : .semibold)
            label.textColor = title == "favorites" ? Config.primaryTextColor : Config.tertiaryTextColor
            tabs.addArrangedSubview(label)
        }
        contentStack.addArrangedSubview(tabs)

        [("Favorite Stations", "15 stations", "heart"), ("Morning Drive", "6 stations", "sun.max"), ("Focus Mode", "8 stations", "target"), ("Global News", "10 stations", "globe")].forEach {
            contentStack.addArrangedSubview(collectionRow(title: $0.0, subtitle: $0.1, icon: $0.2))
        }

        let divider = UIView()
        divider.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        contentStack.addArrangedSubview(divider)

        Array(stations.prefix(3)).forEach { station in
            contentStack.addArrangedSubview(RdioStationRow(station: station, showsHeart: true) { [weak self] in
                guard let self else { return }
                self.experienceDelegate?.rdioDidSelectStation(station, from: self)
            })
        }
    }

    private func collectionRow(title: String, subtitle: String, icon: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 18
        row.alignment = .center

        let iconBox = UIView()
        RdioDesign.applyCardStyle(iconBox, radius: 14)
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        iconBox.widthAnchor.constraint(equalToConstant: 58).isActive = true
        iconBox.heightAnchor.constraint(equalToConstant: 58).isActive = true
        let image = UIImageView(image: UIImage(systemName: icon))
        image.tintColor = Config.secondaryTextColor
        image.translatesAutoresizingMaskIntoConstraints = false
        iconBox.addSubview(image)
        NSLayoutConstraint.activate([
            image.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor)
        ])

        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 3
        labels.addArrangedSubview(RdioDesign.title(title, size: 23))
        labels.addArrangedSubview(RdioDesign.secondary(subtitle, size: 17))
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = Config.tertiaryTextColor
        row.addArrangedSubview(iconBox)
        row.addArrangedSubview(labels)
        row.addArrangedSubview(chevron)
        return row
    }
}

final class RdioSearchViewController: RdioBaseViewController {
    private let searchField = UITextField()
    private let resultsStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarItem = UITabBarItem(title: "search", image: UIImage(systemName: "magnifyingglass"), selectedImage: UIImage(systemName: "magnifyingglass"))
        build()
        reloadContent()
    }

    private func build() {
        let searchRow = UIStackView()
        searchRow.axis = .horizontal
        searchRow.spacing = 16
        searchRow.alignment = .center
        searchField.text = "jazz"
        searchField.textColor = Config.primaryTextColor
        searchField.font = .systemFont(ofSize: 20, weight: .regular)
        searchField.backgroundColor = Config.elevatedBackgroundColor
        searchField.layer.cornerRadius = 18
        searchField.leftView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchField.leftViewMode = .always
        searchField.heightAnchor.constraint(equalToConstant: 56).isActive = true
        let cancel = RdioDesign.secondary("Cancel", size: 18, weight: .semibold)
        searchRow.addArrangedSubview(searchField)
        searchRow.addArrangedSubview(cancel)
        contentStack.addArrangedSubview(searchRow)

        let filters = UIStackView()
        filters.axis = .horizontal
        filters.spacing = 10
        ["All", "Stations", "Shows", "Episodes"].forEach { title in
            filters.addArrangedSubview(filterChip(title, selected: title == "All"))
        }
        contentStack.addArrangedSubview(filters)
        contentStack.addArrangedSubview(RdioHomeViewControllerSectionLabel(title: "stations"))
        resultsStack.axis = .vertical
        resultsStack.spacing = 18
        contentStack.addArrangedSubview(resultsStack)
        contentStack.addArrangedSubview(RdioHomeViewControllerSectionLabel(title: "shows & episodes"))
        [("Jazz Profiles", "The stories behind the sound"), ("Live at Blue Note", "Recorded sessions")].forEach {
            contentStack.addArrangedSubview(showRow(title: $0.0, subtitle: $0.1))
        }
    }

    override func reloadContent() {
        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let jazzStations = stations.filter { $0.name.localizedCaseInsensitiveContains("jazz") || $0.desc.localizedCaseInsensitiveContains("jazz") }
        let items = jazzStations.isEmpty ? RdioFixtures.stations : Array(jazzStations.prefix(4))
        items.forEach { station in
            resultsStack.addArrangedSubview(RdioStationRow(station: station, showsHeart: false) { [weak self] in
                guard let self else { return }
                self.experienceDelegate?.rdioDidSelectStation(station, from: self)
            })
        }
    }

    private func filterChip(_ title: String, selected: Bool) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .center
        label.textColor = selected ? Config.backgroundColor : Config.secondaryTextColor
        label.backgroundColor = selected ? Config.primaryTextColor : .clear
        label.layer.borderWidth = 1
        label.layer.borderColor = RdioDesign.borderColor.cgColor
        label.layer.cornerRadius = 18
        label.clipsToBounds = true
        label.heightAnchor.constraint(equalToConstant: 42).isActive = true
        label.widthAnchor.constraint(greaterThanOrEqualToConstant: selected ? 64 : 90).isActive = true
        return label
    }

    private func showRow(title: String, subtitle: String) -> UIView {
        let station = RadioStation(name: title, streamURL: "", imageURL: "", desc: subtitle)
        return RdioStationRow(station: station, showsChevron: true, showsHeart: false, action: {})
    }
}

final class RdioPlaybackOptionsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Config.backgroundColor
        if let sheet = sheetPresentationController {
            sheet.prefersGrabberVisible = true
            sheet.detents = [.large()]
            sheet.preferredCornerRadius = 28
        }
        build()
    }

    private func build() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52)
        ])
        stack.addArrangedSubview(RdioDesign.title("playback options", size: 28))
        stack.addArrangedSubview(RdioDesign.secondary("sleep timer", size: 19))
        ["Off", "15 minutes", "30 minutes", "45 minutes", "60 minutes"].forEach {
            stack.addArrangedSubview(optionRow(title: $0, icon: nil, selected: $0 == "Off"))
        }
        stack.addArrangedSubview(RdioDesign.secondary("play on", size: 19))
        stack.addArrangedSubview(optionRow(title: "iPhone", icon: "iphone", selected: false))
        stack.addArrangedSubview(optionRow(title: "CarPlay", icon: "car", selected: true))

        let close = UIButton(type: .system)
        close.setTitle("Close", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        close.tintColor = Config.primaryTextColor
        RdioDesign.applyCardStyle(close, radius: 16)
        close.heightAnchor.constraint(equalToConstant: 62).isActive = true
        close.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        stack.addArrangedSubview(close)
    }

    private func optionRow(title: String, icon: String?, selected: Bool) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 18
        row.heightAnchor.constraint(equalToConstant: 54).isActive = true
        if let icon {
            let image = UIImageView(image: UIImage(systemName: icon))
            image.tintColor = Config.secondaryTextColor
            image.widthAnchor.constraint(equalToConstant: 30).isActive = true
            row.addArrangedSubview(image)
        }
        let label = RdioDesign.title(title, size: 24)
        row.addArrangedSubview(label)
        let spacer = UIView()
        row.addArrangedSubview(spacer)
        if selected {
            let check = UIImageView(image: UIImage(systemName: "checkmark"))
            check.tintColor = Config.tintColor
            row.addArrangedSubview(check)
        }
        return row
    }

    @objc private func closePressed() {
        dismiss(animated: true)
    }
}

final class RdioStationRow: UIControl {
    private let station: RadioStation
    private let action: () -> Void

    init(station: RadioStation, showsChevron: Bool = false, showsHeart: Bool = false, action: @escaping () -> Void) {
        self.station = station
        self.action = action
        super.init(frame: .zero)
        build(showsChevron: showsChevron, showsHeart: showsHeart)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(showsChevron: Bool, showsHeart: Bool) {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let art = UIImageView()
        art.backgroundColor = Config.secondaryBackgroundColor
        art.contentMode = .scaleAspectFill
        art.clipsToBounds = true
        art.layer.cornerRadius = 14
        art.translatesAutoresizingMaskIntoConstraints = false
        art.widthAnchor.constraint(equalToConstant: 64).isActive = true
        art.heightAnchor.constraint(equalToConstant: 64).isActive = true
        station.getImage { image in art.image = image }

        let labels = UIStackView()
        labels.axis = .vertical
        labels.spacing = 4
        labels.addArrangedSubview(RdioDesign.title(station.name, size: 21))
        labels.addArrangedSubview(RdioDesign.secondary(station.desc, size: 17))

        stack.addArrangedSubview(art)
        stack.addArrangedSubview(labels)
        let spacer = UIView()
        stack.addArrangedSubview(spacer)

        let symbol = showsChevron ? "chevron.right" : (showsHeart ? "heart.fill" : "play.fill")
        let image = UIImageView(image: UIImage(systemName: symbol))
        image.tintColor = showsHeart ? Config.tintColor : Config.primaryTextColor
        if !showsChevron && !showsHeart {
            let circle = UIView()
            circle.backgroundColor = UIColor.white.withAlphaComponent(0.1)
            circle.layer.cornerRadius = 29
            circle.translatesAutoresizingMaskIntoConstraints = false
            circle.widthAnchor.constraint(equalToConstant: 58).isActive = true
            circle.heightAnchor.constraint(equalToConstant: 58).isActive = true
            image.translatesAutoresizingMaskIntoConstraints = false
            circle.addSubview(image)
            NSLayoutConstraint.activate([
                image.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
                image.centerYAnchor.constraint(equalTo: circle.centerYAnchor)
            ])
            stack.addArrangedSubview(circle)
        } else {
            stack.addArrangedSubview(image)
        }

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    @objc private func tapped() {
        action()
    }
}

final class RdioMiniPlayerView: UIControl {
    init(station: RadioStation, action: @escaping () -> Void) {
        super.init(frame: .zero)
        RdioDesign.applyCardStyle(self, radius: 18)
        heightAnchor.constraint(equalToConstant: 86).isActive = true
        addAction(UIAction { _ in action() }, for: .touchUpInside)

        let row = RdioStationRow(station: station, showsHeart: false, action: action)
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class RdioHomeViewControllerSectionLabel: UIView {
    init(title: String) {
        super.init(frame: .zero)
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        row.addArrangedSubview(RdioDesign.section(title))
        row.addArrangedSubview(RdioDesign.secondary("See All", size: 18, weight: .semibold))
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor),
            row.leadingAnchor.constraint(equalTo: leadingAnchor),
            row.trailingAnchor.constraint(equalTo: trailingAnchor),
            row.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class RdioWaveformView: UIView {
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setLineCap(.round)
        let count = 52
        let spacing = rect.width / CGFloat(count)
        for index in 0..<count {
            let normalized = CGFloat((index * 37) % 17) / 17
            let centerBoost = 1 - min(abs(CGFloat(index) - CGFloat(count) / 2) / (CGFloat(count) / 2), 1)
            let height = 12 + (normalized * 22) + centerBoost * 14
            let x = CGFloat(index) * spacing
            let color = index > 16 && index < 33 ? Config.primaryTextColor : Config.tertiaryTextColor.withAlphaComponent(0.55)
            context?.setStrokeColor(color.cgColor)
            context?.setLineWidth(3)
            context?.move(to: CGPoint(x: x, y: rect.midY - height / 2))
            context?.addLine(to: CGPoint(x: x, y: rect.midY + height / 2))
            context?.strokePath()
        }
    }
}

final class RdioCityBarsView: UIView {
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor.black.withAlphaComponent(0.22).cgColor)
        let bars = 12
        let width = rect.width / CGFloat(bars * 2)
        for index in 0..<bars {
            let factor = CGFloat((index * 19) % 9 + 4) / 13
            let height = rect.height * factor
            let x = CGFloat(index * 2) * width
            context?.fill(CGRect(x: x, y: rect.height - height, width: width, height: height))
        }
    }
}

enum RdioFixtures {
    static let stations = [
        RadioStation(name: "Tokyo Wave", streamURL: "", imageURL: "logo", desc: "City Beats • Tokyo", longDesc: "The best of Japanese city pop, lofi, and contemporary beats."),
        RadioStation(name: "BBC Radio 1", streamURL: "", imageURL: "stationImage", desc: "UK"),
        RadioStation(name: "BFM 89.9", streamURL: "", imageURL: "stationImage", desc: "Kuala Lumpur"),
        RadioStation(name: "Jazz Nights", streamURL: "", imageURL: "stationImage", desc: "Smooth jazz 24/7"),
        RadioStation(name: "LoFi FM", streamURL: "", imageURL: "stationImage", desc: "Beats to relax")
    ]
}
