//
//  PanelWebViewController.swift
//  Go Map!!
//
//  Copyright © 2026 Bryce Cogswell. All rights reserved.
//

import UIKit
@preconcurrency import WebKit

/// In-app web content in a sheet panel for quick open and dismiss.
final class PanelWebViewController: UIViewController, WKNavigationDelegate {
	private let url: URL
	private var webView: WKWebView!
	private let activityIndicator = UIActivityIndicatorView(style: .medium)
	private let errorLabel = UILabel()

	init(url: URL) {
		self.url = url
		super.init(nibName: nil, bundle: nil)
		modalPresentationStyle = .pageSheet
	}

	@available(*, unavailable)
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground
		configureSheetPresentation()

		let config = WKWebViewConfiguration()
		webView = WKWebView(frame: .zero, configuration: config)
		webView.navigationDelegate = self
		webView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(webView)

		activityIndicator.translatesAutoresizingMaskIntoConstraints = false
		activityIndicator.hidesWhenStopped = true
		view.addSubview(activityIndicator)

		errorLabel.translatesAutoresizingMaskIntoConstraints = false
		errorLabel.font = UIFont.preferredFont(forTextStyle: .body)
		errorLabel.textColor = .secondaryLabel
		errorLabel.numberOfLines = 0
		errorLabel.textAlignment = .center
		errorLabel.isHidden = true
		view.addSubview(errorLabel)

		let toolbar = makeToolbar()
		toolbar.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(toolbar)

		let guide = view.safeAreaLayoutGuide
		NSLayoutConstraint.activate([
			webView.topAnchor.constraint(equalTo: guide.topAnchor),
			webView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
			webView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
			toolbar.topAnchor.constraint(equalTo: webView.bottomAnchor),
			toolbar.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
			toolbar.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
			toolbar.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
			activityIndicator.centerXAnchor.constraint(equalTo: webView.centerXAnchor),
			activityIndicator.centerYAnchor.constraint(equalTo: webView.centerYAnchor),
			errorLabel.leadingAnchor.constraint(equalTo: webView.leadingAnchor, constant: 20),
			errorLabel.trailingAnchor.constraint(equalTo: webView.trailingAnchor, constant: -20),
			errorLabel.centerYAnchor.constraint(equalTo: webView.centerYAnchor)
		])

		loadInitialRequest()
	}

	static func present(url: URL, from presenter: UIViewController, sourceView: UIView? = nil) {
		let vc = PanelWebViewController(url: url)
		if let sourceView {
			vc.popoverPresentationController?.sourceView = sourceView
		}
		presenter.present(vc, animated: true)
	}

	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		showLoading(true)
		errorLabel.isHidden = true
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		showLoading(false)
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
		showLoadFailure(error)
	}

	func webView(_ webView: WKWebView,
	             didFailProvisionalNavigation navigation: WKNavigation!,
	             withError error: Error)
	{
		showLoadFailure(error)
	}

	@objc private func close() {
		dismiss(animated: true)
	}

	@objc private func openInSafari() {
		let target = webView.url ?? url
		guard UIApplication.shared.canOpenURL(target) else { return }
		UIApplication.shared.open(target, options: [:], completionHandler: nil)
	}

	private func configureSheetPresentation() {
		if #available(iOS 15.0, *),
		   let sheet = sheetPresentationController
		{
			sheet.detents = [.medium(), .large()]
			sheet.prefersGrabberVisible = true
			sheet.selectedDetentIdentifier = .large
		}
	}

	private func makeToolbar() -> UIToolbar {
		let toolbar = UIToolbar()
		let doneTitle = NSLocalizedString("Done", comment: "Dismiss web panel")
		let done = UIBarButtonItem(title: doneTitle,
		                           style: .done,
		                           target: self,
		                           action: #selector(close))
		let safari = UIBarButtonItem(image: UIImage(systemName: "safari"),
		                             style: .plain,
		                             target: self,
		                             action: #selector(openInSafari))
		safari.accessibilityLabel = NSLocalizedString("Open in Safari", comment: "Open web panel in Safari")
		toolbar.items = [
			safari,
			UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
			done
		]
		return toolbar
	}

	private func loadInitialRequest() {
		showLoading(true)
		var request = URLRequest(url: url)
		request.setUserAgent()
		webView.load(request)
	}

	private func showLoading(_ loading: Bool) {
		if loading {
			activityIndicator.startAnimating()
		} else {
			activityIndicator.stopAnimating()
		}
	}

	private func showLoadFailure(_ error: Error) {
		showLoading(false)
		errorLabel.text = error.localizedDescription
		errorLabel.isHidden = false
	}
}
