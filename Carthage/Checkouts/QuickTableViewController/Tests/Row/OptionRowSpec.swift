//
//  OptionRowSpec.swift
//  QuickTableViewControllerTests
//
//  Created by Ben on 17/08/2017.
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
import QuickTableViewController

internal final class OptionRowSpec: QuickSpec {

  override func spec() {
    describe("initialiation") {
      let icon = Icon.named("icon")

      var invoked = false
      let row = OptionRow(title: "title", isSelected: true, icon: icon) { _ in invoked = true }

      it("should initialize with given parameters") {
        // Row
        expect(row.title) == "title"
        expect(row.subtitle).to(beNil())
        expect(row.isSelected) == true

        row.action?(row)
        expect(invoked) == true

        // RowStyle
        expect(row.cellReuseIdentifier) == "UITableViewCell"
        expect(row.cellStyle) == UITableViewCellStyle.default
        expect(row.icon) == icon
        expect(row.accessoryType) == UITableViewCellAccessoryType.checkmark
        expect(row.isSelectable) == true
        expect(row.customize).to(beNil())
      }

      it("should conform to the protocol") {
        expect(row).to(beAKindOf(OptionRowCompatible.self))
      }
    }

    describe("equatable") {
      let a = OptionRow(title: "Same", isSelected: true, action: nil)

      context("identical parameters") {
        let b = OptionRow(title: "Same", isSelected: true, action: nil)
        it("should be qeaul") {
          expect(a) == b
        }
      }

      context("different titles") {
        let c = OptionRow(title: "Different", isSelected: true, action: nil)
        it("should not be eqaul") {
          expect(a) != c
        }
      }

      context("different selection state") {
        let d = OptionRow(title: "Same", isSelected: false, action: nil)
        it("should not be equal") {
          expect(a) != d
        }
      }

      context("different icons") {
        let e = OptionRow(title: "Same", isSelected: true, icon: .image(UIImage()), action: nil)
        it("should not be equal") {
          expect(a) != e
        }
      }

      context("different actions") {
        let f = OptionRow(title: "Same", isSelected: true, action: { _ in })
        it("should be equal regardless of the actions attached") {
          expect(a) == f
        }
      }
    }

    describe("action invocation") {
      context("when the selection is toggled") {
        var invoked = false
        let row = OptionRow(title: "", isSelected: false) { _ in invoked = true }

        it("should invoke the action closure") {
          row.isSelected = true
          expect(row.accessoryType) == UITableViewCellAccessoryType.checkmark
          expect(invoked).toEventually(beTrue())
        }
      }

      context("when the selection stays the same") {
        var invoked = false
        let row = OptionRow(title: "", isSelected: false) { _ in invoked = true }

        it("should not invoke the action closure") {
          row.isSelected = false
          expect(row.accessoryType) == UITableViewCellAccessoryType.none
          expect(invoked).toEventually(beFalse())
        }
      }
    }
  }

}
