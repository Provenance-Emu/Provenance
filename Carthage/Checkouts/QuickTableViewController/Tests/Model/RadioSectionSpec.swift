//
//  RadioSectionSpec.swift
//  QuickTableViewController
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

internal final class RadioSectionSpec: QuickSpec {

  override func spec() {
    describe("initialization") {
      let row = OptionRow(title: "", isSelected: false, action: nil)
      let section = RadioSection(title: "title", options: [row], footer: "footer")

      it("should initialize with given parameters") {
        expect(section.title) == "title"
        expect(section.rows).to(haveCount(1))
        expect(section.rows.first as? OptionRow) == row
        expect(section.options).to(haveCount(1))
        expect(section.options.first) === row
        expect(section.footer) == "footer"
      }
    }

    describe("rows") {
      context("getter") {
        let options = [
          OptionRow(title: "0", isSelected: false, action: nil),
          OptionRow(title: "1", isSelected: true, action: nil)
        ]
        let section = RadioSection(title: "", options: options)

        it("should return options as rows") {
          expect(section.rows).to(beAKindOf([OptionRowCompatible].self))
          expect(section.rows as? [OptionRow]) == options
        }
      }

      context("setter") {
        context("given empty array") {
          let section = RadioSection(title: "", options: [
            OptionRow(title: "", isSelected: true, action: nil)
          ])

          it("should change rows") {
            expect(section.rows).to(haveCount(1))
            section.rows = []
            expect(section.rows).to(beEmpty())
          }
        }

        context("given incompatible type") {
          let options = [OptionRow(title: "0", isSelected: false, action: nil)]
          let section = RadioSection(title: "", options: options)

          it("should not change rows") {
            expect(section.rows).to(haveCount(1))
            section.rows = [
              NavigationRow(title: "", subtitle: .none),
              NavigationRow(title: "", subtitle: .none)
            ]
            expect(section.rows).to(haveCount(1))
            expect(section.rows as? [OptionRow]) == options
          }
        }

        context("given compatible type") {
          let options = [
            OptionRow(title: "0", isSelected: false, action: nil),
            OptionRow(title: "1", isSelected: true, action: nil)
          ]
          let section = RadioSection(title: "", options: [])

          it("should change rows") {
            expect(section.rows).to(beEmpty())
            section.rows = options
            expect(section.rows).to(haveCount(2))
            expect(section.rows as? [OptionRow]) == options
          }
        }
      }
    }

    describe("always selects one option") {
      context("when set to false") {
        let section = RadioSection(title: "title", options: [
          OptionRow(title: "Option 1", isSelected: false, action: nil)
        ])
        section.alwaysSelectsOneOption = false

        it("should do nothing") {
          expect(section.options).to(haveCount(1))
          expect(section.selectedOption).to(beNil())
        }
      }

      context("when set to true with empty options") {
        let section = RadioSection(title: "title", options: [])
        section.alwaysSelectsOneOption = true

        it("should do nothing") {
          expect(section.options).to(beEmpty())
          expect(section.selectedOption).to(beNil())
        }
      }

      context("when set to true with nothing selected") {
        let section = RadioSection(title: "title", options: [
          OptionRow(title: "Option 1", isSelected: false, action: nil),
          OptionRow(title: "Option 2", isSelected: false, action: nil)
        ])
        section.alwaysSelectsOneOption = true

        it("should select the first option") {
          expect(section.selectedOption) === section.options[0]
          expect(section.options[0].isSelected) == true
          expect(section.options[1].isSelected) == false
        }
      }

      context("when set to true with something selected") {
        let section = RadioSection(title: "title", options: [
          OptionRow(title: "Option 1", isSelected: false, action: nil),
          OptionRow(title: "Option 2", isSelected: true, action: nil)
        ])
        section.alwaysSelectsOneOption = true

        it("should do nothing") {
          expect(section.selectedOption) === section.options[1]
          expect(section.options[0].isSelected) == false
          expect(section.options[1].isSelected) == true
        }
      }
    }

    describe("toggle options") {
      let mock = {
        return RadioSection(title: "Radio", options: [
          OptionRow(title: "Option 1", isSelected: true, action: nil),
          OptionRow(title: "Option 2", isSelected: false, action: nil),
          OptionRow(title: "Option 3", isSelected: false, action: nil)
        ])
      }

      context("when the option to toggle is not in the section") {
        let section = mock()
        let option = OptionRow(title: "", isSelected: true, action: nil)
        let result = section.toggle(option)

        it("should return an empty index set") {
          expect(result) == []
        }
      }

      context("when the option is selected and it allows none selected") {
        let section = mock()
        _ = section.toggle(section.options[0])

        it("should deselect the option") {
          expect(section.selectedOption).to(beNil())
          expect(section.options[0].isSelected) == false
          expect(section.options[1].isSelected) == false
          expect(section.options[2].isSelected) == false
        }
      }

      context("when the option is selected and it doesn't allow none selected") {
        let section = mock()
        section.alwaysSelectsOneOption = true
        _ = section.toggle(section.options[0])

        it("should do nothing") {
          expect(section.selectedOption) === section.options[0]
          expect(section.options[0].isSelected) == true
          expect(section.options[1].isSelected) == false
          expect(section.options[2].isSelected) == false
        }
      }

      context("when there's nothing selected") {
        let section = mock()
        _ = section.toggle(section.options[0])
        _ = section.toggle(section.options[1])

        it("should select the option") {
          expect(section.selectedOption) === section.options[1]
          expect(section.options[0].isSelected) == false
          expect(section.options[1].isSelected) == true
          expect(section.options[2].isSelected) == false
        }
      }

      context("when there's already another option selected") {
        let section = mock()
        _ = section.toggle(section.options[2])

        it("should deselect the other option") {
          expect(section.selectedOption) === section.options[2]
          expect(section.options[0].isSelected) == false
          expect(section.options[1].isSelected) == false
          expect(section.options[2].isSelected) == true
        }
      }
    }
  }

}
