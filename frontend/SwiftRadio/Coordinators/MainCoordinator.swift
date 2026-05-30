//
//  MainCoordinator.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2022-11-23.
//  Copyright © 2022 matthewfecher.com. All rights reserved.
//

import UIKit
import MessageUI
import SafariServices
import LNPopupController
import FRadioPlayer

class MainCoordinator: NSObject, NavigationCoordinator {
    var childCoordinators: [Coordinator] = []
    let navigationController: UINavigationController

    private lazy var nowPlayingViewController: NowPlayingViewController = {
        let vc = NowPlayingViewController()
        vc.delegate = self
        return vc
    }()

    private let player = FRadioPlayer.shared
    private var isPopupBarPresented = false
    private weak var rdioTabBarController: RdioTabBarController?

    func start() {
        let loaderVC = LoaderController()
        loaderVC.delegate = self
        navigationController.setViewControllers([loaderVC], animated: false)
    }

    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
        self.navigationController.delegate = self
        self.navigationController.interactivePopGestureRecognizer?.isEnabled = true
        self.navigationController.interactivePopGestureRecognizer?.delegate = nil
    }

    // MARK: - Popup Bar

    func presentPopupBarIfNeeded() {
        guard !isPopupBarPresented else { return }
        let container = popupContainer
        container.popupBar.barStyle = .prominent
        container.popupBar.tintColor = Config.tintColor
        container.popupBar.progressViewStyle = .bottom
        container.popupContentView.popupCloseButtonStyle = .chevron
        container.presentPopupBar(with: nowPlayingViewController, animated: true)
        isPopupBarPresented = true
    }

    private var popupContainer: UIViewController {
        rdioTabBarController ?? navigationController
    }

    // MARK: - Shared

    func openEmail(to email: String, from coordinator: AboutCoordinator) {
        guard let aboutVC = coordinator.navigationController.viewControllers.first as? AboutViewController else { return }
        guard MFMailComposeViewController.canSendMail() else {
            aboutVC.showSendMailErrorAlert()
            return
        }

        let mailComposer = MFMailComposeViewController()
        mailComposer.mailComposeDelegate = coordinator
        mailComposer.setToRecipients([email])
        mailComposer.setSubject(Config.emailSubject)
        mailComposer.setMessageBody("", isHTML: false)
        aboutVC.present(mailComposer, animated: true)
    }

    func openAbout() {
        let modalNav = UINavigationController()
        let aboutCoordinator = AboutCoordinator(navigationController: modalNav)
        aboutCoordinator.parentCoordinator = self
        aboutCoordinator.start()
        childCoordinators.append(aboutCoordinator)
        navigationController.present(modalNav, animated: true)
    }

    func share(_ text: String, from viewController: UIViewController) {
        let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.sourceView = viewController.view
            popoverController.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popoverController.permittedArrowDirections = []
        }
        viewController.present(activityViewController, animated: true)
    }
}

// MARK: - LoaderControllerDelegate

extension MainCoordinator: LoaderControllerDelegate {
    func didFinishLoading(_ controller: LoaderController, stations: [RadioStation]) {
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([makeRdioTabBarController()], animated: false)
    }
}

// MARK: - Rdio Experience

private extension MainCoordinator {
    func makeRdioTabBarController() -> UITabBarController {
        let home = RdioHomeViewController()
        let explore = RdioExploreViewController()
        let library = RdioLibraryViewController()
        [home, explore, library].forEach { $0.experienceDelegate = self }

        let tabBar = RdioTabBarController()
        tabBar.setViewControllers([home, explore, library], animated: false)
        rdioTabBarController = tabBar
        return tabBar
    }
}

extension MainCoordinator: RdioExperienceDelegate {
    func rdioDidSelectStation(_ station: RadioStation, from controller: UIViewController) {
        let isNewStation = station != StationsManager.shared.currentStation
        if isNewStation {
            StationsManager.shared.set(station: station)
            StationStore.shared.recordPlay(station)
            player.play()
            presentPopupBarIfNeeded()
        } else if player.isPlaying {
            popupContainer.openPopup(animated: true)
        } else {
            player.togglePlaying()
            presentPopupBarIfNeeded()
        }
    }

