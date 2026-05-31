//
//  PanelWebViewController.swift
//  Go Map!!
//
//  Copyright © 2026 Bryce Cogswell. All rights reserved.
//

import UIKit
@preconcurrency import WebKit

/// In-app web content in a sheet panel for quick open and dismiss.
final class PanelWebViewController: UIViewController {
	private let url: URL
	private var webView: WKWebView!

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

		if #available(iOS 15.0, *),
		   let sheet = sheetPresentationController
		{
			sheet.detents = [.medium(), .large()]
			sheet.prefersGrabberVisible = true
			sheet.selectedDetentIdentifier = .large
		}

		let config = WKWebViewConfiguration()
		webView = WKWebView(frame: .zero, configuration: config)
		webView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(webView)

		let toolbar = UIToolbar()
		toolbar.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(toolbar)

		let doneTitle = NSLocalizedString("Done", comment: "Dismiss web panel")
		let done = UIBarButtonItem(title: doneTitle,
		                           style: .done,
		                           target: self,
		                           action: #selector(close))
		let safari = UIBarButtonItem(image: UIImage(systemName: "safari"),
		                             style: .plain,
		                             target: self,
		                             action: #selector(openInSafari))
		toolbar.items = [
			safari,
			UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
			done
		]

		let guide = view.safeAreaLayoutGuide
		NSLayoutConstraint.activate([
			webView.topAnchor.constraint(equalTo: guide.topAnchor),
			webView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
			webView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
			toolbar.topAnchor.constraint(equalTo: webView.bottomAnchor),
			toolbar.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
			toolbar.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
			toolbar.bottomAnchor.constraint(equalTo: guide.bottomAnchor)
		])

		var request = URLRequest(url: url)
		request.setUserAgent()
		webView.load(request)
	}

	static func present(url: URL, from presenter: UIViewController) {
		let vc = PanelWebViewController(url: url)
		presenter.present(vc, animated: true)
	}

	@objc private func close() {
		dismiss(animated: true)
	}

	@objc private func openInSafari() {
		let target = webView.url ?? url
		guard UIApplication.shared.canOpenURL(target) else { return }
		UIApplication.shared.open(target, options: [:], completionHandler: nil)
	}
}
