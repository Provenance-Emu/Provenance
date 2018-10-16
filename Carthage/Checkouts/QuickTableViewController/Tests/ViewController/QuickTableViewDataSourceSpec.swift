//
//  QuickTableViewDataSourceSpec.swift
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

internal final class QuickTableViewDataSourceSpec: QuickSpec {

  override func spec() {

    // MARK: - numberOfSectionsInTableView(_:)

    describe("numberOfSectionsInTableView(_:)") {
      let controller = QuickTableViewController()
      controller.tableContents = [
        Section(title: nil, rows: []),
        Section(title: nil, rows: []),
        Section(title: nil, rows: [])
      ]
      it("should return the number of sections") {
        expect(controller.numberOfSections(in: controller.tableView)) == 3
      }
    }

    // MARK: - tableView(_:numberOfRowsInSection:)

    describe("tableView(_:numberOfRowsInSection:)") {
      let controller = QuickTableViewController()
      controller.tableContents = [
        Section(title: nil, rows: []),
        Section(title: nil, rows: [
          NavigationRow(title: "", subtitle: .none),
          NavigationRow(title: "", subtitle: .none)
        ]),
        RadioSection(title: nil, options: []),
        RadioSection(title: nil, options: [
          OptionRow(title: "", isSelected: false, action: { _ in }),
          OptionRow(title: "", isSelected: false, action: { _ in })
        ])
      ]
      it("should return the number of sections") {
        expect(controller.tableView(controller.tableView, numberOfRowsInSection: 0)) == 0
        expect(controller.tableView(controller.tableView, numberOfRowsInSection: 1)) == 2
        expect(controller.tableView(controller.tableView, numberOfRowsInSection: 2)) == 0
        expect(controller.tableView(controller.tableView, numberOfRowsInSection: 3)) == 2
      }
    }

    // MARK: - tableView(_:titleForHeaderInSection:)

    describe("tableView(_:titleForHeaderInSection:)") {
      let controller = QuickTableViewController()
      controller.tableContents = [
        Section(title: nil, rows: []),
        Section(title: "title", rows: []),
        RadioSection(title: "radio", options: [])
      ]
      it("should return the title in sections") {
        expect(controller.tableView(controller.tableView, titleForHeaderInSection: 0)).to(beNil())
        expect(controller.tableView(controller.tableView, titleForHeaderInSection: 1)) == "title"
        expect(controller.tableView(controller.tableView, titleForHeaderInSection: 2)) == "radio"
      }
    }

    // MARK: - tableView(_:titleForFooterInSection:)

    describe("tableView(_:titleForFooterInSection:)") {
      let controller = QuickTableViewController()
      controller.tableContents = [
        Section(title: nil, rows: []),
        Section(title: nil, rows: [], footer: "footer"),
        RadioSection(title: nil, options: [], footer: "radio")
      ]
      it("should return the title in sections") {
        expect(controller.tableView(controller.tableView, titleForFooterInSection: 0)).to(beNil())
        expect(controller.tableView(controller.tableView, titleForFooterInSection: 1)) == "footer"
        expect(controller.tableView(controller.tableView, titleForFooterInSection: 2)) == "radio"
      }
    }

    // MARK: - tableView(_:cellForRowAt:)

    describe("tableView(_:cellForRowAt:)") {

      // MARK: NavigationRow

      context("NavigationRow") {
        context("style") {
          let controller = QuickTableViewController()
          controller.tableContents = [
            Section(title: "Cell Styles", rows: [
              CustomNavigationRow<CustomCell>(title: "CellStyle.default", subtitle: .none),
              CustomNavigationRow<CustomCell>(title: "CellStyle", subtitle: .belowTitle(".subtitle")),
              CustomNavigationRow<CustomCell>(title: "CellStyle", subtitle: .rightAligned(".value1")),
              CustomNavigationRow<CustomCell>(title: "CellStyle", subtitle: .leftAligned(".value2"))
            ])
          ]
          let a = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
          let b = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
          let c = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 2, section: 0))
          let d = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 3, section: 0))

