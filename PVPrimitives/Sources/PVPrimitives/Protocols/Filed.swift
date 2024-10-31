//
//  Filed.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//

import Foundation

public protocol Filed {
    associatedtype LocalFileProviderType: LocalFileProvider
    var file: LocalFileProviderType! { get }
}

extension LocalFileProvider where Self: Filed {
    public var url: URL { get { return file.url } }
    public var fileInfo: Self.LocalFileProviderType? { return file }
}
