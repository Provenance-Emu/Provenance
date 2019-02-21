//
//  PVCoresTableViewController
//  Provenance
//
//  Created by Joe Mattiello on 16.03.18.
//  Copyright © 2018 Joe Mattiello. All rights reserved.
//

import PVLibrary
import QuickTableViewController
import RealmSwift
import UIKit

final class PVCoresTableViewController: QuickTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let cores = RomDatabase.sharedInstance.all(PVCore.self, sortedByKeyPath: #keyPath(PVCore.projectName))

        #if os(tvOS)
            splitViewController?.title = "Cores"
        #endif

        tableContents = [
            Section(title: "Cores", rows: cores.map { core in
                let systemsText = core.supportedSystems.map({ $0.shortName }).joined(separator: ", ")
                let detailLabelText = "\(core.projectVersion) : \(systemsText)"

                return NavigationRow<SystemSettingsCell>(text: core.projectName, detailText: .subtitle(detailLabelText), icon: nil, customization: { cell, _ in
                    #if os(iOS)
                        if URL(string: core.projectURL) != nil {
                            cell.accessoryType = .disclosureIndicator
                        } else {
                            cell.accessoryType = .none
                        }
                    #else
                        cell.accessoryType = .none
                    #endif
                }, action: { _ in
                    #if os(iOS)
                        guard let url = URL(string: core.projectURL) else {
                            return
                        }

                        let webVC = WebkitViewController(url: url)
                        webVC.title = core.projectName

                        self.navigationController?.pushViewController(webVC, animated: true)
                    #endif
                })
            }),
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

        required init?(coder _: NSCoder) {
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

            let hud = MBProgressHUD(view: view)!
            hud.isUserInteractionEnabled = false
            hud.mode = .determinateHorizontalBar
            hud.progress = 0
            hud.labelText = "Loading..."

            self.hud = hud
            webView.addSubview(hud)

            token = webView.observe(\.estimatedProgress) { webView, _ in
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
        func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            hud.show(true)
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            hud.hide(true, afterDelay: 0.0)
        }
    }
#endif
