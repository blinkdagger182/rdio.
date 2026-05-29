//
//  SwiftRadio-Settings.swift
//  Swift Radio
//
//  Created by Matthew Fecher on 7/2/15.
//  Copyright (c) 2015 MatthewFecher.com. All rights reserved.
//

import UIKit

struct Config {

    static let debugLog = true

    enum StationsSource {
        case bundledJSON
        case remoteJSON
        case radioBrowser
        case backend
    }

    // Tint color used across the app (navigation bar, controls, etc.)
    static let tintColor = UIColor(red: 0.95, green: 0.43, blue: 0.04, alpha: 1.0)

    // Gradient background color (independent from tintColor)
    static let gradientColor = UIColor(red: 0.26, green: 0.36, blue: 0.42, alpha: 1.0)

    static let backgroundColor = UIColor(red: 0.035, green: 0.043, blue: 0.047, alpha: 1.0)
    static let elevatedBackgroundColor = UIColor(red: 0.075, green: 0.095, blue: 0.105, alpha: 1.0)
    static let secondaryBackgroundColor = UIColor(red: 0.11, green: 0.15, blue: 0.17, alpha: 1.0)
    static let primaryTextColor = UIColor(white: 0.96, alpha: 1.0)
    static let secondaryTextColor = UIColor(white: 0.73, alpha: 1.0)
    static let tertiaryTextColor = UIColor(white: 0.52, alpha: 1.0)

    // Choose where the app gets its station list.
    static let stationsSource: StationsSource = .backend

    // Legacy SwiftRadio JSON source settings.
    static let useLocalStations = stationsSource == .bundledJSON
    static let stationsURL = "https://fethica.com/assets/swift-radio/stations.json"

    // Radio Browser source settings. Keep the limit finite for fast startup; set nil to request all stations.
    static let radioBrowserAppName = Bundle.main.appName
    static let radioBrowserStationLimit: Int? = 1_000
    static let radioBrowserCountryCode: String? = nil
    static let radioBrowserHideBroken = true

    // Vercel proxy for Radio Browser. Keeps the app off a single mirror and enables filtered search.
    static let backendBaseURL: String? = "https://rdio-backend.vercel.app"
    static let backendStationLimit = 50

    // Set this to "true" to enable the search bar
    static let searchable = true

    // Set this to "false" to show the next/previous player buttons
    static let hideNextPreviousButtons = false
    
    // Contact & links
    static let website = "https://github.com/analogcode/Swift-Radio-Pro"
    static let email = "contact@fethica.com"
    static let emailSubject = "From \(Bundle.main.appName) App"
    static let feedbackURL = "https://fethica.com/#contact"
    static let licenseURL = "https://raw.githubusercontent.com/analogcode/Swift-Radio-Pro/refs/heads/master/LICENSE"

    struct Libraries {
        static let items: [LibraryItem] = [
            LibraryItem(owner: "analogcode", repo: "Swift-Radio-Pro"),
            LibraryItem(owner: "fethica", repo: "FRadioPlayer"),
            LibraryItem(owner: "ninjaprox", repo: "NVActivityIndicatorView"),
            LibraryItem(owner: "LeoNatan", repo: "LNPopupController"),
            LibraryItem(owner: "cbpowell", repo: "MarqueeLabel"),
        ]
    }

    struct Features {
        static let items: [FeatureItem] = [
            FeatureItem(title: Content.Features.swiftCodebase.0, subtitle: Content.Features.swiftCodebase.1, icon: "swift"),
            FeatureItem(title: Content.Features.carPlay.0, subtitle: Content.Features.carPlay.1, icon: "car.fill"),
            FeatureItem(title: Content.Features.customizableUI.0, subtitle: Content.Features.customizableUI.1, icon: "paintbrush"),
            FeatureItem(title: Content.Features.albumArt.0, subtitle: Content.Features.albumArt.1, icon: "music.note.list"),
            FeatureItem(title: Content.Features.lockScreen.0, subtitle: Content.Features.lockScreen.1, icon: "lock.circle"),
            FeatureItem(title: Content.Features.multipleStations.0, subtitle: Content.Features.multipleStations.1, icon: "radio"),
            FeatureItem(title: Content.Features.easySetup.0, subtitle: Content.Features.easySetup.1, icon: "checkmark.seal.fill"),
        ]
    }

    struct About {
        static let sections: [InfoSection] = [
            InfoSection(title: Content.About.Sections.features, items: [
                .features(title: Content.About.Items.features)
            ]),
            InfoSection(title: Content.About.Sections.contact, items: [
                .email(title: Content.About.Items.email, address: Config.email),
                .link(title: Content.About.feedback.0, subtitle: Content.About.feedback.1, url: Config.feedbackURL)
            ]),
            InfoSection(title: Content.About.Sections.support, items: [
                .rateApp(title: Content.About.Items.rateApp, appID: "YOUR_APP_ID"),
                .share(title: Content.About.Items.shareApp, text: Content.About.shareText)
            ]),
            InfoSection(title: Content.About.Sections.credits, items: [
                .libraries(title: Content.About.Items.libraries),
                .credits(title: Content.About.Items.contributors, subtitle: Content.About.Items.specialThanks, owner: "analogcode", repo: "Swift-Radio-Pro")
            ]),
            InfoSection(title: Content.About.Sections.legal, items: [
                .link(title: Content.About.license.0, subtitle: Content.About.license.1, url: Config.licenseURL)
            ]),
            InfoSection(title: Content.About.Sections.version, items: [
                .version(title: Content.About.Items.appVersion)
            ])
        ]
    }
}
