//
//  RdioExperienceViewControllers.swift
//  SwiftRadio
//
//  Created by Codex on 2026-05-29.
//

import UIKit
import AVKit
import FRadioPlayer
import LNPopupController

protocol RdioExperienceDelegate: AnyObject {
    func rdioDidSelectStation(_ station: RadioStation, from controller: UIViewController)
    func rdioDidRequestNowPlaying(from controller: UIViewController)
    func rdioDidRequestPlaybackOptions(from controller: UIViewController)
    func rdioDidRequestAbout(from controller: UIViewController)
}

enum RdioDesign {
    static let horizontalInset: CGFloat = 24
    static let maxContentWidth: CGFloat = 560
    static let maxBottomBarWidth: CGFloat = 520
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
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        return button
    }

    static func applyCardStyle(_ view: UIView, radius: CGFloat = 18) {
        view.backgroundColor = cardColor
        view.layer.cornerRadius = radius
        view.layer.borderWidth = 1
        view.layer.borderColor = borderColor.cgColor
        view.clipsToBounds = true
    }

    static func sectionHeader(title: String, action: UIAction? = nil) -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.addArrangedSubview(section(title))

        let button = UIButton(type: .system)
        button.setTitle("See All", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.tintColor = Config.secondaryTextColor
        if let action {
            button.addAction(action, for: .touchUpInside)
        }
        stack.addArrangedSubview(button)
        return stack
    }

    static func configureSelected(_ selected: Bool, button: UIButton) {
        var config = button.configuration ?? .plain()
        config.baseForegroundColor = selected ? Config.tintColor : Config.tertiaryTextColor
        button.configuration = config
    }

    static func emptyState(_ text: String) -> UILabel {
        let label = secondary(text, size: 17, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }
}

private struct RdioMetadataItem {
    let name: String
    let count: Int
}

final class RdioTabBarController: UITabBarController {
    private let customBar = UIStackView()
    private let customBarBackground = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
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

    override var bottomDockingViewForPopupBar: UIView? {
        customBarBackground
    }

    override var defaultFrameForBottomDockingView: CGRect {
        customBarBackground.frame
    }

    override var isBottomDockingViewForPopupBarHidden: Bool {
        customBarBackground.isHidden
    }

    override var bottomDockingViewMarginForPopupBar: CGFloat {
        8
    }

    override var requiresIndirectSafeAreaManagement: Bool {
        true
    }

    override var selectedIndex: Int {
        didSet { updateCustomSelection() }
    }

