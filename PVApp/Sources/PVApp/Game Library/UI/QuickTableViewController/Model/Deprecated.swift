//
//  Deprecated.swift
//  QuickTableViewController
//
//  Created by bcylin on 01/01/2019.
//  Copyright © 2019 bcylin.
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

public extension Row {

  @available(*, deprecated, message: "Use `text` instead.")
  var title: String {
    return text
  }

  @available(*, deprecated, message: "Use `detailText` instead.")
  var subtitle: Subtitle? {
    return detailText?.subtitle
  }

}

////////////////////////////////////////////////////////////////////////////////

public extension NavigationRow {

  @available(*, deprecated, message: "Use `init(text:detailText:icon:customization:action:)` instead.")
  convenience init(
    title: String,
    subtitle: Subtitle,
    icon: Icon? = nil,
    customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
    action: ((Row) -> Void)? = nil
  ) {
    self.init(
      text: title,
      detailText: subtitle.detailText,
      icon: icon,
      customization: customization,
      action: action
    )
  }

}

////////////////////////////////////////////////////////////////////////////////

public extension OptionRow {

  @available(*, deprecated, message: "Use `init(text:detailText:isSelected:icon:customization:action:)` instead.")
  convenience init(
    title: String,
    isSelected: Bool,
    icon: Icon? = nil,
    customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
    action: ((Row) -> Void)?
  ) {
    self.init(
      text: title,
      detailText: nil,
      isSelected: isSelected,
      icon: icon,
      customization: customization,
      action: action
    )
  }

}

////////////////////////////////////////////////////////////////////////////////

public extension SwitchRow {

  @available(*, deprecated, message: "Use `init(text:detailText:switchValue:icon:customization:action:)` instead.")
  convenience init(
    title: String,
    switchValue: Bool,
    icon: Icon? = nil,
    customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
    action: ((Row) -> Void)?
  ) {
    self.init(
      text: title,
      detailText: nil,
      switchValue: switchValue,
      icon: icon,
      customization: customization,
      action: action
    )
  }

}

////////////////////////////////////////////////////////////////////////////////

public extension TapActionRow {

  @available(*, deprecated, message: "Use `init(text:customization:action:)` instead.")
  convenience init(
    title: String,
    customization: ((UITableViewCell, Row & RowStyle) -> Void)? = nil,
    action: ((Row) -> Void)?
  ) {
    self.init(
      text: title,
      customization: customization,
      action: action
    )
  }

}
