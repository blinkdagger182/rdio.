//
//  LoaderController.swift
//  SwiftRadio
//
//  Created by Fethi El Hassasna on 2022-12-03.
//  Copyright © 2022 matthewfecher.com. All rights reserved.
//

import UIKit

protocol LoaderControllerDelegate: AnyObject {
    func didFinishLoading(_ controller: LoaderController, stations: [RadioStation])
}

class LoaderController: BaseController {
    
    weak var delegate: LoaderControllerDelegate?
    
    private let manager = StationsManager.shared
    
    private let activityIndicatorView: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = Config.tintColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let errorTitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.preferredFont(forTextStyle: .headline)
        label.textColor = Config.primaryTextColor
        label.numberOfLines = 0
        label.text = Content.Loader.errorTitle
        return label
    }()
    
    private let errorMessageLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = Config.secondaryTextColor
        return label
    }()
    
    private let stackView: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.alignment = .center
        view.spacing = 16
        return view
    }()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetchStations()
    }
    
    private func handle(_ error: Error) {
        stackView.isHidden = false
        errorMessageLabel.text = error.localizedDescription
    }
    
    private func fetchStations() {
        stackView.isHidden = true
        activityIndicatorView.startAnimating()
        
        manager.fetch { [weak self] result in
            guard let self = self else { return }
            
            self.activityIndicatorView.stopAnimating()
            
            switch result {
            case .success(let stations):
                self.delegate?.didFinishLoading(self, stations: stations)
            case .failure(let error):
                self.handle(error)
            }
        }
    }
    
    override func setupViews() {
        super.setupViews()
        
        let logoImageView = UIImageView(image: UIImage(named: "logo"))
        logoImageView.contentMode = .scaleAspectFill
        logoImageView.clipsToBounds = true
        logoImageView.layer.cornerRadius = 42
        logoImageView.layer.borderWidth = 1
        logoImageView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        let wordmarkLabel = UILabel()
        wordmarkLabel.text = "rdio."
        wordmarkLabel.font = UIFont.systemFont(ofSize: 34, weight: .regular)
        wordmarkLabel.textAlignment = .center
        wordmarkLabel.textColor = Config.primaryTextColor
        wordmarkLabel.translatesAutoresizingMaskIntoConstraints = false

        let taglineLabel = UILabel()
        taglineLabel.text = "live radio, beautifully tuned."
        taglineLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        taglineLabel.textAlignment = .center
        taglineLabel.textColor = Config.tertiaryTextColor
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(logoImageView)
        view.addSubview(wordmarkLabel)
        view.addSubview(taglineLabel)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -28),
            logoImageView.widthAnchor.constraint(equalToConstant: 132),
            logoImageView.heightAnchor.constraint(equalToConstant: 132),
            wordmarkLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            wordmarkLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            taglineLabel.topAnchor.constraint(equalTo: wordmarkLabel.bottomAnchor, constant: 96),
            taglineLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
        
        // Activity Indicator
        view.addSubview(activityIndicatorView)
        
        NSLayoutConstraint.activate([
            activityIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicatorView.topAnchor.constraint(equalTo: wordmarkLabel.bottomAnchor, constant: 28)
        ])
        
        // Retry button
        let retryButton = UIButton(type: .system)
        retryButton.setTitle(Content.Loader.retryButton, for: .normal)
        retryButton.tintColor = Config.tintColor
        retryButton.addTarget(self, action: #selector(handleRetry), for: .touchUpInside)
        
        // Stack view
        stackView.addArrangedSubview(errorTitleLabel)
        stackView.addArrangedSubview(errorMessageLabel)
        stackView.addArrangedSubview(retryButton)
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: wordmarkLabel.bottomAnchor, constant: 28),
            stackView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7)
        ])
    }
    
    @objc private func handleRetry() {
        fetchStations()
    }
}