    private func buildCustomBar() {
        let background = customBarBackground
        background.layer.cornerRadius = 22
        background.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
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
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            background.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -66),
            background.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            customBar.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            customBar.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            customBar.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            customBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
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
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 0),
            contentStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.leadingAnchor, constant: RdioDesign.horizontalInset),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -RdioDesign.horizontalInset),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: RdioDesign.maxContentWidth),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -(RdioDesign.horizontalInset * 2)).with { $0.priority = .defaultHigh },
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])
    }

    var stations: [RadioStation] {
        manager.stations
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
    private var selectedCategory = "music"
    private var categoryButtons: [UIButton] = []

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
        route.addTarget(self, action: #selector(nowPlaying), for: .touchUpInside)
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
        play.addTarget(self, action: #selector(playPressed), for: .touchUpInside)
        transport.addArrangedSubview(play)
        transport.addArrangedSubview(RdioDesign.secondary("LIVE  ▥", size: 16, weight: .bold))
        nowStack.addArrangedSubview(transport)
        contentStack.addArrangedSubview(nowStack)
        contentStack.setCustomSpacing(22, after: nowStack)

        contentStack.addArrangedSubview(RdioDesign.sectionHeader(title: "featured stations", action: UIAction { [weak self] _ in
            self?.openSearch(query: "", filter: "Stations")
        }))
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

        contentStack.addArrangedSubview(RdioDesign.sectionHeader(title: "recently played", action: UIAction { [weak self] _ in
            self?.openSearch(query: self?.selectedCategory ?? "", filter: "Stations")
        }))
        recentStack.axis = .vertical
        recentStack.spacing = 12
        contentStack.addArrangedSubview(recentStack)
    }

    override func reloadContent() {
        guard let station = manager.currentStation ?? stations.first else {
            nowTitle.text = "Loading stations"
            nowSubtitle.text = "Connecting to Radio Browser"
            featuredStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            recentStack.addArrangedSubview(RdioDesign.emptyState("Stations are loading."))
            return
        }
        nowTitle.text = station.name
        nowSubtitle.text = station.desc

        featuredStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        Array(stations.prefix(4)).enumerated().forEach { index, station in
            featuredStack.addArrangedSubview(featuredTile(station: station, highlighted: index == 2))
        }

        recentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let filtered = filteredStations(for: selectedCategory)
        if let recent = filtered.dropFirst().first ?? filtered.first {
            recentStack.addArrangedSubview(stationRow(station: recent, compact: false))
        } else {
            recentStack.addArrangedSubview(RdioDesign.emptyState("No matching live stations."))
        }
        updateCategorySelection()
    }

    private func featuredTile(station: RadioStation, highlighted: Bool) -> UIView {
        let control = UIControl()
        RdioDesign.applyCardStyle(control, radius: 16)
        control.layer.borderColor = (highlighted ? Config.tintColor : RdioDesign.borderColor).cgColor
        control.layer.borderWidth = highlighted ? 2 : 1
        control.heightAnchor.constraint(equalToConstant: 78).isActive = true
        control.accessibilityLabel = "\(station.name), \(station.desc)"
        control.accessibilityTraits = .button
        control.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.experienceDelegate?.rdioDidSelectStation(station, from: self)
        }, for: .touchUpInside)

        let labels = UIStackView()
        labels.isUserInteractionEnabled = false
        labels.axis = .vertical
        labels.spacing = 2
        labels.translatesAutoresizingMaskIntoConstraints = false

        let title = RdioDesign.title(station.name, size: 17)
        title.numberOfLines = 2
        title.lineBreakMode = .byTruncatingTail
        title.adjustsFontSizeToFitWidth = true
        title.minimumScaleFactor = 0.72

        let subtitle = RdioDesign.secondary(station.countryName ?? station.desc, size: 12, weight: .medium)
        subtitle.lineBreakMode = .byTruncatingTail
        labels.addArrangedSubview(title)
        labels.addArrangedSubview(subtitle)
        control.addSubview(labels)

        NSLayoutConstraint.activate([
            labels.leadingAnchor.constraint(equalTo: control.leadingAnchor, constant: 12),
            labels.trailingAnchor.constraint(equalTo: control.trailingAnchor, constant: -12),
            labels.centerYAnchor.constraint(equalTo: control.centerYAnchor)
        ])

        return control
    }

    private func categoryTile(title: String, icon: String) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .center
        let box = UIButton(type: .system)
        box.accessibilityLabel = title
        box.addAction(UIAction { [weak self] _ in
            self?.selectedCategory = title
            self?.reloadContent()
            self?.openSearch(query: title, filter: "Genres")
        }, for: .touchUpInside)
        categoryButtons.append(box)
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

    private func filteredStations(for category: String) -> [RadioStation] {
        let tokens: [String]
        switch category {
        case "news": tokens = ["news", "radio", "bbc", "info", "npr"]
        case "talk": tokens = ["talk", "podcast", "voice", "public"]
        case "culture": tokens = ["culture", "classic", "world", "global"]
        default: tokens = ["music", "fm", "jazz", "lofi", "rock", "pop"]
        }
        let matches = stations.filter { station in
            tokens.contains { token in
                station.matches(token)
            }
        }
        return matches.isEmpty ? Array(stations.prefix(8)) : matches
    }

    private func updateCategorySelection() {
        for button in categoryButtons {
            let selected = button.accessibilityLabel == selectedCategory
            button.layer.borderColor = (selected ? Config.tintColor : RdioDesign.borderColor).cgColor
            button.backgroundColor = selected ? Config.secondaryBackgroundColor : RdioDesign.cardColor
            button.subviews.compactMap { $0 as? UIImageView }.forEach {
                $0.tintColor = selected ? Config.tintColor : Config.secondaryTextColor
            }
        }
    }

    private func openSearch(query: String, filter: String) {
        tabBarController?.selectedIndex = 3
        (tabBarController?.viewControllers?[safe: 3] as? RdioSearchViewController)?.apply(query: query, filter: filter)
    }

    @objc private func nowPlaying() {
        experienceDelegate?.rdioDidRequestNowPlaying(from: self)
    }

    @objc private func playPressed() {
        if let station = manager.currentStation ?? stations.first {
            experienceDelegate?.rdioDidSelectStation(station, from: self)
        } else {
            experienceDelegate?.rdioDidRequestNowPlaying(from: self)
        }
    }

    @objc private func playbackOptions() {
        experienceDelegate?.rdioDidRequestPlaybackOptions(from: self)
    }

}

