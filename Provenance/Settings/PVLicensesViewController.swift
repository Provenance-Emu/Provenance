//  Converted to Swift 4 by Swiftify v4.1.6613 - https://objectivec2swift.com/
//
//  PVLicensesViewController.swift
//  Provenance
//
//  Created by Marcel Voß on 20.09.16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

import UIKit

class PVLicensesViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        title = "Acknowledgements"
        let filesystemPath: String? = Bundle.main.path(forResource: "licenses", ofType: "html")
        let htmlContent = try? String(contentsOfFile: filesystemPath ?? "", encoding: .utf8)
        let webView = UIWebView(frame: view.bounds)
        webView.loadHTMLString(htmlContent ?? "", baseURL: nil)
        webView.scalesPageToFit = false
        webView.scrollView.bounces = false
        webView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        view.addSubview(webView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}