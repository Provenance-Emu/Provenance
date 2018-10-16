//
//  QuickTableViewDelegateSpec.swift
//  QuickTableViewControllerTests
//
//  Created by Ben on 31/12/2017.
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

internal final class QuickTableViewDelegateSpec: QuickSpec {

  override func spec() {

    // MARK: tableView(_:shouldHighlightRowAt:)

    describe("tableView(_:shouldHighlightRowAt:)") {
      let controller = QuickTableViewController()
      _ = controller.view

      controller.tableContents = [
        Section(title: "NavigationRow", rows: [
          NavigationRow(title: "", subtitle: .none),
          CustomNavigationRow(title: "", subtitle: .none),
          NavigationRow<CustomCell>(title: "", subtitle: .none),
          CustomNavigationRow<CustomCell>(title: "", subtitle: .none)
        ]),

        Section(title: "NavigationRow", rows: [
          NavigationRow(title: "", subtitle: .none, action: { _ in }),
          CustomNavigationRow(title: "", subtitle: .none, action: { _ in }),
          NavigationRow<CustomCell>(title: "", subtitle: .none, action: { _ in }),
          CustomNavigationRow<CustomCell>(title: "", subtitle: .none, action: { _ in })
        ]),

        Section(title: "SwitchRow", rows: [
          SwitchRow(title: "", switchValue: true, action: nil),
          CustomSwitchRow(title: "", switchValue: true, action: nil),
          SwitchRow<CustomSwitchCell>(title: "", switchValue: true, action: nil),
          CustomSwitchRow<CustomSwitchCell>(title: "", switchValue: true, action: nil)
        ]),

        Section(title: "TapActionRow", rows: [
          TapActionRow(title: "", action: { _ in }),
          CustomTapActionRow(title: "", action: { _ in }),
          TapActionRow<CustomTapActionCell>(title: "", action: { _ in }),
          CustomTapActionRow<CustomTapActionCell>(title: "", action: { _ in })
        ]),

        Section(title: "OptionRow", rows: [
          OptionRow(title: "", isSelected: false, action: nil),
          CustomOptionRow(title: "", isSelected: false, action: nil),
          OptionRow<CustomCell>(title: "", isSelected: false, action: nil),
          CustomOptionRow<CustomCell>(title: "", isSelected: false, action: nil)
        ]),

        RadioSection(title: "RadioSection", options: [
          OptionRow(title: "", isSelected: false, action: { _ in }),
          CustomOptionRow(title: "", isSelected: false, action: { _ in }),
          OptionRow<CustomCell>(title: "", isSelected: false, action: { _ in }),
          CustomOptionRow<CustomCell>(title: "", isSelected: false, action: { _ in })
        ])
      ]

      it("should not highlight NavigationRow without an action") {
        for index in 0...3 {
          let highlight = controller.tableView(controller.tableView, shouldHighlightRowAt: IndexPath(row: index, section: 0))
          expect(highlight) == false
        }
      }

      it("should highlight NavigationRow with an action") {
        for index in 0...3 {
          let highlight = controller.tableView(controller.tableView, shouldHighlightRowAt: IndexPath(row: index, section: 1))
          expect(highlight) == true
        }
      }

      it("should not highlight SwitchRow") {
        for index in 0...3 {
          let highlight = controller.tableView(controller.tableView, shouldHighlightRowAt: IndexPath(row: index, section: 2))
          #if os(iOS)
            expect(highlight) == false
          #elseif os(tvOS)
            expect(highlight) == true
          #endif
        }
      }

      it("should highlight TapActionRow") {
        for index in 0...3 {
          let highlight = controller.tableView(controller.tableView, shouldHighlightRowAt: IndexPath(row: index, section: 3))
          expect(highlight) == true
        }
      }

      it("should highlight OptionRow without an action") {
        for index in 0...3 {
          let highlight = controller.tableView(controller.tableView, shouldHighlightRowAt: IndexPath(row: index, section: 4))
          expect(highlight) == true
        }
      }

      it("should highlight OptionRow with an action") {
        for index in 0...3 {
          let highlight = controller.tableView(controller.tableView, shouldHighlightRowAt: IndexPath(row: index, section: 5))
          expect(highlight) == true
        }
      }
    }

    // MARK: - tableView(_:didSelectRowAt:)

    describe("tableView(_:didSelectRowAt:)") {

      // MARK: Section

      context("Section") {
        context("NavigationRow") {
          let controller = QuickTableViewController()
          _ = controller.view
          var selectedIndex = -1

          controller.tableContents = [
            Section(title: "NavigationRow", rows: [
              NavigationRow(title: "", subtitle: .none, action: { _ in selectedIndex = 0 }),
              CustomNavigationRow(title: "", subtitle: .none, action: { _ in selectedIndex = 1 }),
              NavigationRow<CustomCell>(title: "", subtitle: .none, action: { _ in selectedIndex = 2 }),
              CustomNavigationRow<CustomCell>(title: "", subtitle: .none, action: { _ in selectedIndex = 3 })
            ])
          ]

          for index in 0...3 {
            it("should invoke action when \(index) is selected") {
              controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
              expect(selectedIndex).toEventually(equal(index))
            }
          }
        }

        context("TapActionRow") {
          let controller = QuickTableViewController()
          _ = controller.view
          var selectedIndex = -1

          controller.tableContents = [
            Section(title: "TapActionRow", rows: [
              TapActionRow(title: "", action: { _ in selectedIndex = 0 }),
              CustomTapActionRow(title: "", action: { _ in selectedIndex = 1 }),
              TapActionRow<CustomTapActionCell>(title: "", action: { _ in selectedIndex = 2 }),
              CustomTapActionRow<CustomTapActionCell>(title: "", action: { _ in selectedIndex = 3 })
            ])
          ]

          for index in 0...3 {
            it("should invoke action when \(index) is selected") {
              controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
              expect(selectedIndex).toEventually(equal(index))
            }
          }
        }

        context("OptionRow") {
          let controller = QuickTableViewController()
          _ = controller.view
          var toggledIndex = -1

          let section = Section(title: "OptionRow", rows: [
            OptionRow(title: "", isSelected: false, action: { _ in toggledIndex = 0 }),
            CustomOptionRow(title: "", isSelected: false, action: { _ in toggledIndex = 1 }),
            OptionRow<CustomCell>(title: "", isSelected: false, action: { _ in toggledIndex = 2 }),
            CustomOptionRow<CustomCell>(title: "", isSelected: false, action: { _ in toggledIndex = 3 })
          ])
          controller.tableContents = [section]

          for index in 0...3 {
            it("should invoke action when \(index) is selected") {
              controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
              expect(toggledIndex).toEventually(equal(index))

              let option = section.rows[index] as? OptionRowCompatible
              expect(option?.isSelected) == true
            }
          }
        }
      }

      // MARK: Radio Section

      context("RadioSection") {
        context("default") {
          let controller = QuickTableViewController()
          _ = controller.view
          var toggledIndex = -1

          let radio = RadioSection(title: "alwaysSelectsOneOption = false", options: [
            OptionRow(title: "", isSelected: false, action: { _ in toggledIndex = 0 }),
            CustomOptionRow(title: "", isSelected: false, action: { _ in toggledIndex = 1 }),
            OptionRow<CustomCell>(title: "", isSelected: false, action: { _ in toggledIndex = 2 }),
            CustomOptionRow<CustomCell>(title: "", isSelected: false, action: { _ in toggledIndex = 3 })
          ])
          controller.tableContents = [radio]

          for index in 0...3 {
            it("should invoke action when \(index) is selected") {
              controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
              expect(toggledIndex).toEventually(equal(index))

              let option = radio.rows[index] as? OptionRowCompatible
              expect(option?.isSelected) == true

              controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
              expect(option?.isSelected) == false
            }
          }
        }

        context("alwaysSelectsOneOption") {
          let controller = QuickTableViewController()
          _ = controller.view
          var toggledIndex = -1

          let radio = RadioSection(title: "alwaysSelectsOneOption = true", options: [
            OptionRow(title: "", isSelected: false, action: { _ in toggledIndex = 0 }),
            CustomOptionRow(title: "", isSelected: false, action: { _ in toggledIndex = 1 }),
            OptionRow<CustomCell>(title: "", isSelected: false, action: { _ in toggledIndex = 2 }),
            CustomOptionRow<CustomCell>(title: "", isSelected: false, action: { _ in toggledIndex = 3 })
          ])
          radio.alwaysSelectsOneOption = true
          controller.tableContents = [radio]

          for index in 0...3 {
            it("should invoke action when \(index) is selected") {
              controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
              expect(toggledIndex).toEventually(equal(index))

              let option = controller.tableContents[0].rows[index] as? OptionRowCompatible
              expect(option?.isSelected) == true

              controller.tableView(controller.tableView, didSelectRowAt: IndexPath(row: index, section: 0))
              expect(option?.isSelected) == true
              expect(radio.indexOfSelectedOption) == index
            }
          }
        }
      }
    }
  }

}