final class RdioExploreViewController: RdioBaseViewController {
    private enum MetadataKind {
        case genre
        case country
        case region
    }

    private let exploreTabs = ["for you", "genres", "countries", "regions"]
    private var selectedExploreTab = "countries"
    private var tabButtons: [UIButton] = []
    private let listStack = UIStackView()
    private var miniPlayerView: RdioMiniPlayerView?

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
        let bell = RdioDesign.iconButton("bell")
        bell.addTarget(self, action: #selector(aboutPressed), for: .touchUpInside)
        header.addArrangedSubview(bell)
        contentStack.addArrangedSubview(header)

        let tabs = UIStackView()
        tabs.axis = .horizontal
        tabs.distribution = .fillEqually
        exploreTabs.forEach { title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 19, weight: .semibold)
            button.addAction(UIAction { [weak self] _ in
                self?.selectedExploreTab = title
                self?.reloadContent()
            }, for: .touchUpInside)
            tabButtons.append(button)
            tabs.addArrangedSubview(button)
        }
        contentStack.addArrangedSubview(tabs)

        listStack.axis = .vertical
        listStack.spacing = 14
        contentStack.addArrangedSubview(listStack)

        if let station = manager.currentStation ?? stations.first {
            let mini = RdioMiniPlayerView(station: station) { [weak self] in
                guard let self else { return }
                self.experienceDelegate?.rdioDidRequestNowPlaying(from: self)
            }
            miniPlayerView = mini
            contentStack.addArrangedSubview(mini)
        }
        reloadContent()
    }

    override func reloadContent() {
        updateTabs()
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch selectedExploreTab {
        case "genres":
            listStack.addArrangedSubview(RdioDesign.sectionHeader(title: "popular genres", action: UIAction { [weak self] _ in
                self?.openSearch(query: "", filter: "Genres")
            }))
            metadataItems(kind: .genre).enumerated().forEach { index, item in
                listStack.addArrangedSubview(cityCard(name: item.name, count: "\(item.count) stations", index: index, filter: "Genres"))
            }
        case "countries":
            listStack.addArrangedSubview(RdioDesign.sectionHeader(title: "countries", action: UIAction { [weak self] _ in
                self?.openSearch(query: "", filter: "Countries")
            }))
            metadataItems(kind: .country).enumerated().forEach { index, item in
                listStack.addArrangedSubview(cityCard(name: item.name, count: "\(item.count) stations", index: index, filter: "Countries"))
            }
        case "for you":
            listStack.addArrangedSubview(RdioDesign.sectionHeader(title: "for you", action: UIAction { [weak self] _ in
                self?.openSearch(query: "", filter: "Stations")
            }))
            Array(stations.prefix(8)).forEach { station in
                listStack.addArrangedSubview(RdioStationRow(station: station, showsHeart: false) { [weak self] in
                    guard let self else { return }
                    self.experienceDelegate?.rdioDidSelectStation(station, from: self)
                })
            }
        default:
            listStack.addArrangedSubview(RdioDesign.sectionHeader(title: "regions", action: UIAction { [weak self] _ in
                self?.openSearch(query: "", filter: "Stations")
            }))
            metadataItems(kind: .region).enumerated().forEach { index, item in
                listStack.addArrangedSubview(cityCard(name: item.name, count: "\(item.count) stations", index: index, filter: "Stations"))
            }
        }

        if listStack.arrangedSubviews.count == 1 {
            listStack.addArrangedSubview(RdioDesign.emptyState("No live station data for this view yet."))
        }
    }

    private func cityCard(name: String, count: String, index: Int, filter: String) -> UIView {
        let view = UIControl()
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
        view.addAction(UIAction { [weak self] _ in
            self?.openSearch(query: name, filter: filter)
        }, for: .touchUpInside)

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

    private func updateTabs() {
        tabButtons.forEach { button in
            let selected = button.title(for: .normal) == selectedExploreTab
            button.tintColor = selected ? Config.primaryTextColor : Config.tertiaryTextColor
            button.titleLabel?.font = .systemFont(ofSize: 19, weight: selected ? .bold : .semibold)
        }
    }

    private func filteredStations(query: String) -> [RadioStation] {
        stations.filter { $0.matches(query) }
    }

    private func metadataItems(kind: MetadataKind) -> [RdioMetadataItem] {
        var counts: [String: Int] = [:]

        stations.forEach { station in
            let values: [String]
            switch kind {
            case .genre:
                values = station.genreNames
            case .country:
                values = station.countryName.map { [$0] } ?? []
            case .region:
                values = station.regionName.map { [$0] } ?? []
            }

            values.forEach { value in
                counts[value, default: 0] += 1
            }
        }

        return counts
            .map { RdioMetadataItem(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }
            .prefix(8)
            .map { $0 }
    }

    private func openSearch(query: String, filter: String) {
        tabBarController?.selectedIndex = 3
        (tabBarController?.viewControllers?[safe: 3] as? RdioSearchViewController)?.apply(query: query, filter: filter)
    }

    @objc private func aboutPressed() {
        experienceDelegate?.rdioDidRequestAbout(from: self)
    }
}

final class RdioLibraryViewController: RdioBaseViewController {
    private let libraryTabs = ["favorites", "collections", "history"]
    private var selectedLibraryTab = "favorites"
    private var tabButtons: [UIButton] = []
    private let listStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBarItem = UITabBarItem(title: "library", image: UIImage(systemName: "rectangle.stack"), selectedImage: UIImage(systemName: "rectangle.stack.fill"))
        build()
        reloadContent()
    }

    private func build() {
        let header = UIStackView()
        header.axis = .horizontal
        header.distribution = .equalSpacing
        header.addArrangedSubview(RdioDesign.title("library"))
        let bell = RdioDesign.iconButton("bell")
        bell.addTarget(self, action: #selector(aboutPressed), for: .touchUpInside)
        header.addArrangedSubview(bell)
        contentStack.addArrangedSubview(header)

        let tabs = UIStackView()
        tabs.axis = .horizontal
        tabs.distribution = .fillEqually
        libraryTabs.forEach { title in
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
            button.addAction(UIAction { [weak self] _ in
                self?.selectedLibraryTab = title
                self?.reloadContent()
            }, for: .touchUpInside)
            tabButtons.append(button)
            tabs.addArrangedSubview(button)
        }
        contentStack.addArrangedSubview(tabs)

        listStack.axis = .vertical
        listStack.spacing = 22
        contentStack.addArrangedSubview(listStack)
    }

    override func reloadContent() {
        updateTabs()
        listStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        switch selectedLibraryTab {
        case "collections":
            collectionItems().forEach {
                listStack.addArrangedSubview(collectionRow(title: $0.name, subtitle: "\($0.count) stations", icon: "tag", filter: "Genres"))
            }
        case "history":
            Array(stations.prefix(8)).forEach { station in
                listStack.addArrangedSubview(RdioStationRow(station: station, showsHeart: false) { [weak self] in
                    guard let self else { return }
                    self.experienceDelegate?.rdioDidSelectStation(station, from: self)
                })
            }
        default:
            countryItems().forEach {
                listStack.addArrangedSubview(collectionRow(title: $0.name, subtitle: "\($0.count) stations", icon: "globe", filter: "Countries"))
            }

            let divider = UIView()
            divider.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
            listStack.addArrangedSubview(divider)

            Array(stations.prefix(3)).forEach { station in
                listStack.addArrangedSubview(RdioStationRow(station: station, showsHeart: true) { [weak self] in
                    guard let self else { return }
                    self.experienceDelegate?.rdioDidSelectStation(station, from: self)
                })
            }
        }

        if listStack.arrangedSubviews.isEmpty {
            listStack.addArrangedSubview(RdioDesign.emptyState("No live stations loaded yet."))
        }
    }

    private func collectionRow(title: String, subtitle: String, icon: String, filter: String) -> UIView {
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
        let control = UIControl()
        control.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        control.addAction(UIAction { [weak self] _ in
            self?.tabBarController?.selectedIndex = 3
            (self?.tabBarController?.viewControllers?[safe: 3] as? RdioSearchViewController)?.apply(query: title, filter: filter)
        }, for: .touchUpInside)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: control.topAnchor),
            row.leadingAnchor.constraint(equalTo: control.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: control.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: control.bottomAnchor)
        ])
        return control
    }

    private func collectionItems() -> [RdioMetadataItem] {
        metadataItems { $0.genreNames }
    }

    private func countryItems() -> [RdioMetadataItem] {
        metadataItems { station in
            station.countryName.map { [$0] } ?? []
        }
    }

    private func metadataItems(values: (RadioStation) -> [String]) -> [RdioMetadataItem] {
        var counts: [String: Int] = [:]
        stations.forEach { station in
            values(station).forEach { counts[$0, default: 0] += 1 }
        }
        return counts
            .map { RdioMetadataItem(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }
            .prefix(4)
            .map { $0 }
    }

    private func updateTabs() {
        tabButtons.forEach { button in
            let selected = button.title(for: .normal) == selectedLibraryTab
            button.tintColor = selected ? Config.primaryTextColor : Config.tertiaryTextColor
            button.titleLabel?.font = .systemFont(ofSize: 20, weight: selected ? .bold : .semibold)
        }
    }

    @objc private func aboutPressed() {
        experienceDelegate?.rdioDidRequestAbout(from: self)
    }
}

