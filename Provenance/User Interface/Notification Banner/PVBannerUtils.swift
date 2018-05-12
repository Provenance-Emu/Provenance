//
//  PVBannerUtils.swift
//  Provenance
//
//  Created by Yoshi Sugawara on 5/11/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import UIKit

class PVBannerUtils: NSObject {
    class func showSaveStateBanner(message: String) {
        let banner = Banner(title: message, subtitle: nil, image: nil, backgroundColor: Theme.currentTheme.gameLibraryBackground)
        banner.tintColor = Theme.currentTheme.defaultTintColor
        banner.show(duration: 2.0)
    }
}
