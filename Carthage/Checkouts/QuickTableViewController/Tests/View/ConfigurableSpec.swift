//
//  ConfigurableSpec.swift
//  QuickTableViewControllerTests
//
//  Created by Ben on 27/12/2017.
//  Copyright © 2017 bcylin.
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

import Nimble
import Quick
@testable import QuickTableViewController

internal final class ConfigurableSpec: QuickSpec {

  override func spec() {
    describe("configure(with:)") {
      context("default row and cell") {
        it("should set the switch to true") {
          let cell = SwitchCell()
          let row = SwitchRow(title: "", switchValue: true, action: nil)
          cell.configure(with: row)
          #if os(iOS)
            expect(cell.accessoryView) == cell.switchControl
            expect(cell.switchControl.isOn) == true
          #elseif os(tvOS)
            expect(cell.accessoryView).to(beNil())
            expect(cell.accessoryType) == UITableViewCellAccessoryType.checkmark
          #endif
        }

        it("should set the switch to false") {
          let cell = SwitchCell()
          let row = SwitchRow(title: "", switchValue: false, action: nil)
          cell.configure(with: row)
          #if os(iOS)
            expect(cell.accessoryView) == cell.switchControl
            expect(cell.switchControl.isOn) == false
          #elseif os(tvOS)
            expect(cell.accessoryView).to(beNil())
            expect(cell.accessoryType) == UITableViewCellAccessoryType.none
          #endif
        }
      }

      context("custom row") {
        it("should set the switch to true") {
          let cell = SwitchCell()
          let row = CustomSwitchRow(title: "", switchValue: true, action: nil)
          cell.configure(with: row)
          #if os(iOS)
            expect(cell.accessoryView) == cell.switchControl
            expect(cell.switchControl.isOn) == true
          #elseif os(tvOS)
            expect(cell.accessoryView).to(beNil())
            expect(cell.accessoryType) == UITableViewCellAccessoryType.checkmark
          #endif
        }

        it("should set the switch to false") {
          let cell = SwitchCell()
          let row = CustomSwitchRow(title: "", switchValue: false, action: nil)
          cell.configure(with: row)
          #if os(iOS)
            expect(cell.accessoryView) == cell.switchControl
            expect(cell.switchControl.isOn) == false
          #elseif os(tvOS)
            expect(cell.accessoryView).to(beNil())
            expect(cell.accessoryType) == UITableViewCellAccessoryType.none
          #endif
        }
      }

      context("custom cell") {
        it("should set the switch to true") {
          let cell = CustomSwitchCell()
          let row = SwitchRow<CustomSwitchCell>(title: "", switchValue: true, action: nil)
          cell.configure(with: row)
          #if os(iOS)
            expect(cell.accessoryView) == cell.switchControl
            expect(cell.switchControl.isOn) == true
          #elseif os(tvOS)
            expect(cell.accessoryView).to(beNil())
            expect(cell.accessoryType) == UITableViewCellAccessoryType.checkmark
          #endif
        }

        it("should set the switch to false") {
          let cell = CustomSwitchCell()
          let row = SwitchRow<CustomSwitchCell>(title: "", switchValue: false, action: nil)
          cell.configure(with: row)
          #if os(iOS)
            expect(cell.accessoryView) == cell.switchControl
            expect(cell.switchControl.isOn) == false
          #elseif os(tvOS)
            expect(cell.accessoryView).to(beNil())
            expect(cell.accessoryType) == UITableViewCellAccessoryType.none
          #endif
        }
      }

      context("custom row and cell") {
        it("should set the switch to true") {
          let cell = CustomSwitchCell()
          let row = CustomSwitchRow<CustomSwitchCell>(title: "", switchValue: true, action: nil)
          cell.configure(with: row)
          #if os(iOS)
            expect(cell.accessoryView) == cell.switchControl
            expect(cell.switchControl.isOn) == true
          #elseif os(tvOS)
            expect(cell.accessoryView).to(beNil())
            expect(cell.accessoryType) == UITableViewCellAccessoryType.checkmark
          #endif
        }

        it("should set the switch to false") {
          let cell = CustomSwitchCell()
          let row = CustomSwitchRow<CustomSwitchCell>(title: "", switchValue: false, action: nil)
          cell.configure(with: row)
          #if os(iOS)
            expect(cell.accessoryView) == cell.switchControl
            expect(cell.switchControl.isOn) == false
          #elseif os(tvOS)
            expect(cell.accessoryView).to(beNil())
            expect(cell.accessoryType) == UITableViewCellAccessoryType.none
          #endif
        }
      }
    }
  }

}