final class RdioSearchViewController: RdioBaseViewController, UITextFieldDelegate {
    private let searchField = UITextField()
    private let filtersStack = UIStackView()
    private let resultsStack = UIStackView()
    private let showsHeader = RdioHomeViewControllerSectionLabel(title: "shows & episodes")
    private let showsStack = UIStackView()
    private var selectedFilter = "All"
    private var filterButtons: [UIButton] = []
    private var remoteResults: [RadioStation] = []
    private var remoteSearchKey = ""
    private var remoteSearchTask: Task<Void, Never>?

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
        searchField.placeholder = "Search stations"
        searchField.textColor = Config.primaryTextColor
        searchField.font = .systemFont(ofSize: 20, weight: .regular)
        searchField.backgroundColor = Config.elevatedBackgroundColor
        searchField.layer.cornerRadius = 18
        searchField.leftView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchField.leftViewMode = .always
        searchField.heightAnchor.constraint(equalToConstant: 56).isActive = true
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        let cancel = UIButton(type: .system)
        cancel.setTitle("Cancel", for: .normal)
        cancel.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        cancel.tintColor = Config.secondaryTextColor
        cancel.addTarget(self, action: #selector(cancelSearch), for: .touchUpInside)
        searchRow.addArrangedSubview(searchField)
        searchRow.addArrangedSubview(cancel)
        contentStack.addArrangedSubview(searchRow)

        filtersStack.axis = .horizontal
        filtersStack.spacing = 10
        filtersStack.distribution = .fillProportionally
        ["All", "Stations", "Genres", "Countries"].forEach { title in
            filtersStack.addArrangedSubview(filterChip(title, selected: title == "All"))
        }
        contentStack.addArrangedSubview(filtersStack)
        contentStack.addArrangedSubview(RdioDesign.sectionHeader(title: "stations", action: UIAction { [weak self] _ in
            self?.selectedFilter = "Stations"
            self?.resetRemoteResults()
            self?.reloadContent()
        }))
        resultsStack.axis = .vertical
        resultsStack.spacing = 18
        contentStack.addArrangedSubview(resultsStack)
        contentStack.addArrangedSubview(showsHeader)
        showsStack.axis = .vertical
        showsStack.spacing = 18
        contentStack.addArrangedSubview(showsStack)
    }

