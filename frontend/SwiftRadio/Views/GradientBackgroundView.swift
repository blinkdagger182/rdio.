//
//  GradientBackgroundView.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2025-02-07.
//  Copyright © 2025 matthewfecher.com. All rights reserved.
//

import UIKit

class GradientBackgroundView: UIView {

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.startPoint = CGPoint(x: 0, y: 1)
        layer.endPoint = CGPoint(x: 1, y: 0)
        return layer
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Config.backgroundColor
        updateGradientColors()
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func updateGradientColors() {
        gradientLayer.colors = [
            Config.secondaryBackgroundColor.withAlphaComponent(0.95).cgColor,
            Config.gradientColor.withAlphaComponent(0.48).cgColor,
            Config.backgroundColor.withAlphaComponent(0.92).cgColor,
            Config.backgroundColor.cgColor
        ]
        gradientLayer.locations = [0.0, 0.34, 0.72, 1.0]
    }
}
