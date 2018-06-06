//
//  PVCoresTableViewController
//  Provenance
//
//  Created by Joe Mattiello on 16.03.18.
//  Copyright © 2018 Joe Mattiello. All rights reserved.
//

import UIKit
import RealmSwift

class PVCoresTableViewController: UITableViewController {

    let cores = RomDatabase.sharedInstance.all(PVCore.self, sortedByKeyPath: #keyPath(PVCore.projectName))

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

// MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cores.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "coreCell")!

        let core = cores[indexPath.row]
        let systemsText = core.supportedSystems.map({return $0.shortName}).joined(separator: ", ")

        cell.textLabel?.text = core.projectName
        cell.detailTextLabel?.text = "\(core.projectVersion) : \(systemsText)"

        #if os(iOS)
        if URL.init(string: core.projectURL) != nil {
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.accessoryType = .none
        }
        #else
            cell.accessoryType = .none
        #endif

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        #if os(iOS)
        let core = cores[indexPath.row]

        guard let url = URL.init(string: core.projectURL) else {
            return
        }

        let webVC = WebkitViewController(url: url)
        webVC.title = core.projectName

        navigationController?.pushViewController(webVC, animated: true)
        #endif
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