          it("should match the reusable identifier") {
            expect(a.reuseIdentifier) == "CustomCell.default"
            expect(b.reuseIdentifier) == "CustomCell.subtitle"
            expect(c.reuseIdentifier) == "CustomCell.value1"
            expect(d.reuseIdentifier) == "CustomCell.value2"
          }

          it("should match the texts in labels") {
            expect(a.textLabel?.text) == "CellStyle.default"
            expect(b.textLabel?.text) == "CellStyle"
            expect(c.textLabel?.text) == "CellStyle"
            expect(d.textLabel?.text) == "CellStyle"
          }

          it("should match the texts in detail labels") {
            expect(a.detailTextLabel?.text).to(beNil())
            expect(b.detailTextLabel?.text) == ".subtitle"
            expect(c.detailTextLabel?.text) == ".value1"
            expect(d.detailTextLabel?.text) == ".value2"
          }
        }

        context("icon") {
          let controller = QuickTableViewController()
          let resourcePath = Bundle(for: QuickTableViewControllerSpec.self).resourcePath as NSString?
          let imagePath = resourcePath?.appendingPathComponent("icon.png") ?? ""
          let highlightedImagePath = resourcePath?.appendingPathComponent("icon.png") ?? ""

          let image = UIImage(contentsOfFile: imagePath)!
          let highlightedImage = UIImage(contentsOfFile: highlightedImagePath)!

          controller.tableContents = [
            Section(title: "NavigationRow", rows: [
              CustomNavigationRow<CustomCell>(title: "CellStyle.default", subtitle: .none, icon: .named("icon")),
              CustomNavigationRow<CustomCell>(title: "CellStyle", subtitle: .belowTitle(".subtitle"), icon: .image(image)),
              CustomNavigationRow<CustomCell>(title: "CellStyle", subtitle: .rightAligned(".value1"), icon: .images(normal: image, highlighted: highlightedImage)),
              CustomNavigationRow<CustomCell>(title: "CellStyle", subtitle: .leftAligned(".value2"), icon: .image(image))
            ]),
            Section(title: "SwitchRow", rows: [
              CustomSwitchRow<CustomSwitchCell>(title: "imageName", switchValue: true, icon: .named("icon"), action: nil),
              CustomSwitchRow<CustomSwitchCell>(title: "image", switchValue: true, icon: .image(image), action: nil),
              CustomSwitchRow<CustomSwitchCell>(title: "image + highlightedImage", switchValue: true, icon: .images(normal: image, highlighted: highlightedImage), action: nil)
            ])
          ]

          it("does not work with images in the test bundle") {
            let navigationCell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
            expect(navigationCell.imageView?.image).to(beNil())
            expect(navigationCell.imageView?.highlightedImage).to(beNil())

            let switchCell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 1))
            expect(switchCell.imageView?.image).to(beNil())
            expect(switchCell.imageView?.highlightedImage).to(beNil())
          }

          it("should have the image set") {
            let navigationCell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
            expect(navigationCell.imageView?.image) == image
            expect(navigationCell.imageView?.highlightedImage).to(beNil())

            let switchCell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 1, section: 1))
            expect(switchCell.imageView?.image).notTo(beNil())
            expect(switchCell.imageView?.highlightedImage).to(beNil())
          }

          it("should have the image and highlightedImage set") {
            let cell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 2, section: 0))
            expect(cell.imageView?.image).notTo(beNil())
            expect(cell.imageView?.highlightedImage).notTo(beNil())

            let switchCell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 2, section: 1))
            expect(switchCell.imageView?.image).notTo(beNil())
            expect(switchCell.imageView?.highlightedImage).notTo(beNil())
          }

          it("should not have an image with UITableViewCellStyle.value2") {
            let cell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 3, section: 0))
            expect(cell.imageView?.image).to(beNil())
            expect(cell.imageView?.highlightedImage).to(beNil())
          }
        }

        context("indicator") {
          let controller = QuickTableViewController()
          controller.tableContents = [
            Section(title: "Navigation", rows: [
              CustomNavigationRow<CustomCell>(title: "", subtitle: .none, action: { _ in }),
              CustomNavigationRow<CustomCell>(title: "", subtitle: .belowTitle(""), action: { _ in }),
              CustomNavigationRow<CustomCell>(title: "", subtitle: .rightAligned(""), action: { _ in }),
              CustomNavigationRow<CustomCell>(title: "", subtitle: .leftAligned(""), action: { _ in })
            ])
          ]

          it("should have the disclosure indicator") {
            for row in 0...3 {
              let cell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: row, section: 0))
              expect(cell.accessoryType) == UITableViewCellAccessoryType.disclosureIndicator
            }
          }
        }
      }

      // MARK: SwitchRow

      context("SwitchRow") {
        let controller = QuickTableViewController()
        controller.tableContents = [
          Section(title: "SwitchRow", rows: [
            SwitchRow(title: "Setting 0", switchValue: true, action: nil),
            CustomSwitchRow(title: "Setting 1", switchValue: true, action: nil),
            SwitchRow<CustomSwitchCell>(title: "Setting 2", switchValue: true, action: nil),
            CustomSwitchRow<CustomSwitchCell>(title: "Setting 3", switchValue: true, action: nil)
          ])
        ]

        for index in 0...3 {
          let cell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: index, section: 0))

          it("should return cell type at \(index)") {
            let type = index < 2 ? SwitchCell.self : CustomSwitchCell.self
            expect(cell).to(beAKindOf(type))
          }

          it("should match the text at \(index)") {
            expect(cell.textLabel?.text) == "Setting \(index)"
            expect(cell.detailTextLabel?.text).to(beNil())
          }

          it("should match the switch value at \(index)") {
            #if os(iOS)
              expect((cell as? SwitchCell)?.switchControl.isOn) == true
            #elseif os(tvOS)
              expect(cell.accessoryType) == UITableViewCellAccessoryType.checkmark
            #endif
          }
        }
      }

      // MARK: TapActionRow

      context("TapActionRow") {
        let controller = QuickTableViewController()
        controller.tableContents = [
          Section(title: "TapActionRow", rows: [
            TapActionRow(title: "0", action: { _ in }),
            CustomTapActionRow(title: "1", action: { _ in }),
            TapActionRow<CustomTapActionCell>(title: "2", action: { _ in }),
            CustomTapActionRow<CustomTapActionCell>(title: "3", action: { _ in })
          ])
        ]

        for index in 0...3 {
          let cell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: index, section: 0))

          it("should return cell type at \(index)") {
            let type = index < 2 ? TapActionCell.self : CustomTapActionCell.self
            expect(cell).to(beAKindOf(type))
          }

          it("should match the text at \(index)") {
            expect(cell.textLabel?.text) == "\(index)"
            expect(cell.detailTextLabel?.text).to(beNil())
          }
        }
      }

      // MARK: OptionRow

      context("OptionRow") {
        let controller = QuickTableViewController()
        controller.tableContents = [
          Section(title: "OptionRow", rows: [
            OptionRow(title: "0", isSelected: true, action: { _ in }),
            CustomOptionRow(title: "1", isSelected: true, action: { _ in }),
            OptionRow<CustomCell>(title: "2", isSelected: true, action: { _ in }),
            CustomOptionRow<CustomCell>(title: "3", isSelected: true, action: { _ in })
          ])
        ]

        for index in 0...3 {
          let cell = controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: index, section: 0))

          it("should return cell type at \(index)") {
            let type = index < 2 ? UITableViewCell.self : CustomCell.self
            expect(cell).to(beAKindOf(type))
          }

          it("should match the text at \(index)") {
            expect(cell.textLabel?.text) == "\(index)"
          }

          it("should match the selection at \(index)") {
            expect(cell.accessoryType) == UITableViewCellAccessoryType.checkmark
          }
        }
      }
    }
  }

}