    func rdioDidStartPlayback(from controller: UIViewController) {
        presentPopupBarIfNeeded()
    }

    func rdioDidRequestStationList(title: String, query: String, filter: String, from controller: UIViewController) {
        let list = RdioStationListViewController(title: title, query: query, filter: filter)
        list.experienceDelegate = self
        navigationController.pushViewController(list, animated: true)
    }

    func rdioDidRequestCountryList(from controller: UIViewController) {
        let list = RdioCountryListViewController()
        list.experienceDelegate = self
        navigationController.pushViewController(list, animated: true)
    }

    func rdioDidRequestSearch(query: String, filter: String, from controller: UIViewController) {
        let search = RdioSearchViewController()
        search.experienceDelegate = self
        search.loadViewIfNeeded()
        search.apply(query: query, filter: filter)
        navigationController.pushViewController(search, animated: true)
    }

    func rdioDidRequestNowPlaying(from controller: UIViewController) {
        guard StationsManager.shared.currentStation != nil else {
            if let station = StationsManager.shared.stations.first {
                StationsManager.shared.set(station: station)
            }
            presentPopupBarIfNeeded()
            popupContainer.openPopup(animated: true)
            return
        }
        presentPopupBarIfNeeded()
        popupContainer.openPopup(animated: true)
    }

    func rdioDidRequestPlaybackOptions(from controller: UIViewController) {
        let options = RdioPlaybackOptionsViewController()
        controller.present(options, animated: true)
    }

    func rdioDidRequestAbout(from controller: UIViewController) {
        openAbout()
    }
}

// MARK: - StationsViewControllerDelegate

extension MainCoordinator: StationsViewControllerDelegate {

    func didSelectStation(_ station: RadioStation, from stationsViewController: StationsViewController) {
        let isNewStation = station != StationsManager.shared.currentStation
        if isNewStation {
            StationsManager.shared.set(station: station)
            StationStore.shared.recordPlay(station)
            player.play()
            presentPopupBarIfNeeded()
        } else if player.isPlaying {
            popupContainer.openPopup(animated: true)
        } else {
            player.togglePlaying()
        }
    }

    func didTapNowPlaying(_ stationsViewController: StationsViewController) {
        popupContainer.openPopup(animated: true)
    }

    func presentAbout(_ stationsViewController: StationsViewController) {
        openAbout()
    }
}

// MARK: - UINavigationControllerDelegate

extension MainCoordinator: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController,
                              didShow viewController: UIViewController,
                              animated: Bool) {
        // UIKit disables interactivePopGestureRecognizer when nav bar is hidden;
        // re-enable after every push/pop so swipe-back always works.
        let canPop = navigationController.viewControllers.count > 1
        navigationController.interactivePopGestureRecognizer?.isEnabled = canPop
        navigationController.interactivePopGestureRecognizer?.delegate = nil
    }
}

// MARK: - NowPlayingViewControllerDelegate

extension MainCoordinator: NowPlayingViewControllerDelegate {

    func didSelectBottomSheetOption(_ option: BottomSheetViewController.Option, from controller: NowPlayingViewController) {
        guard let station = StationsManager.shared.currentStation else { return }

        switch option {
        case .info:
            let infoController = InfoDetailViewController(station: station)
            navigationController.pushViewController(infoController, animated: true)
            popupContainer.closePopup(animated: true)
        case .website:
            if let website = station.website, let url = URL(string: website) {
                let safariVC = SFSafariViewController(url: url)
                popupContainer.closePopup(animated: true, completion: { [weak self] in
                    self?.navigationController.present(safariVC, animated: true)
                })
            }
        default:
            BottomSheetHandler.handle(option, station: station, from: controller)
        }
    }

    func didTapCompanyButton(_ nowPlayingViewController: NowPlayingViewController) {
        openAbout()
    }
}