    override func reloadContent() {
        updateFilterSelection()
        let includeStations = selectedFilter == "All" || selectedFilter == "Stations"
        let includeMetadata = selectedFilter == "Genres" || selectedFilter == "Countries"
        let query = (searchField.text?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? ""

        resultsStack.isHidden = !(includeStations || includeMetadata)
        showsHeader.isHidden = true
        showsStack.isHidden = true

        let localMatches = query.isEmpty ? stations : stations.filter { $0.matches(query) }
        let stationItems = remoteResults.isEmpty ? localMatches : remoteResults
        renderStationResults(Array(stationItems.prefix(12)))
        loadRemoteStationsIfNeeded(query: query, filter: selectedFilter)

        showsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }

    private func filterChip(_ title: String, selected: Bool) -> UIView {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.borderWidth = 1
        button.layer.borderColor = RdioDesign.borderColor.cgColor
        button.layer.cornerRadius = 18
        button.clipsToBounds = true
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: selected ? 64 : 86).isActive = true
        button.addAction(UIAction { [weak self] _ in
            self?.selectedFilter = title
            self?.resetRemoteResults()
            self?.reloadContent()
        }, for: .touchUpInside)
        filterButtons.append(button)
        return button
    }

    func apply(query: String, filter: String) {
        searchField.text = query
        selectedFilter = filter
        resetRemoteResults()
        reloadContent()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        reloadContent()
        return true
    }

