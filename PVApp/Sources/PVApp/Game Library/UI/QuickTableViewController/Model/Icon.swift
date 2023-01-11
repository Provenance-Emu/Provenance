//
//  Icon.swift
//  QuickTableViewController
//
//  Created by Ben on 01/09/2015.
//  Copyright (c) 2015 bcylin.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import UIKit

/// A struct that represents the image used in a row.
public struct Icon: Equatable {

  /// The initializer is kept private until v2.0 when `methodSignature` is removed.
  private init(methodSignature: String, image: UIImage?, highlightedImage: UIImage?) {
    self.methodSignature = methodSignature
    self.image = image
    self.highlightedImage = highlightedImage
  }

  // MARK: - Properties

  /// A string to keep track of how the struct is initialized.
  /// It's used internally to avoid the breaking Equatable changes of Icon (as enum) until v2.0.
  private let methodSignature: String

  /// The image for the normal state.
  public let image: UIImage?

  /// The image for the highlighted state.
  public let highlightedImage: UIImage?

  // MARK: -

  /// Returns `Icon` with an image of the given name for the normal state.
  /// The "-highlighted" suffix is appended to the name for the highlighted image.
  ///
  /// - Parameters:
  ///   - name: The name of the image asset.
  ///   - bundle: The bundle containing the image file or asset catalog. Specify nil to search the app’s main bundle.
  ///   - traitCollection: The traits associated with the intended environment for the image. Specify nil to use the traits associated with the main screen.
  public static func named(_ name: String, in bundle: Bundle? = nil, compatibleWith traitCollection: UITraitCollection? = nil) -> Self {
    return Icon(
      methodSignature: "\(#function):\(name)",
      image: UIImage(named: name, in: bundle, compatibleWith: traitCollection),
      highlightedImage: UIImage(named: name + "-highlighted", in: bundle, compatibleWith: traitCollection)
    )
  }

  /// Returns `Icon` with an image for the normal state. The image for the highlighted state is nil.
  /// A method to provide backward compatiblility with the previous enum `case image(UIImage)`.
  public static func image(_ image: UIImage) -> Self {
    return Icon(methodSignature: #function, image: image, highlightedImage: nil)
  }

  /// Returns `Icon` with images for the normal and highlighted states.
  /// A method to provide backward compatiblility with the previous enum `case images(normal: UIImage, highlighted: UIImage)`.
  public static func images(normal: UIImage, highlighted: UIImage) -> Self {
    return Icon(methodSignature: #function, image: normal, highlightedImage: highlighted)
  }

  /// Returns `Icon` with the specified SF Symbol as the image for the normal state.
  /// The image for the highlighted state is nil.
  ///
  /// - Parameters:
  ///   - name: The name of the system symbol image.
  ///   - configuration: The configuration to specify traits and other details that define the variant of image.
  public static func sfSymbol(_ name: String, withConfiguration configuration: UIImage.Configuration? = nil) -> Self {
    // Make sure the image scales with the Dynamic Type settings.
    let fallback = UIImage.SymbolConfiguration(textStyle: .body)
    return Icon(
      methodSignature: "\(#function):\(name)",
      image: UIImage(systemName: name, withConfiguration: configuration ?? fallback),
      highlightedImage: nil
    )
  }

}
