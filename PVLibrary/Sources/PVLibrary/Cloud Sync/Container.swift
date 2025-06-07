//
//  Container.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 4/29/25.
//

import Foundation

public protocol Container {
    var containerURL: URL? { get }
}

extension Container {
    public var containerURL: URL? { get { return URL.iCloudContainerDirectory }}
    public var documentsURL: URL? { get { return URL.iCloudDocumentsDirectory }}
}
