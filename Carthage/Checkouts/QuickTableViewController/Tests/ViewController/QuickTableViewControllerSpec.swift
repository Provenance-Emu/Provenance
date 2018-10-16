//
//  QuickTableViewControllerSpec.swift
//  QuickTableViewControllerTests
//
//  Created by Ben on 21/01/2016.
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
@testable import QuickTableViewController

internal final class QuickTableViewControllerSpec: QuickSpec {

  override func spec() {

    // MARK: - Initializer

    describe("init(style:)") {
      it("should set up table view with style") {
        expect(QuickTableViewController().tableView.style) == UITableViewStyle.grouped
        expect(QuickTableViewController(style: .plain).tableView.style) == UITableViewStyle.plain
      }
    }

    // MARK: - UIViewController

    describe("lifecycle") {
      var tableView: UITableView! // swiftlint:disable:this implicitly_unwrapped_optional

      it("should set up table view") {
        let controller = QuickTableViewController(style: .grouped)
        let view = controller.view
        tableView = controller.tableView

        expect(view?.subviews).to(contain(tableView))
        expect(tableView.dataSource as? QuickTableViewController) == controller
        expect(tableView.delegate as? QuickTableViewController) == controller
      }

      it("should nullify the references after controller is gone") {
        expect(tableView).notTo(beNil())
        expect(tableView.dataSource).toEventually(beNil())
        expect(tableView.delegate).toEventually(beNil())
      }
    }
  }

}
