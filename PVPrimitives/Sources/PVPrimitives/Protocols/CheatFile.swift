//
//  CheatFile.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/30/24.
//
 
import Foundation

public protocol CheatFile {
    associatedtype LocalFileProviderType: LocalFileProvider
    var file: LocalFileProviderType! { get }
}

public extension LocalFileProvider where Self: CheatFile {
    var url: URL { get { return file.url }}
    var fileInfo: Self.LocalFileProviderType? { get { return file }}
}
