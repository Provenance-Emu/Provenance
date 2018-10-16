//
//  PVCoresTableViewController
//  Provenance
//
//  Created by Joe Mattiello on 16.03.18.
//  Copyright © 2018 Joe Mattiello. All rights reserved.
//

import UIKit
import RealmSwift
import PVLibrary
import QuickTableViewController

class PVCoresTableViewController: QuickTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
		let cores = RomDatabase.sharedInstance.all(PVCore.self, sortedByKeyPath: #keyPath(PVCore.projectName))
		tableContents = [
			Section(title: "Cores", rows: cores.map { core in
				let systemsText = core.supportedSystems.map({return $0.shortName}).joined(separator: ", ")
				let detailLabelText = "\(core.projectVersion) : \(systemsText)"

				return NavigationRow<SystemSettingsCell>(title: core.projectName, subtitle: .belowTitle(detailLabelText), icon: nil, customization: { (cell, rowStyle) in
					#if os(iOS)
					if URL.init(string: core.projectURL) != nil {
						cell.accessoryType = .disclosureIndicator
					} else {
						cell.accessoryType = .none
					}
					#else
					cell.accessoryType = .none
					#endif
				}, action: { (row) in
					#if os(iOS)
					guard let url = URL.init(string: core.projectURL) else {
						return
					}

					let webVC = WebkitViewController(url: url)
					webVC.title = core.projectName

					self.navigationController?.pushViewController(webVC, animated: true)
					#endif
				})
			})
		]
    }
}

#if os(iOS)
    import WebKit
    class WebkitViewController: UIViewController {
        private let url: URL
        private var webView: WKWebView!
        private var hud: MBProgressHUD!
        private var token: NSKeyValueObservation?

        init(url: URL) {
            self.url = url
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            token?.invalidate()
            token = nil
        }

        override func viewDidLoad() {
            let config = WKWebViewConfiguration()
            let webView = WKWebView(frame: view.bounds, configuration: config)
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            webView.navigationDelegate = self
            self.webView = webView

            view.addSubview(webView)

            let hud = MBProgressHUD.init(view: view)!
            hud.isUserInteractionEnabled = false
            hud.mode = .determinateHorizontalBar
            hud.progress = 0
            hud.labelText = "Loading..."

            self.hud = hud
            webView.addSubview(hud)

            token = webView.observe(\.estimatedProgress) { (webView, change) in
                let estimatedProgress = webView.estimatedProgress
                self.hud.progress = Float(estimatedProgress)
            }
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            webView.load(URLRequest(url: url))
        }
    }

    extension WebkitViewController: WKNavigationDelegate {
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            self.hud.show(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            self.hud.hide(true, afterDelay: 0.0)
        }
    }
#endif
