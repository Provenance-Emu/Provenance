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
public enum Icon: Equatable {

  /// Icon with an image of the given name for the normal state.
  /// The "-highlighted" suffix is appended to the name for the highlighted image.
  case named(String)
  /// Icon with an image for the normal state.
  case image(UIImage)
  /// Icon with images for the normal and highlighted states.
  case images(normal: UIImage, highlighted: UIImage)

  /// The image for the normal state.
  public var image: UIImage? {
    switch self {
    case let .named(name):
      return UIImage(named: name)
    case let .image(image):
      return image
    case let .images(normal: image, highlighted: _):
      return image
    }
  }

  /// The image for the highlighted state.
  public var highlightedImage: UIImage? {
    switch self {
    case let .named(name):
      return UIImage(named: name + "-highlighted")
    case .image:
      return nil
    case let .images(normal: _, highlighted: image):
      return image
    }
  }

}
