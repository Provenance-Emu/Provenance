//
//  SwitchRowSpec.swift
//  QuickTableViewControllerTests
//
//  Created by Ben on 17/01/2016.
//  Copyright © 2016 bcylin.
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

internal final class SwitchRowSpec: QuickSpec {

  override func spec() {
    describe("initialization") {
      var invoked = false
      let row = SwitchRow(title: "title", switchValue: true) { _ in invoked = true }

      it("should initialize with given parameters") {
        expect(row.title) == "title"
        expect(row.switchValue) == true
        expect(row.cellReuseIdentifier) == "SwitchCell"

        row.action?(row)
        expect(invoked) == true
      }

      it("should conform to the protocol") {
        expect(row).to(beAKindOf(SwitchRowCompatible.self))
      }
    }

    describe("equatable") {
      let a = SwitchRow(title: "Same", switchValue: true, action: nil)

      context("identical parameters") {
        let b = SwitchRow(title: "Same", switchValue: true, action: nil)
        it("should be qeaul") {
          expect(a) == b
        }
      }

      context("different titles") {
        let c = SwitchRow(title: "Different", switchValue: true, action: nil)
        it("should not be eqaul") {
          expect(a) != c
        }
      }

      context("different switch values") {
        let d = SwitchRow(title: "Same", switchValue: false, action: nil)
        it("should not be equal") {
          expect(a) != d
        }
      }

      context("different icons") {
        let e = SwitchRow(title: "Same", switchValue: true, icon: .image(UIImage()), action: nil)
        it("should not be equal") {
          expect(a) != e
        }
      }

      context("different actions") {
        let f = SwitchRow(title: "Same", switchValue: true, action: { _ in })
        it("should be equal regardless of the actions attached") {
          expect(a) == f
        }
      }
    }

    describe("action invocation") {
      context("when the switch value is changed") {
        var invoked = false
        let row = SwitchRow(title: "", switchValue: false) { _ in invoked = true }

        it("should invoke the action closure") {
          row.switchValue = true
          expect(invoked).toEventually(beTrue())
        }
      }

      context("when the switch value stays the same") {
        var invoked = false
        let row = SwitchRow(title: "", switchValue: false) { _ in invoked = true }

        it("should not invoke the action closure") {
          row.switchValue = false
          expect(invoked).toEventually(beFalse())
        }
      }
    }
  }

}