    @objc private func searchChanged() {
        resetRemoteResults()
        reloadContent()
    }

    @objc private func cancelSearch() {
        searchField.text = ""
        selectedFilter = "All"
        searchField.resignFirstResponder()
        resetRemoteResults()
        reloadContent()
    }

    private func updateFilterSelection() {
        for button in filterButtons {
            let selected = button.title(for: .normal) == selectedFilter
            button.tintColor = selected ? Config.backgroundColor : Config.secondaryTextColor
            button.backgroundColor = selected ? Config.primaryTextColor : .clear
        }
    }

    private func renderStationResults(_ items: [RadioStation]) {
        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard !items.isEmpty else {
            resultsStack.addArrangedSubview(RdioDesign.emptyState("No matching live stations."))
            return
        }
        items.forEach { station in
            resultsStack.addArrangedSubview(RdioStationRow(station: station, showsHeart: false) { [weak self] in
                guard let self else { return }
                self.experienceDelegate?.rdioDidSelectStation(station, from: self)
            })
        }
    }

    private func resetRemoteResults() {
        remoteResults = []
        remoteSearchKey = ""
        remoteSearchTask?.cancel()
    }

    private func loadRemoteStationsIfNeeded(query: String, filter: String) {
        guard Config.backendBaseURL != nil else { return }

        let key = "\(filter)|\(query)"
        guard remoteSearchKey != key else { return }
        remoteSearchKey = key
        remoteSearchTask?.cancel()

        remoteSearchTask = Task { [weak self] in
            do {
                let stations = try await NetworkService.searchStations(
                    query: query.isEmpty ? nil : query,
                    filter: filter,
                    limit: 50
                )
                await MainActor.run {
                    guard let self, self.remoteSearchKey == key else { return }
                    self.remoteResults = stations
                    self.renderStationResults(Array(stations.prefix(12)))
                }
            } catch {
                if Config.debugLog { print("Backend search failed: \(error)") }
            }
        }
    }
}

