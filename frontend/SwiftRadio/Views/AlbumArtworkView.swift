//
//  AlbumArtworkView.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2024-01-13.
//  Copyright 2024 matthewfecher.com. All rights reserved.
//

import UIKit
import NVActivityIndicatorView

class AlbumArtworkView: UIView {

    private let particleLayer = CAEmitterLayer()

    private let containerView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.backgroundColor = Config.elevatedBackgroundColor
        return view
    }()

    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFill
        view.clipsToBounds = true
        view.alpha = 0.88
        return view
    }()

    private let bufferingOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.alpha = 0
        return view
    }()

    private let bufferingIndicator: NVActivityIndicatorView = {
        let view = NVActivityIndicatorView(frame: .zero, type: .ballPulse, color: Config.tintColor, padding: nil)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage?, animated: Bool = false) {
        let image = image ?? UIImage(named: "logo")
        guard animated else {
            imageView.image = image
            return
        }
        UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve) {
            self.imageView.image = image
        }
    }

    func setBuffering(_ isBuffering: Bool) {
        if isBuffering {
            bufferingIndicator.startAnimating()
            UIView.animate(withDuration: 0.3) { self.bufferingOverlay.alpha = 1 }
        } else {
            UIView.animate(withDuration: 0.3) { self.bufferingOverlay.alpha = 0 }
            bufferingIndicator.stopAnimating()
        }
    }

    func setPlaying(_ isPlaying: Bool) {
        let scale: CGFloat = isPlaying ? 1.0 : 0.85
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0,
            options: .allowUserInteraction
        ) {
            self.containerView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.layer.cornerRadius = min(containerView.bounds.width, containerView.bounds.height) / 2
        particleLayer.frame = containerView.bounds
        particleLayer.emitterSize = CGSize(width: containerView.bounds.width * 0.78, height: containerView.bounds.height * 0.78)
        particleLayer.emitterPosition = CGPoint(x: containerView.bounds.midX, y: containerView.bounds.midY)
    }

    private func configureParticleLayer() {
        particleLayer.emitterShape = .circle
        particleLayer.emitterMode = .surface
        let cell = CAEmitterCell()
        cell.birthRate = 150
        cell.lifetime = 1
        cell.velocity = 0
        cell.scale = 0.01
        cell.scaleRange = 0.014
        cell.alphaRange = 0.55
        cell.color = UIColor.white.withAlphaComponent(0.75).cgColor
        cell.contents = makeParticleImage().cgImage
        particleLayer.emitterCells = [cell]
    }

    private func makeParticleImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4))
        return renderer.image { context in
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: 4, height: 4))
        }
    }

    private func setupViews() {
        // Shadow on outer view
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.4
        layer.shadowOffset = CGSize(width: 0, height: 10)
        layer.shadowRadius = 20

        containerView.translatesAutoresizingMaskIntoConstraints = false

        imageView.translatesAutoresizingMaskIntoConstraints = false
        bufferingOverlay.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(imageView)
        configureParticleLayer()
        containerView.layer.addSublayer(particleLayer)
        containerView.addSubview(bufferingOverlay)
        bufferingOverlay.addSubview(bufferingIndicator)
        addSubview(containerView)

        NSLayoutConstraint.activate([
            // Container fills the view
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Keep container square
            containerView.widthAnchor.constraint(equalTo: containerView.heightAnchor),

            // Image fills container
            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            // Buffering overlay fills container
            bufferingOverlay.topAnchor.constraint(equalTo: containerView.topAnchor),
            bufferingOverlay.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            bufferingOverlay.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            bufferingOverlay.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bufferingIndicator.centerXAnchor.constraint(equalTo: bufferingOverlay.centerXAnchor),
            bufferingIndicator.centerYAnchor.constraint(equalTo: bufferingOverlay.centerYAnchor),
            bufferingIndicator.widthAnchor.constraint(equalToConstant: 40),
            bufferingIndicator.heightAnchor.constraint(equalToConstant: 30),
        ])
    }
}