final class RdioPlaybackOptionsViewController: UIViewController {
    private let stack = UIStackView()
    private let sleepOptions = ["Off", "15 minutes", "30 minutes", "45 minutes", "60 minutes"]
    private let outputOptions = ["iPhone", "CarPlay"]
    private var selectedSleepTimer = "Off"
    private var selectedOutput = "CarPlay"

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
        stack.axis = .vertical
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52)
        ])
        reloadOptions()
    }

    private func reloadOptions() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(RdioDesign.title("playback options", size: 28))
        stack.addArrangedSubview(RdioDesign.secondary("sleep timer", size: 19))
        sleepOptions.forEach { option in
            stack.addArrangedSubview(optionRow(title: option, icon: nil, selected: option == selectedSleepTimer) { [weak self] in
                self?.selectedSleepTimer = option
                self?.reloadOptions()
            })
        }
        stack.addArrangedSubview(RdioDesign.secondary("play on", size: 19))
        outputOptions.forEach { option in
            stack.addArrangedSubview(optionRow(title: option, icon: option == "iPhone" ? "iphone" : "car", selected: option == selectedOutput) { [weak self] in
                self?.selectedOutput = option
                self?.reloadOptions()
            })
        }

        let close = UIButton(type: .system)
        close.setTitle("Close", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        close.tintColor = Config.primaryTextColor
        RdioDesign.applyCardStyle(close, radius: 16)
        close.heightAnchor.constraint(equalToConstant: 62).isActive = true
        close.addTarget(self, action: #selector(closePressed), for: .touchUpInside)
        stack.addArrangedSubview(close)
    }

    private func optionRow(title: String, icon: String?, selected: Bool, action: @escaping () -> Void) -> UIView {
        let button = UIButton(type: .system)
        button.contentHorizontalAlignment = .fill
        button.heightAnchor.constraint(equalToConstant: 54).isActive = true
        button.accessibilityLabel = title
        button.accessibilityTraits = selected ? [.button, .selected] : .button
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)

        let row = UIStackView()
        row.isUserInteractionEnabled = false
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 18
        row.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(row)
        if let icon {
            let image = UIImageView(image: UIImage(systemName: icon))
            image.isAccessibilityElement = false
            image.tintColor = Config.secondaryTextColor
            image.widthAnchor.constraint(equalToConstant: 30).isActive = true
            row.addArrangedSubview(image)
        }
        let label = RdioDesign.title(title, size: 24)
        label.isAccessibilityElement = false
        row.addArrangedSubview(label)
        let spacer = UIView()
        row.addArrangedSubview(spacer)
        if selected {
            let check = UIImageView(image: UIImage(systemName: "checkmark"))
            check.isAccessibilityElement = false
            check.tintColor = Config.tintColor
            row.addArrangedSubview(check)
        }
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: button.topAnchor),
            row.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        return button
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
        isAccessibilityElement = true
        accessibilityLabel = "\(station.name), \(station.desc)"
        accessibilityTraits = .button
        build(showsChevron: showsChevron, showsHeart: showsHeart)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func build(showsChevron: Bool, showsHeart: Bool) {
        let stack = UIStackView()
        stack.isUserInteractionEnabled = false
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
        labels.isUserInteractionEnabled = false
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

private extension RadioStation {
    var searchText: String {
        [name, desc, longDesc].joined(separator: " ")
    }

    var countryName: String? {
        metadataParts.first
    }

    var regionName: String? {
        guard metadataParts.count > 1 else { return nil }
        let value = metadataParts[1]
        return value.count > 2 ? value : nil
    }

    var genreNames: [String] {
        longDesc
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("radio browser") }
            .map { $0.localizedCapitalized }
    }

    func matches(_ query: String) -> Bool {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
        return searchText.localizedCaseInsensitiveContains(query)
    }

    private var metadataParts: [String] {
        desc
            .components(separatedBy: " - ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.localizedCaseInsensitiveContains("radio browser") }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
